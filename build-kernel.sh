#!/bin/sh -e

usage() {
	cat << EOF
Usage: build-kernel.sh [kernel source] [modules folder]

Builds a kernel using a locally installed crosstool-ng toolchain.
This script heavily assumes a specific file structure is already set up.

I highly recommend creating a dedicated Wii Linux folder, and cloning at least:
- build-stack
- boot-stack
- kernel of your choice

and generating these ahead of time:
- initrd-src
- loader-img-src

All of these must be present in the parent directory of your kernel source.

Report any bugs to the GitHub issues page.
EOF
}


case "$1" in
	"") usage; exit 1 ;; # user didn't provide anything
	-h|--help) usage; exit 0 ;; # show help
esac

if [ "$2" = "" ]; then usage; exit 1; fi

# don't bother cding to it if we're already there
if [ "$(basename "$PWD")" != "$1" ]; then
	cd "$1" || { fatal "specified kernel source does not exist"; usage; }
fi

# clean up any old builds
sudo rm -rf ../initrd-src/lib/modules/*
sudo rm -rf ../loader-img-src/lib/modules/*

# make sure we have the env
. ../build-stack/kernel-env.sh

# build the kernel modules for the internal initramfs
make wii_ultratiny_defconfig
make -j8
sudo sh -c 'source ../build-stack/kernel-env.sh; make INSTALL_MOD_PATH=../initrd-src/usr/ modules_install'

# build the kernel modules for the loader
make wii_smaller_defconfig
make -j8
sudo sh -c 'source ../build-stack/kernel-env.sh; make INSTALL_MOD_PATH=../loader-img-src/usr/ modules_install'

# rebuild the internal initramfs
cd ../initrd-src || fatal "initrd-src does not exist!"
cp ../boot-stack/internal-loader/init.sh    ./linuxrc
cp ../boot-stack/internal-loader/support.sh ./
cp ../boot-stack/internal-loader/logging.sh ./
find . -print0 | cpio --null --create --verbose --format=newc > ../initrd.cpio
cd ../ || fatal "can't cd back?  wtf?"
# legacy compression, force overwrite if exists, delete source file
lz4 -lf --rm initrd.cpio initrd.cpio.lz4

# build the real deal kernel and modules
cd "$1" || fatal "kernel directory disappeared"
make wii_defconfig
make -j8


# it's one module per line, it really doesn't matter that we aren't reading lines
# shellcheck disable=2013
#for mod in $(sed 's|kernel/||g' < "../initrd-src/lib/modules/$2/modules.order"); do
#	sudo mkdir "../initrd-src/lib/modules/$2/kernel/$(dirname "$mod")" -p
#	sudo cp "$mod" "../initrd-src/lib/modules/$2/kernel/$mod"
#done

echo "Kernel built!  Don't forget to rebuild the loader if you changed the wii_smaller_defconfig."
#scp arch/powerpc/boot/zImage root@172.16.4.90:/mnt/sd/wiilinux/v4_5_0.krn || echo "failed to copy"
#cp arch/powerpc/boot/zImage zImage

#cd ../build-stack
#./b.sh
