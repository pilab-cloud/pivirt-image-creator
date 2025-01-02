#  <img src="https://pilab.hu/favicon.png" height="32" width="32"/>  PiVirt Appliance Image Builder

This tool creates a bootable appliance image for PiVirt using Fedora as the base system. The resulting image can be written directly to a USB drive or used as a virtual disk.

## Features

- UEFI boot support
- Compressed squashfs root filesystem
- Automatic boot without GRUB menu
- Network support via NetworkManager
- Console support (both VGA and Serial)
- Pre-installed PiVirt components
- Live system with changes stored in RAM

## Prerequisites

The script must be run on a Fedora system with root privileges. Required packages will be installed automatically.

## Usage

1. Run the script as root:
```bash
sudo ./create_live_usb.sh
```

2. After completion, write the image to a storage device:
```bash
sudo dd if=/appliance/output/pivirt-host.img of=/dev/sdX bs=4M status=progress oflag=sync
```
Replace `/dev/sdX` with your target device.

## Configuration

The script uses the following default values which can be modified at the top of the script:

- `FEDORA_VERSION="41"` - Base Fedora version
- `WORK_DIR="/tmp/appliance"` - Working directory for build process
- `IMAGE_SIZE="1G"` - Size of the output image
- `IMAGE_FILE="pivirt-host.img"` - Output image filename

## Included Packages

### Base System
- basesystem
- NetworkManager
- dracut-network
- dracut-live
- kernel
- kernel-modules-extra

### PiVirt Components
- pivirt-agent
- pivirt-netman
- pivirt-dc
- pivirt-selfupdate
- pivirt-snode
- pivirt-dcui

### System Utilities
- vim-minimal
- dnf
- sudo
- systemd

## Partitioning

The image is partitioned as follows:
1. EFI System Partition (FAT32, 550MiB)
2. Root Partition (ext4, remaining space)

## Boot Configuration

- GRUB is configured for immediate boot
- Console output is configured for both VGA (tty0) and Serial (ttyS0, 115200n8)
- Root filesystem is mounted as live image with label PIVIRT_APPL

## Build Process

1. Installs required packages
2. Creates minimal Fedora installation
3. Configures system services and networking
4. Creates squashfs image of the installation
5. Creates bootable disk image with UEFI support
6. Installs bootloader and copies required files

## Troubleshooting

- If the GRUB menu is needed, press and hold Shift during boot
- System logs are available in the standard locations but will be lost on reboot due to the live nature of the system
- Network configuration can be modified using standard NetworkManager tools

## Notes

- All changes to the running system are stored in RAM and will be lost on reboot
- Root password is set to `toor` by default
- The system is configured for both VGA and Serial console access
- The script assumes that the USB drive is mounted at `/tmp/appliance/output`
- The appliance does not make any change on the host system

## Thanks

Special thanks to [Fedora](https://fedoraproject.org/) for providing the base system and [PiVirt](https://pivirt.io/) for inspiration. We hope you find this tool useful for your PiVirt needs!


---

<p align="center">
Sponsored with ❤️ by
</p>
<p align="center">
    <a href="https://newpush.com" target="_blank">
    <img src="https://www.newpush.com/images/np_logo_blue_SVG.svg" width="128"/>
    </a><br>
    We focus on reliability, quality, and value.
</p>

---

<p style="padding-top: 2rem;" align="center">
Pioneering the future, together</p>

<p align="center">
<img src="https://pilab.hu/images/pi-logo-header.svg" alt="PiVirt Logo" width="100"></p>
