#!/bin/bash

# Exit on error
set -e

# Default values
FEDORA_VERSION="41"
WORK_DIR="/tmp/appliance"
MOUNT_DIR="${WORK_DIR}/mount"
SQUASHFS_DIR="${WORK_DIR}/squashfs"
OUTPUT_DIR="${WORK_DIR}/output"
IMAGE_SIZE="1G"
IMAGE_FILE="pivirt-host.img"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Check if required packages are installed
check_requirements() {
    local packages=(
        "squashfs-tools"
        "parted"
        "dosfstools"
        "dnf"
        "grub2-efi-x64"
        "shim-x64"
        "dracut"
        "e2fsprogs"
    )
    
    echo "Installing required packages..."
    dnf install -y "${packages[@]}"
}

# Create working directories
setup_directories() {
    echo "Setting up working directories..."
    mkdir -p "$MOUNT_DIR" "$SQUASHFS_DIR" "$OUTPUT_DIR"
}

# Create minimal Fedora installation
create_minimal_system() {
    echo "Creating minimal Fedora system with version ${FEDORA_VERSION}..."
    dnf install -y --releasever="$FEDORA_VERSION" \
        --installroot="$SQUASHFS_DIR" \
        --setopt=install_weak_deps=False \
        --setopt=keepcache=False \
        --use-host-config \
        basesystem \
        NetworkManager \
        dracut-network \
        dracut-live \
        biosdevname \
        linux-firmware \
        passwd \
        rootfiles \
        vim-minimal \
        dnf \
        sudo \
        systemd \
        grub2-efi-x64 \
        shim-x64 \
        kernel \
        kernel-modules-extra \
        pivirt-agent \
        pivirt-dcui \
        libvirt \
        ocfs2-tools \
        iscsi-initiator-utils
        
    # Configure system
    chroot "$SQUASHFS_DIR" /bin/bash -c "
        systemctl enable NetworkManager
        echo 'root:toor' | chpasswd
        echo 'NETWORKING=yes' > /etc/sysconfig/network
        
        # Generate initramfs with live boot support
        KERNEL_VERSION=\$(ls /lib/modules | sort -V | tail -n 1)
        dracut --force --add 'dmsquash-live' /boot/initramfs-\${KERNEL_VERSION}.img \${KERNEL_VERSION}
    "
}

# Create squashfs image
create_squashfs() {
    echo "Creating squashfs image..."
    mkdir -p "$OUTPUT_DIR/LiveOS"
    mksquashfs "$SQUASHFS_DIR" "$OUTPUT_DIR/LiveOS/squashfs.img" -comp xz 
}

# Create and prepare disk image
create_disk_image() {
    # Create empty image file
    truncate -s "$IMAGE_SIZE" "$OUTPUT_DIR/$IMAGE_FILE"

    # Create partition table and partitions
    parted -s "$OUTPUT_DIR/$IMAGE_FILE" mklabel gpt
    parted -s "$OUTPUT_DIR/$IMAGE_FILE" mkpart primary fat32 1MiB 551MiB
    parted -s "$OUTPUT_DIR/$IMAGE_FILE" set 1 esp on
    parted -s "$OUTPUT_DIR/$IMAGE_FILE" mkpart primary ext4 551MiB 100%

    # Setup loop device
    LOOP_DEVICE=$(losetup -f --show --partscan "$OUTPUT_DIR/$IMAGE_FILE")

    # Format partitions
    mkfs.vfat -F 32 "${LOOP_DEVICE}p1"
    mkfs.ext4 -L PIVIRT_APPL "${LOOP_DEVICE}p2"
    
    # Mount partitions
    mount "${LOOP_DEVICE}p2" "$MOUNT_DIR"
    mkdir -p "$MOUNT_DIR/boot/efi"
    mount "${LOOP_DEVICE}p1" "$MOUNT_DIR/boot/efi"
    
    echo "$LOOP_DEVICE"
}

# Install bootloader
install_bootloader() {
    local LOOP_DEVICE="$1"
    echo "Installing bootloader..."
    
    # Copy LiveOS
    mkdir -p "$MOUNT_DIR/LiveOS"
    cp "$OUTPUT_DIR/LiveOS/squashfs.img" "$MOUNT_DIR/LiveOS/"
    
    # Install GRUB2 for UEFI
    grub2-install --target=x86_64-efi \
        --efi-directory="$MOUNT_DIR/boot/efi" \
        --boot-directory="$MOUNT_DIR/boot" \
        --removable --no-nvram --force
    
    # Create GRUB2 configuration
    cat > "$MOUNT_DIR/boot/grub2/grub.cfg" << EOF
set timeout=0
set timeout_style=hidden
set default=0

terminal_output console

menuentry "PiVirt Appliance" {
    search --no-floppy --label PIVIRT_APPL --set root
    linux /boot/vmlinuz root=live:LABEL=PIVIRT_APPL rd.live.image quiet console=tty0 console=ttyS0,115200n8
    initrd /boot/initramfs
}
EOF

    # Copy kernel and initramfs
    KERNEL_VERSION=$(ls "$SQUASHFS_DIR/lib/modules" | sort -V | tail -n 1)
    cp "$SQUASHFS_DIR/boot/vmlinuz-${KERNEL_VERSION}" "$MOUNT_DIR/boot/vmlinuz"
    cp "$SQUASHFS_DIR/boot/initramfs-${KERNEL_VERSION}.img" "$MOUNT_DIR/boot/initramfs"
}

# Cleanup
cleanup() {
    echo "Cleaning up..."
    # Unmount all partitions
    umount -R "$MOUNT_DIR" || true
    # Delete working directories
    rm -Rf "$MOUNT_DIR"
    # Detach loop device if it exists
    losetup -D
}

# Main execution
echo "Starting Live image creation..."
trap cleanup EXIT

check_requirements
setup_directories
create_minimal_system
create_squashfs

echo "Creating disk image..."
LOOP_DEVICE=$(create_disk_image)
install_bootloader "$LOOP_DEVICE"

echo "Live image creation completed!"
echo "Your bootable image is ready at: $OUTPUT_DIR/$IMAGE_FILE"
echo "To write it to a USB drive, use:"
echo "dd if=$OUTPUT_DIR/$IMAGE_FILE of=/dev/sdX bs=4M status=progress oflag=sync"
echo "We wish you a happy PiVirt day!"

exit 0

