#!/usr/bin/env bash
# =============================================================================
# KVM/QEMU Cybersecurity Home Lab Setup — Arch Linux
# VM storage path: /mnt/nvme0n1p1/VMs/ (iso/ and disks/)
# =============================================================================
# Commands marked with [SUDO] require root. Run as root or use sudo.
# =============================================================================

set -e
VM_BASE="/mnt/nvme0n1p1/VMs"
ISO_DIR="${VM_BASE}/iso"
DISK_DIR="${VM_BASE}/disks"

# -----------------------------------------------------------------------------
# MOUNT NVME0N1P1 AND PERSIST IN FSTAB
# -----------------------------------------------------------------------------
# Create mount point if it doesn't exist, mount the partition, add to fstab.
# Replace /dev/nvme0n1p1 with your actual partition if different.
# Get UUID: lsblk -o NAME,UUID /dev/nvme0n1p1
# -----------------------------------------------------------------------------

# [SUDO] Create mount point
sudo mkdir -p /mnt/nvme0n1p1

# [SUDO] Mount nvme0n1p1 if not already mounted (idempotent)
if ! mountpoint -q /mnt/nvme0n1p1; then
  sudo mount /dev/nvme0n1p1 /mnt/nvme0n1p1
fi

# [SUDO] Add to fstab for persistence (using UUID; run: lsblk -o NAME,UUID /dev/nvme0n1p1 to get UUID)
# Only add if not already present. Replace YOUR_UUID with actual UUID from lsblk.
UUID=$(sudo findmnt -no UUID /mnt/nvme0n1p1 2>/dev/null || true)
if [ -n "$UUID" ] && ! grep -q "$UUID" /etc/fstab 2>/dev/null; then
  echo "# Add the line below to /etc/fstab (then run: sudo mount -a)"
  echo "# UUID=$UUID  /mnt/nvme0n1p1  ext4  defaults,noatime  0  2"
  echo "Run: echo 'UUID=$UUID  /mnt/nvme0n1p1  ext4  defaults,noatime  0  2' | sudo tee -a /etc/fstab"
fi
# Or add manually:
# echo 'UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  /mnt/nvme0n1p1  ext4  defaults,noatime  0  2' | sudo tee -a /etc/fstab
# sudo mount -a

# [SUDO] Create VM directory structure
sudo mkdir -p "${ISO_DIR}" "${DISK_DIR}"
sudo chown -R "$USER:$USER" "${VM_BASE}"

# -----------------------------------------------------------------------------
# STEP 1 — ISOLATED VIRTUAL NETWORK "isolab"
# -----------------------------------------------------------------------------
# Bridge: virbr1, Subnet: 192.168.100.0/24, Gateway: 192.168.100.1
# DHCP: 192.168.100.10 – 192.168.100.50. No forward = fully isolated.
# -----------------------------------------------------------------------------

ISOLAB_XML="/tmp/isolab.xml"
cat > "${ISOLAB_XML}" << 'EOF'
<network>
  <name>isolab</name>
  <bridge name="virbr1"/>
  <ip address="192.168.100.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.100.10" end="192.168.100.50"/>
    </dhcp>
  </ip>
</network>
EOF

# [SUDO] Define, set autostart, and start the network
sudo virsh net-define "${ISOLAB_XML}"
sudo virsh net-autostart isolab
sudo virsh net-start isolab

# -----------------------------------------------------------------------------
# STEP 2 — DOWNLOAD ISOS TO /mnt/nvme0n1p1/VMs/iso/
# -----------------------------------------------------------------------------

# Kali Linux (latest installer AMD64). Use current/ for latest or a specific version.
# [SUDO not required for wget into user-owned dir]
wget -O "${ISO_DIR}/kali-linux-installer-amd64.iso" \
  "https://cdimage.kali.org/current/kali-linux-2025.4-installer-amd64.iso"
# Checksum (optional): wget https://cdimage.kali.org/current/SHA256SUMS -O - | grep installer-amd64

