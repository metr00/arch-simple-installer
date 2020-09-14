#!/usr/bin/env bash
# Written by Draco (tytydraco @ GitHub)

# Configuration
lsblk
echo -n "Disk [/dev/sda]: "
read DISKPATH
DISKPATH=${DISKPATH:-/dev/sda}

echo -n "Timezone [America/Los_Angeles]: "
read TIMEZONE
TIMEZONE=${TIMEZONE:-America/Los_Angeles}

echo -n "Hostname [localhost]: "
read HOSTNAME
HOSTNAME=${HOSTNAME:-localhost}

echo -n "Password [root]: "
read PASSWORD
PASSWORD=${PASSWORD:-root}

# Setup script vars
EFI="${DISKPATH}1"
ROOT="${DISKPATH}2"

# Unmount for safety
umount "$EFI" 2> /dev/null
umount "$ROOT" 2> /dev/null

# Timezone
timedatectl set-ntp true

# Partitioning
(
	echo g		# Erase as GPT
	echo n		# EFI
	echo
	echo
	echo +512M
	echo t
	echo 1
	echo n		# Linux root
	echo
	echo
	echo
	echo w		# Write
) | fdisk -w always "$DISKPATH"

# Formatting partitions
mkfs.fat -F 32 "$EFI"
yes | mkfs.ext4 "$ROOT"

# Mount our new partition
mount "$ROOT" /mnt

# Initialize base system, kernel, and firmware
pacstrap /mnt base linux linux-firmware

# Setup fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot commands
(
	echo "ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime"
	echo "hwclock --systohc"
	echo "sed -i \"s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/\" /etc/locale.gen"
	echo "locale-gen"
	echo "echo \"LANG=en_US.UTF-8\" > /etc/locale.conf"
	echo "echo \"$HOSTNAME\" > /etc/hostname"
	echo -e "echo \"127.0.0.1\tlocalhost\" >> /etc/hosts"
	echo -e "echo \"::1\tlocalhost\" >> /etc/hosts"
	echo -e "echo \"127.0.1.1\t$HOSTNAME\" >> /etc/hosts"
	echo "echo \"$PASSWORD\" | passwd --stdin"
	echo "pacman -Sy --noconfirm amd-ucode intel-ucode"
	echo "pacman -Sy --noconfirm grub efibootmgr"
	echo "mkdir /boot/efi"
	echo "mount \"$EFI\" /boot/efi"
	echo "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable"
	echo "grub-mkconfig -o /boot/grub/grub.cfg"
	echo "pacman -Sy --noconfirm networkmanager iwd"
	echo "systemctl enable NetworkManager"
) | arch-chroot /mnt
