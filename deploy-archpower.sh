#!/bin/sh
if ! [ -f "$1-root.tar.gz" ]; then
	echo "parameter must be prefix of files as passed to generate-archpower-rootfs.sh"
	exit 1
fi
./versioned_deploy.sh "$1-root.tar.gz" rootfs 'wii_linux_rootfs_archpower-{timestamp}.tar.gz'
./versioned_deploy.sh "$1-root.img.gz" rootfs 'wii_linux_rootfs_archpower-{timestamp}.img.gz'
./versioned_deploy.sh "$1-full-sd.img.gz" full-sd-imgs 'wii_linux_full_sd_archpower-{timestamp}.img.gz'
./versioned_deploy.sh "$1-boot.tar.gz" sd-files 'wii_linux_sd_files_archpower-{timestamp}.tar.gz'
./versioned_deploy.sh "$1-boot.zip" sd-files 'wii_linux_sd_files_archpower-{timestamp}.zip'