# Ubuntu Server 22.04 LTS
wget -O "${ISO_DIR}/ubuntu-22.04-live-server-amd64.iso" \
  "https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"

# Metasploitable 2 — ZIP containing VMDK; download and unzip
wget -O "${ISO_DIR}/metasploitable-linux-2.0.0.zip" \
  "https://downloads.sourceforge.net/project/metasploitable/Metasploitable2/metasploitable-linux-2.0.0.zip"
unzip -o "${ISO_DIR}/metasploitable-linux-2.0.0.zip" -d "${ISO_DIR}/metasploitable2"
# Typical content: Metasploitable.vmdk (and possibly .vmsd, .vmx). We use the .vmdk.

# -----------------------------------------------------------------------------
# STEP 3 — CREATE AND INSTALL VMs
# -----------------------------------------------------------------------------

# --- VM 1: Kali Linux (Attacker) — virt-install with ISO ---
# Static IP 192.168.100.10 configured inside guest after install (or via cloud-init if you use it).
# [SUDO] Required for virt-install
sudo virt-install \
  --name kali-attacker \
  --memory 3072 \
  --vcpus 4 \
  --disk path="${DISK_DIR}/kali.qcow2",size=40,format=qcow2 \
  --network network=isolab \
  --os-variant debiantesting \
  --graphics spice \
  --cdrom "${ISO_DIR}/kali-linux-installer-amd64.iso" \
  --noautoconsole

# After first boot, install OS; then inside guest set static IP (e.g. 192.168.100.10/24, gw 192.168.100.1).

# --- VM 2: Metasploitable 2 (Victim 1) — Convert VMDK to QCOW2 and import ---
# [SUDO] For qemu-img and virt-install
VMDK_PATH=$(find "${ISO_DIR}/metasploitable2" -name "*.vmdk" | head -1)
if [ -z "$VMDK_PATH" ]; then
  echo "No .vmdk found in ${ISO_DIR}/metasploitable2"
  exit 1
fi
sudo qemu-img convert -O qcow2 "$VMDK_PATH" "${DISK_DIR}/metasploitable.qcow2"

sudo virt-install \
  --name metasploitable-victim \
  --memory 1024 \
  --vcpus 2 \
  --disk path="${DISK_DIR}/metasploitable.qcow2" \
  --network network=isolab \
  --os-variant ubuntu8.04 \
  --graphics spice \
  --import \
  --noautoconsole

# Set static IP 192.168.100.20 inside Metasploitable guest (e.g. /etc/network/interfaces or netplan).

# --- VM 3: Ubuntu Server 22.04 (Victim 2) — virt-install with ISO ---
sudo virt-install \
  --name ubuntu-victim \
  --memory 2048 \
  --vcpus 2 \
  --disk path="${DISK_DIR}/ubuntu.qcow2",size=20,format=qcow2 \
  --network network=isolab \
  --os-variant ubuntu22.04 \
  --graphics spice \
  --cdrom "${ISO_DIR}/ubuntu-22.04-live-server-amd64.iso" \
  --noautoconsole

# During installer, set static IP 192.168.100.30/24, gateway 192.168.100.1.

# -----------------------------------------------------------------------------
# STEP 4 — VERIFICATION
# -----------------------------------------------------------------------------

# List all VMs and status
sudo virsh list --all

# Verify isolab network is active
sudo virsh net-list --all
sudo virsh net-dumpxml isolab

# After VMs are installed and have static IPs, from inside each VM:
# - ping 192.168.100.10 (Kali)
# - ping 192.168.100.20 (Metasploitable)
# - ping 192.168.100.30 (Ubuntu)
# From host, confirm no route to host physical NICs from isolab:
ip route get 192.168.100.10
ip addr show virbr1

echo "Done. Configure static IPs inside each guest (192.168.100.10, .20, .30)."
echo "Verify: VMs can ping each other; VMs cannot reach host wlan0/eno1."
