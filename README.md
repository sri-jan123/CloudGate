# CloudGate — Secure Azure Private Network with Self-Managed VPN

CloudGate is a secure Azure networking project that provides authenticated remote access to private cloud resources using a **self-managed Pritunl/OpenVPN gateway**.

The project places the application VM inside a private Azure subnet with **no public IP address**. Authorized users connect through the VPN gateway and can securely access the application using its private IP. Azure infrastructure is provisioned and managed using **Terraform**.

---

## 🏗️ Architecture

<img width="1536" height="1024" alt="b479af24-4765-4387-94ea-8a0438344280" src="https://github.com/user-attachments/assets/457cd3ac-71e5-4623-9b03-f75ae48934d3" />


## 🎯 Problem Statement

Publicly exposing every cloud VM increases the attack surface and makes private infrastructure harder to control.

CloudGate solves this by keeping the application VM private:

```text
Before:

Internet → Public IP → Application VM
```

```text
After:

Internet → Pritunl VPN → Private VNet → Application VM
```

Only the VPN gateway requires a public IP. The application VM remains accessible through its private IP after VPN authentication.

This architecture is useful for:

- Private application environments
- Remote administration of cloud VMs
- Internal dashboards and tools
- Development and staging environments
- Private APIs
- Database administration
- Internal DevOps infrastructure

---

## 🚀 Key Features

- Private application VM with **no public IP**
- Self-managed VPN gateway using **Pritunl/OpenVPN**
- Individual VPN users with separate profiles
- Private Azure VNet with subnet segmentation
- VPN-to-VNet routing
- NAT through the VPN gateway
- Linux IP forwarding
- Azure NIC IP forwarding
- Network Security Group restrictions
- Terraform-managed Azure infrastructure
- Secure SSH and HTTP access through the VPN

---

## 🔐 How It Works

### 1. User connects to the VPN

A user imports their Pritunl `.tar` profile into the Pritunl Client and authenticates.

```text
User
  │
  ▼
Pritunl Client
  │
  ▼
Pritunl VPN
  │
  └── VPN IP: 10.30.0.x
```

### 2. VPN routes traffic to the Azure private subnet

Pritunl routes traffic destined for:

```text
10.0.2.0/24
```

through the Azure VNet.

### 3. NAT forwards traffic through the Pritunl VM

The VPN client may have an address such as:

```text
10.30.0.2
```

while the application VM sees the connection from the Pritunl VM's private address:

```text
10.0.1.4
```

The traffic flow is therefore:

```text
VPN Client
10.30.0.2
    │
    ▼
Pritunl
10.0.1.4
    │
    │ NAT
    ▼
Application VM
10.0.2.4
```

### 4. NSG controls access

The application VM's NSG allows required traffic from the Pritunl gateway:

```text
Source:      10.0.1.4
Destination: Application VM
Port:        22 / 80
Protocol:    TCP
```

The application VM itself has no public IP.

### 5. User accesses the application

After connecting to the VPN, an authorized user can access:

```text
http://10.0.2.4
```

The request travels through the VPN gateway to the private application VM.

---

## 👤 Authentication Model

The project uses multiple layers of authentication.

| Identity | Purpose |
|---|---|
| Azure account | Manage Azure resources |
| Pritunl user | Authenticate to the VPN |
| Linux user | Access the Ubuntu VM |
| SSH key | Authenticate SSH access |

A Pritunl user does **not** automatically become a Linux user on the application VM.

For example:

```text
Pritunl User: srijan
        ↓
VPN Authentication
        ↓
Private Network Access
```

while:

```text
Linux User: adminuser
        ↓
SSH Authentication
        ↓
Application VM
```

---

## 👥 Adding VPN Users

To provide VPN access to another user:

1. Create a user under the Pritunl organization.
2. Generate/download the user's client profile.
3. Securely provide the `.tar` profile to the user.
4. The user installs Pritunl Client.
5. The user imports the profile.
6. The user connects to the VPN.
7. The user can access authorized private resources.

Example:

```text
srijan       → 10.30.0.2
developer1   → 10.30.0.3
developer2   → 10.30.0.4
```

