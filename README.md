# AWS Free-Tier Load-Balanced Website (Terraform)

> A beginner-friendly Terraform project that spins up two t2.micro EC2 instances (Amazon Linux 2023) running Nginx “Hello” pages, fronts them with an Application Load Balancer (ALB), publishes a free Dynamic DNS CNAME via ClouDNS, and demonstrates real-time load testing with CloudWatch metrics.

---

## 🚀 What This Repo Demonstrates

1. **Terraform ≥1.6** environment setup  
2. **VPC** with two public subnets (one per AZ)  
3. **EC2** instances (Amazon Linux 2023) bootstrapped by `userdata.sh`  
4. **Application Load Balancer (ALB)** distributing port 80 traffic  
5. **ClouDNS** (free) CNAME → ALB DNS  
6. **`load_test.sh` script** to simulate 1 hour of Nginx requests  
7. **CloudWatch graphs** for RequestCount & TargetResponseTime

---

## 📑 Architecture Diagram

## mermaid

graph LR
  %% ────────────────────────
  %% VPC Subgraph
  subgraph VPC
    VPCLabel["10.0.0.0/16 VPC (us-east-1)"]
    AZ1["AZ us-east-1a"]
    AZ2["AZ us-east-1b"]
    Subnet1["10.0.1.0/24 (public)"]
    Subnet2["10.0.2.0/24 (public)"]
    VPCLabel --> AZ1
    VPCLabel --> AZ2
    AZ1 --> Subnet1
    AZ2 --> Subnet2
    Subnet1 --> EC2_0["EC2 (t2.micro)"]
    Subnet2 --> EC2_1["EC2 (t2.micro)"]
  end

  %% ────────────────────────────────
  %% Internet Node
  Internet["🌐 Internet"]

  %% ────────────────────────
  %% DNS (CNAME) Node
  DNS["ClouDNS CNAME\nalb.helloalb.ip-ddns.com"]

  %% Internet ↔ DNS ↔ ALB  (user↔DNS and DNS↔ALB can be bidirectional if you want to show
  %% that DNS “answers” back, but often we just draw Internet-->DNS-->ALB)
  Internet <--> DNS  
  DNS <--> ALB

  %% ────────────────────────────────
  %% Application Load Balancer
  ALB["Application Load Balancer"]

  %% ALB ↔ EC2 instances (to show request/response, health checks, etc.)
  EC2_0 <--> ALB
  EC2_1 <--> ALB

  %% ────────────────────────────────
  %% CloudWatch Metrics  (metrics flow one way, from ALB into CloudWatch)
  CW_REQ["NewConnectionCount"]
  CW_LAT["TargetResponseTime"]
  ALB --> CW_REQ
  ALB --> CW_LAT

