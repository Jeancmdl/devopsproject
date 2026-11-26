#!/usr/bin/env python3
"""Days until expiry for PEM certificates, with Zabbix low-level discovery.

Usage:
  check_certs.py [--dir DIR]                 table for humans
  check_certs.py [--dir DIR] --discovery     LLD JSON: {#CERT}
  check_certs.py [--dir DIR] --days NAME     integer days until expiry (-1 on error)

Certificates are the *.pem files in DIR (default /etc/pki/app-certs). NAME is the file name
without extension. Certificates expired for more than IGNORE_AFTER days are left out, so
discovery removes them on its own. Requires the openssl binary.
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

IGNORE_AFTER = 60  # days


def days_left(pem: Path) -> int:
    out = subprocess.run(
        ["openssl", "x509", "-noout", "-enddate", "-in", str(pem)],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    # notAfter=Nov 25 12:00:00 2027 GMT
    end = datetime.strptime(out.split("=", 1)[1], "%b %d %H:%M:%S %Y %Z").replace(tzinfo=timezone.utc)
    return (end - datetime.now(timezone.utc)).days


def certs(directory: Path) -> dict[str, int]:
    result = {}
    for pem in sorted(directory.glob("*.pem")):
        try:
            days = days_left(pem)
        except (subprocess.CalledProcessError, ValueError, IndexError):
            days = -1
        if days < -IGNORE_AFTER:
            continue
        result[pem.stem] = days
    return result


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", default="/etc/pki/app-certs", type=Path)
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--discovery", action="store_true")
    mode.add_argument("--days", metavar="NAME")
    args = ap.parse_args()

    if args.days:
        pem = args.dir / f"{args.days}.pem"
        try:
            print(days_left(pem))
        except (OSError, subprocess.CalledProcessError, ValueError, IndexError):
            print(-1)
        return 0

    found = certs(args.dir)
    if args.discovery:
        print(json.dumps([{"{#CERT}": name} for name in found]))
    else:
        for name, days in found.items():
            print(f"{name:40} {days:>6} days")
    return 0


if __name__ == "__main__":
    sys.exit(main())
