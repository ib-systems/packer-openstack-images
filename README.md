# Windows Server KVM Image Build Guide

This project creates Windows Server images for KVM and OpenStack using Packer. It automates the installation process, applies the required VirtIO drivers, installs Cloudbase-Init for cloud metadata handling, and produces a generalized qcow2 image ready for deployment.

## Project structure

The repository is organized as follows:

- `windows.pkr.hcl` — the main Packer configuration; this is the file that defines the VM, the QEMU settings, the install flow, and the provisioners.
- `answer_files/` — contains the unattended Windows installation answer file (`Autounattend.xml.pkrtpl`), which automates the Windows setup and enables WinRM for Packer.
- `scripts/` — PowerShell scripts used during the build:
  - `01-prepare.ps1` prepares the OS and basic system settings
  - `02-virtio.ps1` installs VirtIO drivers and QEMU Guest Agent
  - `03-cloudbase-init.ps1` installs Cloudbase-Init
  - `99-cleanup.ps1` performs the final cleanup
  - `sysprep.ps1` runs Windows sysprep and shuts the VM down
- `files/` — additional files copied into the guest image, such as the Cloudbase-Init configuration file.
- `vars/` — version-specific variable files used to select the OS version, output name, image name, and ISO paths.

This project is intended to be run as a complete build pipeline: the answer file handles the unattended installation, the scripts handle the OS configuration, and the final image is prepared for cloud usage.

## What the project does

At a high level, the build process does the following:
- creates a QEMU virtual machine for the installation
- boots Windows Server from a local ISO
- performs unattended setup using `Autounattend.xml`
- configures WinRM so Packer can connect to the guest
- installs VirtIO drivers for virtual disk and networking
- installs Cloudbase-Init to support OpenStack metadata and injected configuration
- generalizes the Windows guest with sysprep
- exports the resulting image as a qcow2 disk image

## Required tools

Before running the build, ensure that the host has:
- Linux with KVM enabled
- `qemu-system-x86`
- `qemu-img`
- Packer installed and on the `PATH`
- enough free disk space for the build output

## Required ISO files

You need two local ISO files:

1. A Windows Server installation ISO, such as:
   - `win2019.iso`
   - `win2022.iso`
   - `win2025.iso`

2. A VirtIO ISO, such as:
   - `virtio-win.iso`

The project expects these files to be available on the build host before running the image build.

## Recommended ISO storage location

The default recommended folder is:

```bash
/var/lib/isos/
```
If you store the ISO files somewhere else, update the paths in the relevant variable files.

## Files and their role

### `windows.pkr.hcl`
This is the central Packer definition. It controls:
- the target VM settings (`memory`, `cpus`, `disk_size`, etc.)
- the output image name and directory
- the source ISO path and VirtIO ISO path
- the QEMU arguments used for the build VM
- the provisioners that run inside the Windows guest

### `answer_files/Autounattend.xml.pkrtpl`
This file is rendered at build time and is used during the Windows installation process. It does the following:
- selects the correct Windows image from the installation media
- configures the disk layout
- sets the language and locale
- sets the local administrator password
- enables WinRM for remote management
- injects the VirtIO driver path into the installation environment

### `scripts/`
These PowerShell scripts are executed inside the VM after installation:
- `01-prepare.ps1` configures the base OS and system behavior
- `02-virtio.ps1` installs VirtIO storage and network drivers, plus QEMU Guest Agent
- `03-cloudbase-init.ps1` downloads and installs Cloudbase-Init
- `99-cleanup.ps1` removes unnecessary items and finalizes the image
- `sysprep.ps1` runs Windows sysprep and powers off the VM

### `files/cloudbase-init.conf`
This configuration file is copied into the guest and used by Cloudbase-Init. It configures:
- local admin user details
- password injection from metadata
- network settings
- logging behavior
- plugin configuration for the cloud environment

### `vars/`
Each version file defines the parameters for that specific Windows Server release, such as:
- the VM name
- the Windows image name
- the VirtIO driver directory
- the ISO path
- optional product key

Example:

```hcl
vm_name    = "windows-server-2022-en"
image_name = "Windows Server 2022 SERVERSTANDARD"
virtio_dir = "2k22"
iso_url    = "/var/lib/isos/win2022.iso"
```

These files are the place to edit when building a different Windows version or using a different ISO file.

## Quick start

Run the setup and validation commands first. Then choose **one** build command:

```bash
sudo mkdir -p /var/lib/isos
sudo cp ~/Downloads/win2022.iso /var/lib/isos/win2022.iso
sudo cp ~/Downloads/virtio-win.iso /var/lib/isos/virtio-win.iso
packer init .
packer validate -var-file=vars/win2022.pkrvars.hcl .
```

For a normal build, use headless mode. The VM runs without a visible QEMU console:

```bash
PACKER_LOG=1 packer build -var-file=vars/win2022.pkrvars.hcl .
```

To watch the VM's graphical console during installation or troubleshoot boot issues, use:

```bash
PACKER_LOG=1 packer build -var='headless=false' -var-file=vars/win2022.pkrvars.hcl .
```

Both commands enable detailed Packer logging with `PACKER_LOG=1`. The `headless=false` option only changes whether the VM console is shown; it does not replace the normal build command. Do not run both build commands one after the other for the same output image.

## Output artifact

After a successful build, the output directory contains a qcow2 image, typically something like:

```bash
output/windows-server-2022-en/windows-server-2022-en
```

This file can be imported into OpenStack, Glance, or KVM-based environments.
