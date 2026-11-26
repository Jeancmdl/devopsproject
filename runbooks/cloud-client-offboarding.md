# Cloud client offboarding (AWS)

A client leaves. Goal: keep what the law and the contract require, delete everything else, and leave nothing behind that keeps billing or can be hijacked. **Order matters: nothing destructive before preservation.**

## 1. Survey (read only)

Instances, volumes and each volume's `DeleteOnTermination`, Elastic IPs, security groups (shared with other clients?), buckets and their lifecycle rules, termination protection, the last valid backup, and any open incident that needs evidence.

## 2. Decide with the business

Retention of the database dump (tax data is usually 5 years), retention of disk snapshots, delivery of data to the client, any VM to keep stopped, legal hold.

## 3. Preserve

- Forensic evidence, if any, in a bucket with **Object Lock**.
- Adjust lifecycle rules. The default rule may expire objects in 365 days, which is shorter than tax retention.
- Tag buckets: `Status=offboarded`, `Client`, `OffboardDate`, `RetentionYears`.
- Snapshot every volume, tagged `Offboard=<client>-<year>`, `RetentionMonths`, `ExpiresOn`, `Source`. Wait until all are `completed`.
- Move long-term snapshots to the **Archive tier** (about 75% cheaper, 90-day minimum, 24–72 h to restore).

## 4. Check before destroying

- Every volume has a `completed` snapshot.
- The snapshot cleanup automation (a scheduled Lambda) **reads the tag you used**. A descriptive tag protects nothing. Only the tag the automation reads does.
- For each Elastic IP, no DNS record still points to it. Releasing an IP that DNS still references invites subdomain takeover.
- The security group is not referenced anywhere else.

## 5. Execute

Remove termination protection → terminate → wait for `terminated` → delete orphan volumes → release Elastic IPs → delete security groups.

## 6. Validate in the real cycle

Wait for the next scheduled run of the cleanup Lambda and check that the preserved snapshots survived. A dry run is not proof.

## 7. Clean references

Monitoring hosts, `pg_hba` lines on central databases, DNS and CDN records, VPN routes, backup crontabs, monitoring scripts, documentation.

## Cost lessons

- A stopped VM is not free: its EBS volumes keep billing.
- Data volumes usually have `DeleteOnTermination=false` and stay behind after terminate.
- Split retention by data type: the dump long-term in S3 Glacier Deep Archive, disk images short-term.
