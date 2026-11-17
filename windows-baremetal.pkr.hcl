# Windows Server for bare metal (minibar): UEFI + GPT, no virtio in the image, vendor drivers from
# drivers/ (storage controllers boot-start), OpenSSH and RDP on, cloudbase-init reading a local NoCloud
# volume ("cidata") that the deployer writes next to the image. The result is a raw disk:
# compress it with zstd after the build (README) and the deployer writes it to the server's disk.
#   packer build -var-file=vars/win2025-baremetal.pkrvars.hcl -var iso_url=... windows-baremetal.pkr.hcl
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

variable "vm_name"    { type = string }
variable "image_name" { type = string } # /IMAGE/NAME from install.wim
variable "iso_url" {
  type        = string
  description = "Local path to the Windows Server ISO"
}
variable "iso_checksum" {
  type    = string
  default = "none"
}
variable "product_key" {
  type    = string
  default = "" # empty for Evaluation
}
variable "admin_password" {
  type      = string
  default   = "" # build only; the server's password comes from minibar's user-data
  sensitive = true
}
variable "cloudbase_init_url" {
  type    = string
  default = "https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
}
variable "disk_size" {
  type    = string
  default = "40G" # C: is extended to the whole disk on the server (ExtendVolumes)
}
variable "memory" {
  type    = number
  default = 8192
}
variable "cpus" {
  type    = number
  default = 8
}
variable "headless" {
  type    = bool
  default = true
}
variable "accelerator" {
  type    = string
  default = "kvm"
}
# OVMF without Secure Boot (Ubuntu's ovmf package): iPXE and the deployer are not signed.
variable "efi_code" {
  type    = string
  default = "/usr/share/OVMF/OVMF_CODE_4M.fd"
}
variable "efi_vars" {
  type    = string
  default = "/usr/share/OVMF/OVMF_VARS_4M.fd"
}

locals {
  build_password = var.admin_password != "" ? var.admin_password : "Pk-${uuidv4()}-Aa1"
  autounattend = templatefile("${path.root}/answer_files/Autounattend-uefi.xml.pkrtpl", {
    image_name     = var.image_name
    product_key    = var.product_key
    admin_password = local.build_password
  })
}

source "qemu" "windows-baremetal" {
  vm_name          = var.vm_name
  output_directory = "output/${var.vm_name}"
  format           = "raw"
  accelerator      = var.accelerator
  machine_type     = "q35"
  headless         = var.headless
  cpus             = var.cpus
  memory           = var.memory
  disk_size        = var.disk_size

  efi_boot          = true
  efi_firmware_code = var.efi_code
  efi_firmware_vars = var.efi_vars

  # AHCI disk and e1000 NIC: Windows has both drivers inbox, so no virtio is needed during setup
  # and none ends up in the image.
  disk_interface = "ide"
  net_device     = "e1000"

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # q35 has no floppy: Autounattend.xml goes on a second CD (Setup searches removable media for it).
  cd_content = {
    "Autounattend.xml" = local.autounattend
  }
  cd_label = "UNATTEND"

  # UEFI Windows media: "Press any key to boot from CD or DVD..." for a few seconds after OVMF starts.
  boot_wait = "3s"
  boot_command = [
    "<spacebar><wait><spacebar><wait><spacebar><wait><spacebar><wait><spacebar><wait>",
    "<spacebar><wait><spacebar><wait><spacebar><wait><spacebar><wait><spacebar>",
  ]

  qemuargs = [
    ["-cpu", "host"],
  ]

  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = local.build_password
  winrm_timeout  = "4h"
  winrm_use_ssl  = false
  winrm_insecure = true

  shutdown_command = "powershell -NoProfile -ExecutionPolicy Bypass -File C:\\Windows\\Temp\\sysprep.ps1"
  shutdown_timeout = "60m"
}

build {
  name    = "windows-baremetal"
  sources = ["source.qemu.windows-baremetal"]

  provisioner "powershell" {
    script = "scripts/01-prepare.ps1"
  }

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

  # Vendor drivers for the fleet: drivers/<component>/*.inf (may be empty, keep the directory).
  provisioner "file" {
    source      = "drivers/"
    destination = "C:\\Windows\\Temp\\drivers"
  }

  provisioner "powershell" {
    script = "scripts/05-drivers.ps1"
  }

  provisioner "powershell" {
    script = "scripts/04-openssh.ps1"
  }

  provisioner "file" {
    source      = "files/cloudbase-init-baremetal.conf"
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
