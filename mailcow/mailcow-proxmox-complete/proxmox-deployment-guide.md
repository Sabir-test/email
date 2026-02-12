# PROXMOX MAILCOW DEPLOYMENT GUIDE - MBS.RENT
## Production Email Server Architecture

---

## 🏗️ ARCHITECTURE OVERVIEW

```
Internet
    ↓
Router/Firewall (Port Forwarding)
    ↓
Proxmox Host (192.168.1.X)
    ↓
┌─────────────────────────────────────────┐
│ Mailcow VM (ID: 200)                    │
│ IP: 192.168.1.200                       │
│ Hostname: mail.mbs.rent                 │
│                                         │
│ ┌─────────────────────────────────┐    │
│ │  Ubuntu 24.04 LTS               │    │
│ │  - Docker Engine                │    │
│ │  - Mailcow Stack (17 containers)│    │
│ │  - 4 vCPU, 8GB RAM, 100GB Disk  │    │
│ └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
    ↓
Cloudflare DNS
    ↓
External Email Servers
```

---

## ⚙️ DEPLOYMENT OPTIONS

### **Option A: Self-Hosted (Home/Office Network)**

**Pros:**
- Full control
- No monthly VPS costs
- Unlimited bandwidth (usually)

**Cons:**
- ISP may block port 25 (CRITICAL issue)
- Dynamic IP requires DDNS
- Power/internet reliability concerns
- PTR record difficult to set

**Requirements:**
- Static or dynamic DNS
- Port forwarding capability
- ISP allows port 25 (test with: telnet smtp.gmail.com 25)

### **Option B: Hybrid (Proxmox at home + VPS as relay)**

**Pros:**
- Bypass ISP port 25 blocking
- Static IP from VPS
- PTR record easy to set
- Keep data at home

**Cons:**
- VPS relay cost (~$5-10/month)
- Slightly more complex setup

**Best for:** Home Proxmox setups where ISP blocks port 25

### **Option C: Proxmox VPS (Cloud hosted)**

**Pros:**
- Static IP included
- No port blocking
- PTR record easy to set
- Professional setup

**Cons:**
- Monthly VPS cost ($15-30/month for specs)

**Recommended Providers:**
- Hetzner Cloud (best value)
- DigitalOcean
- Vultr
- OVH

---

## 📋 PROXMOX VM SPECIFICATIONS

### **Recommended Configuration:**

| Resource | Minimum | Recommended | Production |
|----------|---------|-------------|------------|
| CPU      | 2 cores | 4 cores     | 6 cores    |
| RAM      | 6GB     | 8GB         | 12GB       |
| Disk     | 50GB    | 100GB       | 200GB      |
| Network  | 1 Gbps  | 1 Gbps      | 10 Gbps    |

### **Disk Layout:**
```
/ (root)          - 20GB
/var/lib/docker   - 60GB (container storage)
/opt/mailcow      - 10GB (application)
Swap              - 4GB
Free space        - 6GB (buffer)
```

---

## 🚀 STEP-BY-STEP DEPLOYMENT

### **PHASE 1: PROXMOX VM CREATION**

#### **Method 1: Automated Script (Recommended)**

1. SSH into Proxmox host:
```bash
ssh root@proxmox-host
```

2. Download and run setup script:
```bash
wget -O /tmp/proxmox-mailcow-setup.sh https://YOUR_SCRIPT
chmod +x /tmp/proxmox-mailcow-setup.sh
nano /tmp/proxmox-mailcow-setup.sh
```

3. Edit configuration:
```bash
# VM Settings
VM_ID=200                          # Change if needed
STORAGE="local-lvm"                # Your storage pool
STATIC_IP="192.168.1.200/24"       # Your network
GATEWAY="192.168.1.1"              # Your gateway
```

4. Run script:
```bash
/tmp/proxmox-mailcow-setup.sh
```

#### **Method 2: Manual Creation**

**Via Proxmox Web UI:**

1. **Create VM:**
   - Datacenter → Create VM
   - VM ID: 200
   - Name: mailcow-mbs
   - OS: Ubuntu 24.04
   - System: Default (SCSI)
   - Disk: 100GB, VirtIO SCSI
   - CPU: 4 cores, type=host
   - Memory: 8192MB
   - Network: VirtIO, Bridge=vmbr0

2. **Start VM & Install Ubuntu:**
   - Console → Start
   - Install Ubuntu Server
   - Hostname: mail.mbs.rent
   - Username: mailcow
   - Install OpenSSH server

3. **Network Configuration (Ubuntu):**
```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  version: 2
  ethernets:
    ens18:
      addresses:
        - 192.168.1.200/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
```

Apply:
```bash
sudo netplan apply
```

---

### **PHASE 2: NETWORK CONFIGURATION**

#### **Router/Firewall Port Forwarding**

Forward these ports from WAN → 192.168.1.200:

