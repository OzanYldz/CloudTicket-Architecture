# CloudTicket: Highly Available AWS Web Infrastructure

## About this project
This is my AWS infrastructure project. Instead of following isolated tutorials, I wanted to build a realistic environment that combines networking, load balancing, Linux administration, Auto Scaling, and managed databases into a cohesive 3-tier architecture.

The scenario simulates an online ticket platform experiencing sudden traffic spikes. The goal was not only to make it work, but also to understand *why* each AWS service was needed and how they connect under real production conditions.

```mermaid
graph TD
    Client([Internet / Users]) --> |HTTP:80| IGW[Internet Gateway]
    
    subgraph "AWS Cloud"
        IGW --> ALB
        
        subgraph "Virtual Private Cloud (VPC)"
            ALB(Application Load Balancer)
            
            subgraph "Web Tier - Public Subnets"
                subgraph "Public Subnet (us-east-1a)"
                    EC2_1[EC2 Web Server - Nginx]
                end
                
                subgraph "Public Subnet (us-east-1b)"
                    EC2_2[EC2 Web Server - Nginx]
                end
            end
            
            ALB -->|Health Checks & Routing| EC2_1
            ALB -->|Health Checks & Routing| EC2_2

            subgraph "Database Tier - Private Subnets"
                subgraph "Private Subnet (us-east-1a)"
                    RDS_Primary[(Amazon RDS MySQL - Primary)]
                end
                
                subgraph "Private Subnet (us-east-1b)"
                    RDS_Standby[(Amazon RDS MySQL - Standby)]
                end
            end
            
            EC2_1 -->|MySQL:3306 (SG Chained)| RDS_Primary
            EC2_2 -->|MySQL:3306 (SG Chained)| RDS_Primary
            RDS_Primary -.->|Sync Replication| RDS_Standby
        end
    end
```

![Browser Test](screenshots/Extra/Browser%20Test%20ALB.png)

## 📌 Problem Statement

Imagine 300,000 users attempting to access the ticket sales website within a 5 minute window for a popular concert. A traditional single server architecture would immediately crash under the load, resulting in lost revenue and a poor user experience. 

**Challenges of a single server setup:**
- Single Point of Failure (SPOF).
- Inability to handle sudden traffic bursts.
- Wasted infrastructure costs during low traffic periods.
- Risk of data loss when application and database share the same host.

---

## 🏗️ Architecture Design & Decisions

To solve this, I designed an elastic, highly available 3-tier web infrastructure.

**Why Application Load Balancer (ALB)?**  
Instead of exposing EC2 instances directly to users, I chose an ALB because it acts as the public entry point for all incoming HTTP traffic. It provides continuous health checks and distributes traffic evenly across multiple Availability Zones, ensuring users never hit an unhealthy server.

**Why Auto Scaling Group (ASG)?**  
Ticket sales create unpredictable traffic spikes. I configured Auto Scaling to automatically provision additional EC2 instances when average CPU utilization exceeds 50%, and terminate them during idle periods. This maintains responsiveness during traffic surges while keeping costs low when idle.

**Why Custom AMI?**  
Creating an Amazon Machine Image (AMI) ensures that every new EC2 instance launched by the Auto Scaling Group is identical. It boots up already configured with the Nginx web server and application code, ready to serve traffic immediately without manual bootstrapping delays.

**Why Amazon RDS instead of MySQL on EC2? (v2.0)**  
Running a database on an EC2 instance creates operational overhead: OS patching, manual backups, and disk management are your responsibility, and a hardware failure means data loss. Amazon RDS provides automated backups, point in time recovery, and Multi-AZ synchronous replication with automatic failover in under 60 seconds if the primary host goes down.

**Why Security Group Chaining? (v2.0)**  
Instead of whitelisting specific IP addresses on the database firewall (port 3306), I chained the database security group directly to the web security group (`cloudticket-ec2-sg`). Because Auto Scaling dynamically launches and terminates EC2 instances with changing private IPs, security groups linked by ID ensure that any authorized web server can talk to the database with zero manual IP management.

---

## 📸 Implementation & Proof of Work

### 1. Networking (VPC, Subnets, Security)
I created a custom VPC to isolate the environment. Two public subnets were deployed across different Availability Zones to satisfy the Load Balancer's High Availability requirement. I configured strict Security Groups to allow HTTP traffic via the ALB and SSH access only to my specific IP.

| VPC | Subnets | Route Tables |
|:---:|:---:|:---:|
| ![VPC](screenshots/Networking/VPC.png) | ![Subnets](screenshots/Networking/Subnets.png) | ![Route Tables](screenshots/Networking/Route%20Tables.png) |

### 2. Compute (EC2, Launch Templates, AMI)
I launched a base Ubuntu EC2 instance, securely accessed it via SSH, and configured an Nginx web server. I then generated a custom AMI from this instance to serve as the golden image for the Auto Scaling Group.

| Running Instances | Launch Template | Custom AMI |
|:---:|:---:|:---:|
| ![EC2](screenshots/Compute/EC2%20Instances%20Running.png) | ![Launch Template](screenshots/Compute/Launch%20Template.png) | ![AMI](screenshots/Compute/AMI.png) |

