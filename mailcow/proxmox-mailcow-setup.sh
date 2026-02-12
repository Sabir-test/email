#!/bin/bash
# =============================================================================
# PROXMOX VM CREATION FOR MAILCOW EMAIL SERVER - MBS.RENT
# Creates optimized Ubuntu 24.04 LTS VM for email hosting
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   PROXMOX MAILCOW VM SETUP - MBS.RENT                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
# CONFIGURATION
# =============================================================================

# VM Settings
VM_ID=200                          # Change if ID is taken
VM_NAME="mailcow-mbs"
VM_DESCRIPTION="Mailcow Email Server for mbs.rent"
STORAGE="local-lvm"                # Change to your storage name
ISO_STORAGE="local"                # Where Ubuntu ISO is stored
ISO_FILE="ubuntu-24.04-live-server-amd64.iso"

# Resources
CORES=4                            # 4 vCPUs recommended (min 2)
MEMORY=8192                        # 8GB RAM (min 6GB)
DISK_SIZE=100                      # 100GB disk (min 50GB)

# Network
BRIDGE="vmbr0"                     # Your network bridge
VLAN_TAG=""                        # Optional VLAN tag
STATIC_IP="192.168.1.200/24"       # Change to your network
GATEWAY="192.168.1.1"              # Change to your gateway
DNS="1.1.1.1,8.8.8.8"             # Cloudflare & Google DNS

# Email Configuration
HOSTNAME="mail.mbs.rent"
DOMAIN="mbs.rent"

# =============================================================================
# FUNCTIONS
# =============================================================================

check_proxmox() {
    if ! command -v pvesh &> /dev/null; then
        echo -e "${RED}❌ This script must run on a Proxmox host${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Proxmox detected${NC}"
}

check_iso() {
    if ! pvesm list $ISO_STORAGE | grep -q "$ISO_FILE"; then
        echo -e "${RED}❌ Ubuntu ISO not found: $ISO_STORAGE:iso/$ISO_FILE${NC}"
        echo ""
        echo "Download it with:"
        echo "cd /var/lib/vz/template/iso"
        echo "wget https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
        exit 1
    fi
    echo -e "${GREEN}✓ Ubuntu ISO found${NC}"
}

check_vm_id() {
    if qm status $VM_ID &> /dev/null; then
        echo -e "${RED}❌ VM ID $VM_ID already exists${NC}"
        echo "Change VM_ID in this script or destroy existing VM:"
        echo "qm destroy $VM_ID"
        exit 1
    fi
    echo -e "${GREEN}✓ VM ID $VM_ID available${NC}"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

echo -e "${YELLOW}[1/5] Validating environment...${NC}"
check_proxmox
check_iso
check_vm_id

echo -e "${YELLOW}[2/5] Creating VM...${NC}"

# Create VM
qm create $VM_ID \
    --name $VM_NAME \
    --description "$VM_DESCRIPTION" \
    --ostype l26 \
    --memory $MEMORY \
    --cores $CORES \
    --cpu host \
    --sockets 1 \
    --numa 0 \
    --balloon 2048 \
    --net0 virtio,bridge=$BRIDGE \
    --scsihw virtio-scsi-pci \
    --boot order=scsi0 \
    --agent 1

echo -e "${GREEN}✓ VM created (ID: $VM_ID)${NC}"

echo -e "${YELLOW}[3/5] Adding storage...${NC}"

# Add disk
qm set $VM_ID --scsi0 $STORAGE:$DISK_SIZE,format=raw,iothread=1,discard=on,ssd=1

# Add CD-ROM with Ubuntu ISO
qm set $VM_ID --ide2 $ISO_STORAGE:iso/$ISO_FILE,media=cdrom

echo -e "${GREEN}✓ Storage configured${NC}"

echo -e "${YELLOW}[4/5] Configuring boot options...${NC}"

# Set boot order and VGA
qm set $VM_ID \
    --boot order=scsi0\;ide2 \
    --vga std

echo -e "${GREEN}✓ Boot configured${NC}"

echo -e "${YELLOW}[5/5] Generating cloud-init configuration...${NC}"

# Create cloud-init config file
cat > /tmp/mailcow-cloud-init.yaml <<EOF
#cloud-config
hostname: ${HOSTNAME}
fqdn: ${HOSTNAME}
manage_etc_hosts: true

users:
  - name: mailcow
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - YOUR_SSH_PUBLIC_KEY_HERE

# Set timezone
timezone: Asia/Qatar

# Update packages
package_update: true
package_upgrade: true

# Install required packages
packages:
  - qemu-guest-agent
  - curl
  - wget
  - git
  - net-tools

# Network configuration
network:
  version: 2
  ethernets:
    ens18:
      addresses:
        - ${STATIC_IP}
      gateway4: ${GATEWAY}
      nameservers:
        addresses: [${DNS}]

# Run on first boot
runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - hostnamectl set-hostname ${HOSTNAME}
  - echo "${STATIC_IP%%/*} ${HOSTNAME} ${VM_NAME}" >> /etc/hosts

# Disable cloud-init after first boot
final_message: "Mailcow VM ready for deployment. Install with: curl -L https://get.docker.com | sh"
EOF

echo -e "${GREEN}✓ Cloud-init template created${NC}"

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              VM CREATED SUCCESSFULLY                      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}VM Details:${NC}"
echo "  ID:       $VM_ID"
echo "  Name:     $VM_NAME"
echo "  Hostname: $HOSTNAME"
echo "  Memory:   ${MEMORY}MB"
echo "  CPU:      ${CORES} cores"
echo "  Disk:     ${DISK_SIZE}GB"
echo "  IP:       $STATIC_IP"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Start VM and install Ubuntu:"
echo "   qm start $VM_ID"
echo "   # Open console and complete Ubuntu installation"
echo ""
echo "2. After Ubuntu installation, SSH into VM:"
echo "   ssh mailcow@${STATIC_IP%%/*}"
echo ""
echo "3. Run Mailcow installation:"
echo "   curl -o install-mailcow.sh https://YOUR_SCRIPT_URL"
echo "   chmod +x install-mailcow.sh"
echo "   sudo ./install-mailcow.sh"
echo ""
echo -e "${RED}⚠️  IMPORTANT:${NC}"
echo "  - Configure port forwarding from your router/firewall to VM IP"
echo "  - Forward ports: 25, 80, 443, 587, 993, 995"
echo "  - Set PTR record at your ISP (if self-hosted)"
echo "  - Or use a VPS as mail relay if ISP blocks port 25"
echo ""
