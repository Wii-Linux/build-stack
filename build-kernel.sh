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

if [ -f ./utils.sh ]; then . ./utils.sh
elif [ -f ./build-stack/utils.sh ]; then . ./build-stack/utils.sh
elif [ -f ../build-stack/utils.sh ]; then . ../build-stack/utils.sh
else
	echo "failed to find utils.sh" >&2
	exit 1
fi

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
sudo rm -rf ../initrd-src/lib/modules/* ../loader-img-src/lib/modules/*

# make sure we have the env
. ../build-stack/kernel-env.sh

# build the kernel modules for the internal initramfs
make wii_ultratiny_defconfig
make "-j$(nproc)"
sudo sh -c 'source ../build-stack/kernel-env.sh; make INSTALL_MOD_PATH=../initrd-src/usr/ modules_install'

# build the kernel modules for the loader
make wii_smaller_defconfig
make "-j$(nproc)"
sudo sh -c 'source ../build-stack/kernel-env.sh; make INSTALL_MOD_PATH=../loader-img-src/usr/ modules_install'


# rebuild the internal initramfs
tmp="../boot-stack/internal-loader"
tmp2="../../initrd-src"

if [ -d "$tmp" ]; then cd "$tmp"
else fatal "$tmp doesn't exist"; fi

if ! [ -d "$tmp2" ]; then fatal "$tmp2 does not exist!"; fi
cp init.sh               "$tmp2/linuxrc"
cp support.sh logging.sh "$tmp2/"

cd "$tmp2"
find . -print0 | cpio --null --create --verbose --format=newc > ../initrd.cpio
cd ../ || fatal "can't cd back?  wtf?"
# legacy compression, force overwrite if exists, delete source file
lz4 -lf --rm initrd.cpio initrd.cpio.lz4

# build the real deal kernel and modules
cd "$1" || fatal "kernel directory disappeared"
make wii_defconfig
make "-j$(nproc)"


echo "Kernel built!  Don't forget to rebuild the loader if you changed the wii_smaller_defconfig."