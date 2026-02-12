# Terraform Configuration for Mailcow VM on Proxmox
# Automates VM creation with best practices

terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

# Proxmox Provider Configuration
provider "proxmox" {
  pm_api_url      = "https://YOUR_PROXMOX_IP:8006/api2/json"
  pm_user         = "root@pam"
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
}

# Variables
variable "proxmox_password" {
  description = "Proxmox root password"
  type        = string
  sensitive   = true
}

variable "vm_ip" {
  description = "Static IP for mailcow VM"
  type        = string
  default     = "192.168.1.200"
}

variable "gateway" {
  description = "Network gateway"
  type        = string
  default     = "192.168.1.1"
}

# Mailcow VM Resource
resource "proxmox_vm_qemu" "mailcow" {
  name        = "mailcow-mbs"
  target_node = "pve"  # Change to your Proxmox node name
  vmid        = 200
  desc        = "Mailcow Email Server for mbs.rent - Managed by Terraform"

  # OS Settings
  clone   = "ubuntu-2404-template"  # Create template first
  os_type = "cloud-init"
  
  # CPU Configuration
  cores   = 4
  sockets = 1
  cpu     = "host"
  
  # Memory Configuration
  memory  = 8192
  balloon = 2048
  
  # Disk Configuration
  disk {
    size    = "100G"
    type    = "scsi"
    storage = "local-lvm"
    iothread = 1
    discard  = "on"
    ssd      = 1
  }
  
  # Network Configuration
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
  
  # Cloud-Init Configuration
  cloudinit_cdrom_storage = "local-lvm"
  
  ipconfig0 = "ip=${var.vm_ip}/24,gw=${var.gateway}"
  
  nameserver = "1.1.1.1 8.8.8.8"
  
  sshkeys = file("~/.ssh/id_rsa.pub")
  
  ciuser = "mailcow"
  
  # Startup Configuration
  onboot   = true
  startup  = "order=2,up=60"
  
  # Enable QEMU Guest Agent
  agent = 1
  
  # Lifecycle
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
  
  # Provisioner to run Mailcow installation
  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname mail.mbs.rent",
      "curl -o /tmp/install-mailcow.sh https://YOUR_SCRIPT_URL",
      "chmod +x /tmp/install-mailcow.sh",
      "echo 'Mailcow VM ready. Run: sudo /tmp/install-mailcow.sh'",
    ]
    
    connection {
      type        = "ssh"
      user        = "mailcow"
      private_key = file("~/.ssh/id_rsa")
      host        = var.vm_ip
    }
  }
}

# Outputs
output "vm_ip" {
  value = var.vm_ip
}

output "vm_id" {
  value = proxmox_vm_qemu.mailcow.vmid
}

output "next_steps" {
  value = <<EOT
  
  VM Created Successfully!
  
  1. SSH into VM:
     ssh mailcow@${var.vm_ip}
  
  2. Install Mailcow:
     sudo /tmp/install-mailcow.sh
  
  3. Configure port forwarding on router
  
  4. Setup DNS records via Cloudflare
  
  EOT
}
