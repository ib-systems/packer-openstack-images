# Creating and preparing OS images for OpenStack

Procedure for an Ubuntu host, based on the official Cloud Images, with QCOW2 as the final format.

## 1. Images and official sources

Images to prepare:

| Operating system | Official source |
| --- | --- |
| Ubuntu 26.04 | https://cloud-images.ubuntu.com/releases/26.04/release/ |
| AlmaLinux 10.2 | https://repo.almalinux.org/almalinux/10/cloud/x86_64/images/ |
| AlmaLinux 9.8 | https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/ |
| Fedora 43 | https://dl.fedoraproject.org/pub/fedora/linux/releases/43/Cloud/x86_64/images/ |
| Fedora 44 | https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/ |

## 2. Preparing the host (Ubuntu)

Install the required tools: `libguestfs-tools` (`virt-customize`, `virt-sysprep`), `qemu-utils`, `qemu-system-x86` and `cloud-image-utils` (`cloud-localds`).

```bash
sudo apt update
sudo apt install -y libguestfs-tools qemu-utils qemu-system-x86 cloud-image-utils wget curl
```

Create the working folder:

```bash
mkdir -p ~/os-images && cd ~/os-images
```

## 3. Downloading the official Cloud Images

Download the official Cloud Images (QCOW2) from the sources listed in the table at the beginning and add them to the `~/os-images` folder. In the commands below the files are named `ubuntu-26.04-openstack.qcow2`, `almalinux-10.2-openstack.qcow2`, `almalinux-9.8-openstack.qcow2`, `fedora-43-openstack.qcow2` and `fedora-44-openstack.qcow2`.

## 4. Configuring the images

All changes are made offline, directly on the `*-openstack.qcow2` files, with `virt-customize`. For each image:

- `qemu-guest-agent` is installed and enabled;
- `fstrim.timer` is enabled;
- `/etc/ssh/sshd_config` is set to `PermitRootLogin yes` and `PasswordAuthentication yes`, and the files in `/etc/ssh/sshd_config.d/` are removed;
- the PAM configuration (`/etc/pam.d/*`) is not modified.

### 4.1 Ubuntu 26.04

```bash
IMAGE=ubuntu-26.04-openstack.qcow2

virt-customize -a $IMAGE \
  --run-command 'apt-get update' \
  --install qemu-guest-agent \
  --run-command 'systemctl enable fstrim.timer' \
  --run-command 'systemctl enable qemu-guest-agent || true' \
  --run-command 'sed -i "/^#PasswordAuthentication yes$/a PasswordAuthentication yes" /etc/ssh/sshd_config' \
  --run-command 'sed -i "/^#PermitRootLogin prohibit-password$/a PermitRootLogin yes" /etc/ssh/sshd_config' \
  --run-command 'rm -f /etc/ssh/sshd_config.d/*.conf'
```

### 4.2 AlmaLinux 10.2, AlmaLinux 9.8, Fedora 43, Fedora 44

On the RHEL/Fedora family, SELinux relabeling is required after the changes (`--selinux-relabel`, the last option).

```bash
for IMAGE in almalinux-10.2-openstack.qcow2 almalinux-9.8-openstack.qcow2 fedora-43-openstack.qcow2 fedora-44-openstack.qcow2; do
  virt-customize -a $IMAGE \
    --install qemu-guest-agent \
    --run-command 'systemctl enable fstrim.timer' \
    --run-command 'systemctl enable qemu-guest-agent' \
    --run-command 'sed -i "/^#PasswordAuthentication yes$/a PasswordAuthentication yes" /etc/ssh/sshd_config' \
    --run-command 'sed -i "/^#PermitRootLogin prohibit-password$/a PermitRootLogin yes" /etc/ssh/sshd_config' \
    --run-command 'rm -f /etc/ssh/sshd_config.d/*.conf' \
    --selinux-relabel
done
```

### 4.3 virt-sysprep

After configuration, we clean the images (this removes the SSH host keys, `machine-id`, history, logs, DHCP state, etc.). Cloud-init regenerates them on first boot.

```bash
for IMAGE in *-openstack.qcow2; do
  virt-sysprep -a $IMAGE
done
```

## 5. Local testing

The purpose of this step is to check locally, before uploading to OpenStack, that the image boots, that cloud-init configures it correctly and that the settings we made work: SSH login as root with a password, `qemu-guest-agent` and `fstrim.timer`.

### 5.1 The user-data and meta-data files

We use the same files for all systems. `user-data` sets the root password and allows password authentication; the password below is for testing only.

```bash
cat > user-data <<'EOF'
#cloud-config
disable_root: false
ssh_pwauth: true
chpasswd:
  expire: false
  users:
    - {name: root, password: Test12345!, type: text}
EOF

cat > meta-data <<'EOF'
instance-id: test-instance-01
local-hostname: test-vm
EOF
```

### 5.2 Creating the cloud-init ISO

By default `cloud-localds` creates an ISO 9660 image labeled `cidata`, which cloud-init detects automatically:

```bash
cloud-localds cloud-init.iso user-data meta-data
```

### 5.3 Starting the VM

This is only a test VM. `$IMAGE` is the image under test (Ubuntu here), `-snapshot` keeps the image unchanged (writes go to a temporary file), and `-cpu host` is required for AlmaLinux 10:

```bash
IMAGE=ubuntu-26.04-openstack.qcow2

qemu-system-x86_64 \
  -enable-kvm -cpu host \
  -m 2048 \
  -smp 2 \
  -snapshot \
  -drive file=$IMAGE,format=qcow2,if=virtio \
  -drive file=cloud-init.iso,format=raw,media=cdrom \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -nographic
```

### 5.4 Checks

Once the login prompt appears (cloud-init takes a few tens of seconds), from a second terminal:

```bash
ssh -p 2222 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@localhost
```

Logging in as `root` with the password from `user-data` confirms `PermitRootLogin` and `PasswordAuthentication`. Inside the VM, run:

```bash
cloud-init status --wait
sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication|usepam)'
systemctl is-enabled fstrim.timer
systemctl is-active qemu-guest-agent
```

Expected result: `done`, then `permitrootlogin yes`, `passwordauthentication yes`, `usepam yes`, `enabled` and `active`.