### 3. Application Load Balancer (ALB)
The ALB routes traffic only to healthy instances registered in the Target Group. The Resource Map below clearly demonstrates the successful routing of HTTP:80 traffic to multiple healthy targets across different Availability Zones.

| ALB List | Resource Map | Target Group Health |
|:---:|:---:|:---:|
| ![ALB](screenshots/Load%20Balancing/ALB%20List.png) | ![ALB Map](screenshots/Load%20Balancing/ALB%20Resource%20Map.png) | ![TG Health](screenshots/Load%20Balancing/Target%20Group%20Healthy.png) |

### 4. Auto Scaling Group (ASG)
The ASG is configured with a minimum capacity of 1, a desired capacity of 2, and a maximum capacity of 4 instances. 

| ASG Capacity | ASG Details |
|:---:|:---:|
| ![ASG Capacity](screenshots/Auto%20Scaling/ASG%20Capacity%20Details.png) | ![ASG List](screenshots/Auto%20Scaling/ASG%20List.png) |

### 5. Database Layer (Amazon RDS & Security Group Chaining - v2.0)
To transform CloudTicket into a true 3-tier architecture, I provisioned an Amazon RDS MySQL database placed exclusively inside isolated private subnets across two Availability Zones (`us-east-1a` and `us-east-1b`) using a DB Subnet Group. 

To enforce strict least privilege, the database has `Publicly Accessible: No` and allows inbound traffic on port 3306 **only** from the `cloudticket-ec2-sg` Security Group ID. This isolates customer data completely from the public internet while allowing the web tier seamless internal access.

| RDS MySQL (Available) | Database Connection & Query | Restored Chaining Rule |
|:---:|:---:|:---:|
| ![RDS MySQL](screenshots/Database/RDS%20MySQL%20Available.png) | ![EC2 Query](screenshots/Compute/EC2%20to%20RDS%20Connection%20and%20Query.png) | ![SG Rule](screenshots/Security/Security%20Group%20Chaining%20Rule.png) |

---

## 🛠️ Challenges & Troubleshooting

**Challenge 1: Windows SSH Permission Denied**  
While attempting to connect to the initial EC2 instance via SSH on a Windows machine, AWS rejected the connection because the `.pem` key file had overly permissive inherited permissions.
* **Solution:** I utilized Windows Command Prompt (`icacls`) to strip inherited permissions, explicitly grant access only to my current user, and remove all other access rights.

![Permission Error](screenshots/Error/SSH%20Permission%20Error.png)

**Challenge 2: ALB Health Check Failures**  
Initially, instances might fail the Load Balancer health checks if security is misconfigured.
* **Solution:** I ensured that the Security Group attached to the EC2 instances explicitly allowed inbound HTTP (port 80) traffic originating directly from the ALB's Security Group, rather than keeping it open to the entire internet.

**Challenge 3: Database Connection Timeout (Chaos Test & Incident 001)**  
To test how firewall misconfigurations behave in production, I intentionally deleted the port 3306 inbound rule on `cloudticket-db-sg`. 
* **Symptom:** The EC2 web client hung for 60 seconds during the TCP handshake before returning `ERROR 2003 (110 "Connection timed out")`. Because AWS Security Groups silently drop unauthorized packets rather than actively rejecting them, the client kept retrying until the Linux TCP timeout expired.
* **Solution:** Verified DNS resolution and route tables (both were healthy), spotted the missing inbound rule in the database security group, and restored the security group chaining rule pointing to `cloudticket-ec2-sg`.
* **Incident writeup:** Documented the full incident, timeline, and preventative measures in [INCIDENT-001-RDS-TIMEOUT.md](INCIDENT-001-RDS-TIMEOUT.md).

![Chaos Timeout](screenshots/Security/Chaos%20Test%20Connection%20Timeout.png)

---

## 📚 What I Learned

During this project, I gained practical experience in:
- Designing custom VPCs with public and private subnets across multiple AZs.
- Building highly available architectures with Application Load Balancers and Target Groups.
- Creating Launch Templates, custom AMIs, and Auto Scaling Dynamic Policies.
- Provisioning managed databases with Amazon RDS MySQL and DB Subnet Groups.
- Implementing Security Group Chaining for dynamic firewall rules linked by security group ID.
- Conducting chaos engineering experiments to observe failure modes and writing incident postmortems.
- Managing Linux servers via SSH, resolving permission barriers, and configuring Nginx.

---

## 📂 Repository Structure

```text
CloudTicket-Architecture/
├── README.md
├── INCIDENT-001-RDS-TIMEOUT.md
├── index.html
└── screenshots/
    ├── Auto Scaling/
    ├── Compute/
    ├── Database/
    ├── Error/
    ├── Extra/
    ├── Load Balancing/
    ├── Networking/
    └── Security/
```

---

## 🚀 Future Roadmap (Project Status)

✅ **Version 1.0:** Highly Available Web Infrastructure (ALB, ASG, Multi-AZ)  
✅ **Version 2.0:** 3-Tier RDS MySQL Architecture, Security Group Chaining & Chaos Postmortem (Current)  
⏳ **Version 3.0:** Infrastructure as Code (Migrate architecture to Terraform + Infracost + S3 Remote State)  
⏳ **Version 4.0:** Containerization & CI/CD (Docker, ECS/EKS)  
