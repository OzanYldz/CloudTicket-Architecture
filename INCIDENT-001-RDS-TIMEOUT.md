# Incident Report: INCIDENT-001 - Database Connection Timeout

* **Status:** Resolved
* **Severity:** P1 (Outage)
* **Date:** October 17, 2026
* **Duration:** ~12 minutes

---

## Summary
During testing of the CloudTicket v2.0 3-tier architecture, the web server (`cloudticket-test-ec2`) lost connection to the MySQL database (`cloudticket-db`). Any attempt to connect or query tickets hung for 60 seconds before throwing `ERROR 2003 (110: Connection timed out)`. 

I ran this test intentionally as a chaos experiment to observe how security group misconfigurations manifest in production, how the Linux client reacts, and how quickly the issue can be isolated and fixed.

---

## Impact
* The web app could not read or write any ticket data (resulting in HTTP 500 errors for users).
* Application processes hung while waiting for the TCP 3-way handshake to complete.
* No data was corrupted or lost because the database itself remained healthy in the private subnet.

---

## Timeline

* **13:40 UTC** - Removed the inbound port 3306 rule on `cloudticket-db-sg` to simulate accidental rule deletion or configuration drift.
* **13:42 UTC** - Logged into the test EC2 instance via SSH and attempted to connect to the database endpoint.
* **13:43 UTC** - The client hung for 60 seconds and failed with:
  ```text
  ERROR 2003 (HY000): Can't connect to MySQL server on 'cloudticket-db.c6fgee26m2pv.us-east-1.rds.amazonaws.com:3306' (110 "Connection timed out")
  ```
  Saved screenshot proof to `screenshots/Security/Chaos Test Connection Timeout.png`.
* **13:46 UTC** - Began troubleshooting. Confirmed DNS resolution worked (`cloudticket-db...` resolved to `10.0.20.70`). Confirmed VPC route table had the default local route for `10.0.0.0/16`.
* **13:48 UTC** - Inspected `cloudticket-db-sg` inbound rules in AWS Console and spotted that port 3306 was missing.
* **13:50 UTC** - Added the security group chaining rule back, setting the source to `cloudticket-ec2-sg`.
* **13:51 UTC** - Ran `mysql -h ... -u admin -p` again from EC2. Connected immediately and queried the tickets table without issues.

---

## Root Cause
AWS Security Groups are stateful and deny all inbound traffic by default. When the inbound rule for port 3306 was deleted, the database stopped accepting incoming TCP SYN packets from the EC2 instance. 

Because security groups silently drop unauthorized packets instead of actively rejecting them (like a firewall sending a TCP RST), the client kept retrying until it hit the 60-second system timeout, returning Linux error 110 (`Connection timed out`).

---

## Resolution & Verification
Restored the security group chaining rule on `cloudticket-db-sg`:
* **Type:** MySQL/Aurora
* **Port:** 3306
* **Protocol:** TCP
* **Source:** `cloudticket-ec2-sg` (`sg-099939d105b471d91`)

Saved screenshot proof to `screenshots/Security/Security Group Chaining Rule.png`.

### Verification
Connected back into MySQL from the EC2 instance and ran a quick query:
```sql
USE ticketdb;
SELECT * FROM tickets;
```

The handshake finished in under 2ms and returned our records:
```text
+----+----------------------------------------+-----------+
| id | title                                  | status    |
+----+----------------------------------------+-----------+
|  1 | Production API Latency Investigation   | RESOLVED  |
|  2 | Automated Database Backup Verification | COMPLETED |
+----+----------------------------------------+-----------+
2 rows in set (0.00 sec)
```

---

## Lessons Learned & Next Steps

1. **Move to Terraform (v3.0):** Manual changes in the AWS Console are error-prone and leave no audit trail. Managing security groups with Terraform will allow us to detect drift automatically and prevent accidental deletions.
2. **Alerting:** Set up a CloudWatch alarm on `DatabaseConnections` so that if connections drop to 0 during active hours, on-call engineers get notified right away.
3. **Reference-based rules:** Always chain security groups by ID rather than relying on IP CIDRs. That way, newly launched EC2 instances from Auto Scaling can talk to the database without updating firewall rules.
