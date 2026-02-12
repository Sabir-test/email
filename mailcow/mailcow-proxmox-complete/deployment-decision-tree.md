# PROXMOX MAILCOW DEPLOYMENT - DECISION TREE
## Choose Your Path

```
START: Where is your Proxmox?
│
├─ HOME/OFFICE NETWORK
│  │
│  ├─ Do you have STATIC PUBLIC IP?
│  │  │
│  │  ├─ YES → Can ISP set PTR record?
│  │  │  │
│  │  │  ├─ YES → ✅ DIRECT SETUP (Best case)
│  │  │  │         • Port forward → VM
│  │  │  │         • PTR via ISP
│  │  │  │         • Cost: $0/month
│  │  │  │
│  │  │  └─ NO → ⚠️ VPS RELAY SETUP
│  │  │            • Rent VPS ($5/mo)
│  │  │            • VPS has PTR
│  │  │            • Tunnel home → VPS
│  │  │            • Cost: ~$5/month
│  │  │
│  │  └─ NO (Dynamic IP) → Test port 25 access
│  │     │
│  │     ├─ Port 25 OPEN → 🔄 DDNS SETUP
│  │     │  │              • Use Cloudflare DDNS
│  │     │  │              • VPS relay recommended
│  │     │  │              • Cost: $0-5/month
│  │     │  │
│  │     │  └─ Port 25 BLOCKED → 🚫 VPS RELAY REQUIRED
│  │                              • ISP blocks email
│  │                              • Must use VPS relay
│  │                              • Cost: $5-10/month
│  │
│  └─ RECOMMENDED: Option B (Hybrid)
│
└─ CLOUD/VPS HOSTED PROXMOX
   │
   ├─ Provider: Hetzner/OVH/etc
   │  │
   │  └─ ✅ BEST OPTION (Easiest)
   │     • Static IP included
   │     • PTR easily set
   │     • No port blocking
   │     • Professional setup
   │     • Cost: $15-30/month
   │
   └─ RECOMMENDED: Option C (Cloud)
```

---

## 🎯 OPTION COMPARISON

### **Option A: Direct Home Setup**
```
[Internet] → [Router] → [Proxmox] → [Mailcow VM]
                ↓
         Port Forwarding
         PTR via ISP (if possible)
```

**Requirements:**
✅ Static public IP
✅ ISP allows port 25
✅ ISP can set PTR record
✅ Reliable internet/power
❌ If ANY of above missing → Use Option B

**Pros:** Free, full control
**Cons:** ISP dependency, residential limitations

---

### **Option B: Hybrid (Home Proxmox + VPS Relay)**
```
[Internet] → [Cheap VPS $5] → [Encrypted Tunnel] → [Home Proxmox] → [Mailcow VM]
                ↓                                           ↓
           Static IP                                  Actual Storage
           PTR Set                                    Full Control
           Relay Only
```

**Requirements:**
✅ Home internet (any type)
✅ Small VPS ($5/month - Hetzner CX11)
✅ Wireguard tunnel

**Pros:** 
- Bypass ISP restrictions
- Data stays at home
- Professional delivery
- Low cost

**Cons:** 
- Slightly complex setup
- Small monthly cost

**Best for:** Home Proxmox with ISP issues

---

### **Option C: Cloud Proxmox VPS**
```
[Internet] → [Cloud VPS Proxmox] → [Mailcow VM]
                ↓
         Everything Professional
         Static IP, PTR, No Blocks
```

**Requirements:**
✅ VPS with Proxmox (~$20-30/month)
✅ Good specs (4 CPU, 8GB RAM)

**Pros:**
- No ISP issues
- Professional setup
- Easy PTR
- Best deliverability

**Cons:**
- Monthly cost higher
- Data not at home

**Best for:** Production business use

---

## 🔍 QUICK DECISION GUIDE

### **Answer These 3 Questions:**

**Q1: Where is Proxmox?**
- Home/Office → Continue
- Cloud VPS → Choose Option C

**Q2: Test port 25**
```bash
telnet smtp.gmail.com 25
```
- Works → Continue
- Times out → Must use Option B

**Q3: Can you get static IP + PTR?**
- Yes from ISP → Option A
- No → Option B

---

## 💰 COST COMPARISON

| Option | Setup | Monthly | Best For |
|--------|-------|---------|----------|
| A - Direct | Easy | $0 | Business fiber with static IP |
| B - Hybrid | Medium | $5 | Home with ISP restrictions |
| C - Cloud | Easy | $25 | Production, no home server |

---

## 🚀 MY RECOMMENDATION FOR YOU

Based on typical home setups:

**Most likely: Option B (Hybrid)**

Why?
- ISPs usually block port 25 for residential
- Dynamic IP common at home
- PTR records difficult to get from ISP
- Best balance: cost vs control

**Setup:**
1. Create VM in your home Proxmox
2. Rent Hetzner Cloud CX11 ($3.79/month)
3. Setup Wireguard tunnel
4. Configure Postfix relay on VPS
5. Set PTR on Hetzner (free, takes 5 minutes)

---

## 📋 INFORMATION I NEED FROM YOU

To give exact instructions, tell me:

1. **Proxmox Location:**
   - [ ] Home network
   - [ ] Cloud VPS (which provider?)

2. **IP Situation:**
   - [ ] Static IP (what is it?)
   - [ ] Dynamic IP

3. **Port 25 Test:**
   ```bash
   telnet smtp.gmail.com 25
   ```
   - [ ] Works (connected)
   - [ ] Blocked (timeout)

4. **Network Details:**
   - Router IP: ?
   - Proxmox IP: ?
   - Desired VM IP: ?
   - Network range: 192.168.1.x or different?

5. **PTR Capability:**
   - [ ] ISP can set PTR
   - [ ] ISP cannot set PTR
   - [ ] Don't know

---

## ⚡ NEXT ACTIONS

**Once you answer above:**

I will:
1. ✅ Create all DNS records via Cloudflare MCP
2. ✅ Provide exact VM configuration
3. ✅ Give router port forwarding rules
4. ✅ Setup relay if needed
5. ✅ Walk through complete installation

**Then you:**
1. Run Proxmox VM creation script
2. Configure network
3. Install Mailcow
4. Done! ✨

Ready to answer the questions? 🎯