VPN access and SSH access should be managed separately.

---

## 🏗️ Azure Infrastructure

The Azure environment consists of:

```text
Azure
│
└── example-resources
    │
    ├── example-network
    │   ├── 10.0.1.0/24
    │   │   └── Pritunl VM
    │   │
    │   └── 10.0.2.0/24
    │       └── Application VM
    │
    ├── Network Security Group
    │
    └── Public IP
        └── Pritunl VM only
```

The application VM does **not** have a public IP.

---

## 🧱 Terraform

Azure infrastructure is defined and managed using Terraform.

Typical workflow:

```powershell
terraform init
terraform plan
terraform apply
```

Terraform manages resources such as:

- Resource Group
- Virtual Network
- Subnets
- Network Interfaces
- Virtual Machines
- Network Security Group
- Public IP for the VPN gateway

The Pritunl application configuration is managed separately on the VPN server.

---

## ⚙️ Linux IP Forwarding

The Pritunl VM requires Linux IP forwarding.

Enable it:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

Make it persistent:

```bash
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-pritunl-forwarding.conf
sudo sysctl --system
```

Verify:

```bash
cat /proc/sys/net/ipv4/ip_forward
```

Expected:

```text
1
```

---

## ⚙️ Azure NIC IP Forwarding

The Pritunl NIC is configured with IP forwarding enabled:

```hcl
ip_forwarding_enabled = true
```

This allows the Pritunl VM to function as a network gateway between the VPN network and the Azure VNet.

---

## 🔒 Network Security

The application VM is protected using an Azure Network Security Group.

Example configuration:

| Rule | Source | Destination Port | Access |
|---|---|---:|---|
| SSH | `10.0.1.4` | `22` | Allow |
| HTTP | `10.0.1.4` | `80` | Allow |

The source is restricted to the Pritunl gateway rather than allowing traffic from arbitrary Internet addresses.

---

## 🧪 Validation

After connecting to the VPN, verify connectivity to the private VM.

### Test SSH

```powershell
Test-NetConnection 10.0.2.4 -Port 22
```

Expected:

```text
TcpTestSucceeded : True
```

### Test HTTP

```powershell
Test-NetConnection 10.0.2.4 -Port 80
```

Expected:

```text
TcpTestSucceeded : True
```

### Access the application

Open in a browser while connected to the VPN:

```text
http://10.0.2.4
```

### SSH into the private VM

```powershell
ssh adminuser@10.0.2.4
```

### Verify the VM has no public IP

```powershell
az vm show -d -g example-resources -n example-machine --query publicIps -o tsv
```

No output indicates that the application VM has no public IP.

---

## 🔄 Traffic Flow

### SSH

```text
Windows Laptop
     │
     │ Pritunl VPN
     ▼
10.30.0.2
     │
     ▼
Pritunl VM
10.0.1.4
     │
     │ NAT
     ▼
Application VM
10.0.2.4:22
```

### HTTP

```text
Browser
   │
   │ http://10.0.2.4
   ▼
VPN Client
   │
   ▼
Pritunl
   │
   ▼
10.0.2.4:80
   │
   ▼
Nginx / Application
```

---

## ☁️ Self-Managed vs Managed VPN

This project uses a **self-managed VPN gateway** instead of Azure's managed VPN Gateway service.

### Self-Managed Architecture

```text
Azure VM
   │
   └── Pritunl/OpenVPN
```

You manage:

- VPN software
- Operating system
- VPN users
- Routing
- NAT
- Updates
- Configuration
- Availability
- Troubleshooting

### Managed Azure VPN Gateway

Azure manages the underlying VPN gateway infrastructure and service.

Therefore, this project can be described as:

> **A self-managed VPN gateway architecture on Azure using Pritunl/OpenVPN.**

---

## 🛠️ Technologies Used

- **Microsoft Azure**
- **Azure Virtual Network**
- **Azure Virtual Machines**
- **Azure Network Security Groups**
- **Azure CLI**
- **Terraform**
- **Ubuntu 24.04**
- **Pritunl**
- **OpenVPN**
- **Nginx**
- **SSH**
- **TCP/IP Networking**

---