| Protocol | Port | Service      | Priority |
|----------|------|--------------|----------|
| TCP      | 25   | SMTP         | CRITICAL |
| TCP      | 80   | HTTP         | CRITICAL |
| TCP      | 443  | HTTPS        | CRITICAL |
| TCP      | 587  | Submission   | CRITICAL |
| TCP      | 993  | IMAPS        | Required |
| TCP      | 995  | POP3S        | Optional |
| TCP      | 110  | POP3         | Optional |
| TCP      | 143  | IMAP         | Optional |
| TCP      | 465  | SMTPS        | Optional |
| TCP      | 4190 | Sieve        | Optional |

**Example (pfSense):**
```
Firewall → NAT → Port Forward
Interface: WAN
Protocol: TCP
Destination Port: 25
Redirect Target IP: 192.168.1.200
Redirect Target Port: 25
Description: Mailcow SMTP
```

**Test Port 25 from outside:**
```bash
# From external network
telnet your-public-ip 25
```

#### **Proxmox Firewall (if enabled)**

Create rules for mailcow VM:

```bash
# Edit VM firewall
pvesh set /nodes/$(hostname)/qemu/$VM_ID/firewall/rules

# Or via GUI: VM → Firewall → Add rules
```

Allow:
- Direction: IN, Port: 25,80,443,587,993,995 (TCP)
- Direction: OUT, all traffic

---

### **PHASE 3: IP ADDRESS STRATEGY**

#### **Option A: Static Public IP (Best)**

**If you have static IP:**
1. Get IP from ISP
2. Set PTR record with ISP
3. Configure router port forwarding
4. Use IP directly for DNS A record

#### **Option B: Dynamic DNS (DDNS)**

**If dynamic IP (residential):**

1. **Choose DDNS Provider:**
   - Cloudflare (free, recommended)
   - DuckDNS (free)
   - No-IP (free)
   - Dynu (free)

2. **Install DDNS updater in Proxmox or VM:**

```bash
# Cloudflare DDNS script
cat > /usr/local/bin/cloudflare-ddns.sh <<'EOF'
#!/bin/bash
ZONE_ID="your_zone_id"
RECORD_ID="your_record_id"
API_TOKEN="your_api_token"
DOMAIN="mail.mbs.rent"

PUBLIC_IP=$(curl -s https://api.ipify.org)

curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
     -H "Authorization: Bearer $API_TOKEN" \
     -H "Content-Type: application/json" \
     --data "{\"type\":\"A\",\"name\":\"mail\",\"content\":\"$PUBLIC_IP\",\"proxied\":false}"
EOF

chmod +x /usr/local/bin/cloudflare-ddns.sh

# Cron every 5 minutes
crontab -e
*/5 * * * * /usr/local/bin/cloudflare-ddns.sh
```

3. **PTR Record Problem:**
   - Residential ISPs rarely allow PTR records
   - **Solution:** Use mail relay (see Phase 5)

#### **Option C: VPS Mail Relay**

**Best solution for home Proxmox + ISP restrictions:**

```
External Email
    ↓
Your Domain (mbs.rent)
    ↓
VPS Mail Relay (Static IP, PTR set)
    ↓
Your Home Proxmox Mailcow (via encrypted tunnel)
```

**Setup:**
1. Rent small VPS ($5/month) - Hetzner Cloud CX11
2. Install Postfix relay
3. Set PTR record at VPS provider
4. Configure Wireguard tunnel: VPS ↔ Home
5. Configure Mailcow to relay via VPS

---

### **PHASE 4: VM PREPARATION**

SSH into VM:
```bash
ssh mailcow@192.168.1.200
```

#### **1. System Updates:**
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git net-tools htop
```

#### **2. Set Hostname:**
```bash
sudo hostnamectl set-hostname mail.mbs.rent
sudo nano /etc/hosts
```

Add:
```
127.0.0.1 localhost
192.168.1.200 mail.mbs.rent mail
```

#### **3. Configure Firewall (UFW):**
```bash
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 25/tcp      # SMTP
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 587/tcp     # Submission
sudo ufw allow 993/tcp     # IMAPS
sudo ufw allow 995/tcp     # POP3S
sudo ufw enable
```

#### **4. Install QEMU Guest Agent:**
```bash
sudo apt install -y qemu-guest-agent
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent
```

#### **5. Optimize for Email:**
```bash
# Increase file limits
sudo tee -a /etc/security/limits.conf <<EOF
* soft nofile 65536
* hard nofile 65536
EOF

# Kernel parameters
sudo tee -a /etc/sysctl.conf <<EOF
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.netdev_max_backlog = 5000
EOF

