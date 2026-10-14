packer {
  required_version = ">= 1.9.0"
  required_plugins {
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
    windows-update = {
      version = ">= 0.16.0"
      source  = "github.com/rgl/windows-update"
    }
  }
}

# ---------- variables (values are set per version in vars/*.pkrvars.hcl) ----------
variable "vm_name"     { type = string }                 # output image name
variable "image_name"  { type = string }                 # /IMAGE/NAME from install.wim
variable "virtio_dir"  { type = string }                 # 2k16 | 2k19 | 2k22 | 2k25
variable "iso_url" {
  type        = string
  description = "Local path to the Windows Server ISO (required for qemuargs)"
}
variable "iso_checksum" {
  type    = string
  default = "none"
}
variable "virtio_iso" {
  type    = string
  default = "/var/lib/isos/virtio-win.iso"
}
variable "product_key" {
  type    = string
  default = ""                                          # empty for Evaluation; for VL/retail use GVLK or MAK
}
variable "admin_password" {
  type      = string
  default   = ""                                        # empty = random password for each build
  sensitive = true
}
variable "cloudbase_init_url" {
  type    = string
  default = "https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
}
variable "disk_size" {
  type    = string
  default = "40G"
}
variable "memory" {
  type    = number
  default = 4096
}
variable "cpus" {
  type    = number
  default = 4
}
variable "headless" {
  type    = bool
  default = true
}
variable "accelerator" {
  type    = string
  default = "kvm"
}

locals {
  build_password = var.admin_password != "" ? var.admin_password : "Pk-${uuidv4()}-Aa1"

  autounattend = templatefile("${path.root}/answer_files/Autounattend.xml.pkrtpl", {
    image_name     = var.image_name
    driver_dir     = var.virtio_dir
    product_key    = var.product_key
    admin_password = local.build_password
    # the VirtIO CD letter in WinPE is unknown in advance; list the possible options
    drive_letters  = ["C", "D", "E", "F", "G"]
  })

  disk_path = "output/${var.vm_name}/${var.vm_name}"
}

# ---------- builder ----------
source "qemu" "windows" {
  vm_name          = var.vm_name
  output_directory = "output/${var.vm_name}"
  format           = "qcow2"
  accelerator      = var.accelerator
  machine_type     = "pc"                 # i440fx is required for the floppy with Autounattend.xml
  headless         = var.headless
  cpus             = var.cpus
  memory           = var.memory
  disk_size        = var.disk_size
  disk_interface   = "virtio"
  disk_compression = true
  net_device       = "e1000"              # during build only; virtio-net is installed from the driver store afterward

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  floppy_content = {
    "Autounattend.xml" = local.autounattend
  }

  # Windows Setup: "Press any key to boot from CD or DVD"
  boot_wait    = "2s"
  boot_command = ["<space><wait><space><wait><space><wait><space>"]

  # IMPORTANT: overriding -drive replaces the builder's default disks,
  # so we list all of them: system disk, installation ISO, and VirtIO ISO.
  qemuargs = [
    ["-cpu", "host"],
    ["-drive", "file=${local.disk_path},if=virtio,cache=writeback,discard=ignore,format=qcow2,index=1"],
    ["-drive", "file=${var.iso_url},media=cdrom,index=2"],
    ["-drive", "file=${var.virtio_iso},media=cdrom,index=3"],
  ]

  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = local.build_password
  winrm_timeout  = "4h"
  winrm_use_ssl  = false
  winrm_insecure = true

  # sysprep powers off the VM automatically; Packer waits for shutdown
  shutdown_command = "powershell -NoProfile -ExecutionPolicy Bypass -File C:\\Windows\\Temp\\sysprep.ps1"
  shutdown_timeout = "60m"
}

# ---------- provisioning ----------
build {
  name    = "windows"
  sources = ["source.qemu.windows"]

  provisioner "powershell" {
    script = "scripts/01-prepare.ps1"
  }

  # VirtIO drivers + QEMU Guest Agent from the ISO
  provisioner "powershell" {
    script = "scripts/02-virtio.ps1"
  }

  provisioner "windows-restart" {}

  # cumulative updates; not required - remove this block if not needed
  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true",
    ]
    update_limit = 100
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "file" {
    source      = "files/cloudbase-init.conf"
    destination = "C:\\Windows\\Temp\\cloudbase-init.conf"
  }

  provisioner "file" {
    source      = "scripts/sysprep.ps1"
    destination = "C:\\Windows\\Temp\\sysprep.ps1"
  }

  provisioner "powershell" {
    environment_vars = ["CBI_URL=${var.cloudbase_init_url}"]
    script           = "scripts/03-cloudbase-init.ps1"
  }

  provisioner "powershell" {
    script = "scripts/99-cleanup.ps1"
  }
}
