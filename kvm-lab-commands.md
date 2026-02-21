# KVM/QEMU Home Lab — Copy-Paste Commands (Arch Linux)

**VM storage path:** `/mnt/nvme0n1p1/VMs/` with subfolders `iso/` and `disks/`.

`[SUDO]` = run with `sudo` or as root.

---

## Mount nvme0n1p1 and add to fstab

```bash
# Create mount point
sudo mkdir -p /mnt/nvme0n1p1

# Mount if not already mounted
if ! mountpoint -q /mnt/nvme0n1p1; then
  sudo mount /dev/nvme0n1p1 /mnt/nvme0n1p1
fi

# Get UUID for fstab (use this UUID in the next command)
lsblk -o NAME,UUID /dev/nvme0n1p1

# Add to /etc/fstab (replace YOUR_UUID with the UUID from above)
echo 'UUID=YOUR_UUID  /mnt/nvme0n1p1  ext4  defaults,noatime  0  2' | sudo tee -a /etc/fstab
sudo mount -a
```

Create VM folders and set ownership:

```bash
sudo mkdir -p /mnt/nvme0n1p1/VMs/iso /mnt/nvme0n1p1/VMs/disks
sudo chown -R $USER:$USER /mnt/nvme0n1p1/VMs
```

---

## STEP 1 — Isolated network "isolab"

**Spec:** Bridge virbr1, subnet 192.168.100.0/24, gateway 192.168.100.1, DHCP 192.168.100.10–192.168.100.50, no connection to host network.

Create the network XML and define/start it:

```bash
# Create XML file
cat > /tmp/isolab.xml << 'EOF'
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

# Define, autostart, and start the network
sudo virsh net-define /tmp/isolab.xml
sudo virsh net-autostart isolab
sudo virsh net-start isolab
```

---

## STEP 2 — Download ISOs to /mnt/nvme0n1p1/VMs/iso/

**Kali Linux (latest installer):**

```bash
wget -O /mnt/nvme0n1p1/VMs/iso/kali-linux-installer-amd64.iso \
  "https://cdimage.kali.org/current/kali-linux-2025.4-installer-amd64.iso"
```

**Ubuntu Server 22.04 LTS:**

```bash
wget -O /mnt/nvme0n1p1/VMs/iso/ubuntu-22.04-live-server-amd64.iso \
  "https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"
```

**Metasploitable 2 (ZIP with VMDK — download and unzip):**

```bash
wget -O /mnt/nvme0n1p1/VMs/iso/metasploitable-linux-2.0.0.zip \
  "https://downloads.sourceforge.net/project/metasploitable/Metasploitable2/metasploitable-linux-2.0.0.zip"
unzip -o /mnt/nvme0n1p1/VMs/iso/metasploitable-linux-2.0.0.zip -d /mnt/nvme0n1p1/VMs/iso/metasploitable2
```

---

## STEP 3 — Create the three VMs

**VM 1 — Kali (Attacker):** 3GB RAM, 4 CPUs, 40GB disk at `/mnt/nvme0n1p1/VMs/disks/kali.qcow2`, network isolab, static IP 192.168.100.10 (set in guest after install).

```bash
sudo virt-install \
  --name kali-attacker \
  --memory 3072 \
  --vcpus 4 \
  --disk path=/mnt/nvme0n1p1/VMs/disks/kali.qcow2,size=40,format=qcow2 \
  --network network=isolab \
  --os-variant debiantesting \
  --graphics spice \
  --cdrom /mnt/nvme0n1p1/VMs/iso/kali-linux-installer-amd64.iso \
  --noautoconsole
```

**VM 2 — Metasploitable 2 (Victim 1):** Convert VMDK to qcow2, then import. 1GB RAM, 2 CPUs, static IP 192.168.100.20 (set in guest).

```bash
# Find the VMDK (usually one .vmdk in the unzipped folder)
VMDK=$(find /mnt/nvme0n1p1/VMs/iso/metasploitable2 -name "*.vmdk" | head -1)
sudo qemu-img convert -O qcow2 "$VMDK" /mnt/nvme0n1p1/VMs/disks/metasploitable.qcow2

sudo virt-install \
  --name metasploitable-victim \
  --memory 1024 \
  --vcpus 2 \
  --disk path=/mnt/nvme0n1p1/VMs/disks/metasploitable.qcow2 \
  --network network=isolab \
  --os-variant ubuntu8.04 \
  --graphics spice \
  --import \
  --noautoconsole
```

**VM 3 — Ubuntu Server 22.04 (Victim 2):** 2GB RAM, 2 CPUs, 20GB disk at `/mnt/nvme0n1p1/VMs/disks/ubuntu.qcow2`, static IP 192.168.100.30 (set during install or in guest).

```bash
sudo virt-install \
  --name ubuntu-victim \
  --memory 2048 \
  --vcpus 2 \
  --disk path=/mnt/nvme0n1p1/VMs/disks/ubuntu.qcow2,size=20,format=qcow2 \
  --network network=isolab \
  --os-variant ubuntu22.04 \
  --graphics spice \
  --cdrom /mnt/nvme0n1p1/VMs/iso/ubuntu-22.04-live-server-amd64.iso \
  --noautoconsole
```

---

## STEP 4 — Verification

```bash
# List all VMs and status
sudo virsh list --all

# Verify isolab is active
sudo virsh net-list --all
sudo virsh net-dumpxml isolab

# From inside each VM: ping the other two (e.g. 192.168.100.10, .20, .30)
# Confirm no connectivity from VMs to host physical interfaces (e.g. wlan0, eno1)
# On host:
ip addr show virbr1
ip route get 192.168.100.10
```

---

## Path reference

All three VM-related path usages use `/mnt/nvme0n1p1/VMs/`:

1. **Kali disk:** `/mnt/nvme0n1p1/VMs/disks/kali.qcow2`
2. **Ubuntu disk:** `/mnt/nvme0n1p1/VMs/disks/ubuntu.qcow2`
3. **Metasploitable disk:** `/mnt/nvme0n1p1/VMs/disks/metasploitable.qcow2`  
   (ISOs live under `/mnt/nvme0n1p1/VMs/iso/`.)

No instances of `/home/owo/VMs/` are used; everything is under `/mnt/nvme0n1p1/VMs/`.