sudo sysctl -p
```

---

### **PHASE 5: MAILCOW INSTALLATION**

Download installation script to VM:

```bash
cd ~
wget -O install-mailcow.sh https://YOUR_INSTALLATION_SCRIPT
chmod +x install-mailcow.sh
sudo ./install-mailcow.sh
```

Or run directly:
```bash
cd /opt
sudo git clone https://github.com/mailcow/mailcow-dockerized
cd mailcow-dockerized
sudo ./generate_config.sh
```

Follow prompts:
- Hostname: mail.mbs.rent
- Timezone: Asia/Qatar

Start Mailcow:
```bash
sudo docker compose pull
sudo docker compose up -d
```

---

### **PHASE 6: PROXMOX OPTIMIZATIONS**

#### **1. Backup Configuration:**

**In Proxmox UI:**
- Datacenter → Backup
- Add backup job:
  - Node: Your node
  - Storage: Backup storage
  - Schedule: Daily, 2:00 AM
  - Selection: VM 200
  - Retention: 7 days

#### **2. Resource Monitoring:**

Install Proxmox monitoring in VM:
```bash
# Install node_exporter for Grafana
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-*.tar.gz
sudo mv node_exporter-*/node_exporter /usr/local/bin/
```

#### **3. Snapshot Strategy:**

Before major changes:
```bash
# In Proxmox CLI
qm snapshot 200 before-update-$(date +%Y%m%d)
```

#### **4. CPU Pinning (Optional - Advanced):**

For dedicated cores:
```bash
qm set 200 --affinity 0,1,2,3
```

---

### **PHASE 7: TESTING CHECKLIST**

From VM:
```bash
# Test DNS resolution
dig mail.mbs.rent
dig mbs.rent MX

# Test port connectivity
telnet localhost 25
telnet localhost 587
telnet localhost 993

# Check Docker containers
cd /opt/mailcow-dockerized
docker compose ps

# View logs
docker compose logs -f
```

From external network:
```bash
# Test public access
telnet YOUR_PUBLIC_IP 25
curl -I https://mail.mbs.rent
```

---

## 🔐 SECURITY CONSIDERATIONS

### **Proxmox Host Security:**

```bash
# Keep updated
apt update && apt upgrade

# Disable root SSH (after setting up key auth)
nano /etc/ssh/sshd_config
# PermitRootLogin no

# Firewall at Proxmox level
pve-firewall enable
```

### **VM Security:**

- Separate network VLAN for mailcow (optional)
- Regular snapshots before updates
- Monitor resource usage
- Automated backups

### **Network Security:**

- Disable VM access from other VMs
- Use VPN for admin access
- Fail2Ban inside VM (included with Mailcow)

---

## 📊 MONITORING & MAINTENANCE

### **Proxmox Monitoring:**

Monitor in UI:
- CPU usage
- RAM usage
- Disk I/O
- Network traffic

### **Mailcow Monitoring:**

```bash
# Quick health check
cd /opt/mailcow-dockerized
docker compose ps
docker compose logs --tail=50

# Resource usage
docker stats

# Disk space
df -h
```

### **Automated Tasks:**

Setup cron in VM:
```bash
# Mailcow backup (daily 2 AM)
0 2 * * * cd /opt/mailcow-dockerized && ./helper-scripts/backup_and_restore.sh backup all

# Update check (weekly)
0 10 * * 0 cd /opt/mailcow-dockerized && ./update.sh --check

# Docker cleanup (monthly)
0 3 1 * * docker system prune -af
```

---

## 🚨 TROUBLESHOOTING

### **Issue: Cannot access VM from internet**

**Check:**
```bash
# 1. Firewall on Proxmox host
iptables -L -n | grep 192.168.1.200

# 2. VM firewall
sudo ufw status

# 3. Router port forwarding
# Log into router, verify rules
```

### **Issue: Port 25 blocked by ISP**

**Test:**
```bash
telnet smtp.gmail.com 25
```

**If timeout:** ISP blocks port 25

**Solutions:**
1. Contact ISP (business plan may allow)
2. Use VPS relay (recommended)
3. Use Cloudflare Email Routing + relay

### **Issue: VM performance slow**

**Check:**
```bash
# In Proxmox
qm monitor 200
info status

# CPU steal time
top
# Look for %st column
```

**Fix:**
- Reduce CPU overcommitment
- Use CPU pinning
- Upgrade host hardware

---

## 📚 NEXT STEPS

1. ✅ VM created and configured
2. ⏭️ **Configure DNS records (Cloudflare MCP)**
3. ⏭️ Set PTR record (ISP/VPS)
4. ⏭️ Install Mailcow
5. ⏭️ Create email accounts
6. ⏭️ Test deliverability

---

## 🎯 READY TO PROCEED?

**Tell me:**
1. Is Proxmox at home or cloud VPS?
2. Do you have static or dynamic IP?
3. What's your network setup? (192.168.1.x or different?)
4. Can you test port 25: `telnet smtp.gmail.com 25`

**Then I'll:**
1. Create DNS records via Cloudflare MCP
2. Provide exact port forwarding rules
3. Help with PTR/relay if needed
4. Walk through installation

Ready to continue? 🚀
