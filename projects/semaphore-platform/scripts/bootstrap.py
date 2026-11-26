#!/usr/bin/env python3
"""Configure Semaphore UI as code.

Creates (idempotently) a project with its SSH key, repository, environment,
inventories and task templates from a JSON file, using only the Python
standard library.

Credentials come from environment variables, never from the config file:
    SEMAPHORE_USER / SEMAPHORE_PASSWORD

Usage:
    python3 scripts/bootstrap.py --config config/semaphore.json --dry-run
    python3 scripts/bootstrap.py --config config/semaphore.json
"""

from __future__ import annotations

import argparse
import http.cookiejar
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


class SemaphoreClient:
    """Minimal Semaphore REST API client using session-cookie auth."""

    def __init__(self, base_url: str, dry_run: bool = False) -> None:
        if not base_url.startswith(("http://", "https://")):
            raise SystemExit(f"Invalid Semaphore URL (http/https only): {base_url}")
        self.base_url = base_url.rstrip("/") + "/api"
        self.dry_run = dry_run
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
        )

    def request(self, method: str, path: str, body: dict[str, Any] | None = None) -> Any:
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(  # noqa: S310 - scheme validated in __init__
            self.base_url + path,
            data=data,
            method=method,
            headers={"Content-Type": "application/json", "Accept": "application/json"},
        )
        try:
            with self.opener.open(req, timeout=30) as resp:
                raw = resp.read()
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="replace")
            raise SystemExit(f"API error {exc.code} on {method} {path}: {detail}") from exc
        return json.loads(raw) if raw else None

    def login(self, user: str, password: str) -> None:
        self.request("POST", "/auth/login", {"auth": user, "password": password})

    def find(self, path: str, name: str) -> dict[str, Any] | None:
        for item in self.request("GET", path) or []:
            if item.get("name") == name:
                return item
        return None

    def ensure(self, path: str, payload: dict[str, Any], kind: str) -> int:
        """Return the id of an object with payload['name'], creating it if missing."""
        existing = self.find(path, payload["name"])
        if existing:
            print(f"  = {kind:<11} {payload['name']} (exists, id={existing['id']})")
            return int(existing["id"])
        if self.dry_run:
            print(f"  + {kind:<11} {payload['name']} (would create)")
            return 0
        created = self.request("POST", path, payload)
        if not created or "id" not in created:
            # Some endpoints return 204; look the object up again.
            created = self.find(path, payload["name"]) or {}
        print(f"  + {kind:<11} {payload['name']} (created, id={created.get('id')})")
        return int(created.get("id", 0))


def load_config(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--dry-run", action="store_true", help="show changes without applying them")
    args = parser.parse_args()

    cfg = load_config(args.config)
    user = os.environ.get("SEMAPHORE_USER")
    password = os.environ.get("SEMAPHORE_PASSWORD")
    if not user or not password:
        print("Set SEMAPHORE_USER and SEMAPHORE_PASSWORD.", file=sys.stderr)
        return 2

    ssh = cfg["ssh_key"]
    key_file = Path(ssh["private_key_file"]).expanduser()
    if not key_file.is_file():
        print(f"SSH private key not found: {key_file}", file=sys.stderr)
        return 2

    api = SemaphoreClient(cfg["url"], dry_run=args.dry_run)
    api.login(user, password)
    print(f"Connected to {cfg['url']}{' (dry run)' if args.dry_run else ''}")

    # Project
    project = api.find("/projects", cfg["project"])
    if project:
        pid = int(project["id"])
        print(f"  = {'project':<11} {cfg['project']} (exists, id={pid})")
    elif args.dry_run:
        print(f"  + {'project':<11} {cfg['project']} (would create)")
        print("Dry run stops here: the project does not exist yet.")
        return 0
    else:
        pid = int(api.request("POST", "/projects", {"name": cfg["project"], "alert": False})["id"])
        print(f"  + {'project':<11} {cfg['project']} (created, id={pid})")
    base = f"/project/{pid}"

    # Keys: "none" for public HTTPS repositories, SSH key for hosts
    none_key = api.ensure(f"{base}/keys", {"name": "none", "type": "none", "project_id": pid}, "key")
    ssh_key = api.ensure(
        f"{base}/keys",
        {
            "name": ssh["name"],
            "type": "ssh",
            "project_id": pid,
            "ssh": {"login": ssh["login"], "private_key": key_file.read_text(encoding="utf-8")},
        },
        "key",
    )

    # Repository
    repo = cfg["repository"]
    repo_id = api.ensure(
        f"{base}/repositories",
        {
            "name": repo["name"],
            "project_id": pid,
            "git_url": repo["git_url"],
            "git_branch": repo.get("git_branch", "main"),
            "ssh_key_id": none_key,
        },
        "repository",
    )

    # Environment (extra vars only; secrets belong in Semaphore's secret store)
    env = cfg["environment"]
    env_id = api.ensure(
        f"{base}/environment",
        {"name": env["name"], "project_id": pid, "json": json.dumps(env.get("extra_vars", {})), "env": json.dumps(env.get("env", {}))},
        "environment",
    )

    # Inventories ("file" = path inside the repository)
    inventory_ids: dict[str, int] = {}
    for inv in cfg["inventories"]:
        inventory_ids[inv["name"]] = api.ensure(
            f"{base}/inventory",
            {
                "name": inv["name"],
                "project_id": pid,
                "type": inv.get("type", "file"),
                "inventory": inv["inventory"],
                "repository_id": repo_id,
                "ssh_key_id": ssh_key,
                "become_key_id": none_key,
            },
            "inventory",
        )

    # Task templates
    for tpl in cfg["templates"]:
        api.ensure(
            f"{base}/templates",
            {
                "name": tpl["name"],
                "project_id": pid,
                "app": "ansible",
                "playbook": tpl["playbook"],
                "inventory_id": inventory_ids[tpl["inventory"]],
                "repository_id": repo_id,
                "environment_id": env_id,
                "description": tpl.get("description", ""),
                "arguments": json.dumps(tpl.get("arguments", [])),
            },
            "template",
        )

    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
