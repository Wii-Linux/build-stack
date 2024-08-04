#!/bin/sh -e

usage() {
	cat << EOF
Usage: build-kernel.sh [kernel src] [modules folder] [short version] <options>

Options:
       -w,--wii:                Builds a kernel for the Nintendo Wii.
                                This is the default option if neither -w nor -g
                                are specified.

       -g,--gamecube:           Builds a kernel for the Nintendo GameCube.

       -j1:                     Force -j1 mode in make

       --no-source-env:         Disable sourcing the default kernel build
                                environment variables.  Ensure that you
                                source your own before running the script if
                                you plan to use this!

       --installer:             Build targetting the Wii Linux Installer.
                                Implies --ios and --wii.

  Compression Options:
       Note that none of these actually affect the kernel config.  You'll need
       to modify it manually if you plan to use anything other than lz4.

       --lz4,--compress=lz4:    Enable lz4 compression of the internal
                                initramfs.  This is the default option.

       --gzip,--compress=gzip:  Enable gzip compression of the internal
                                initramfs.

       --compress=none:         Disable all compression of the internal
                                initramfs.

  Wii Specific:
       -i,--ios:                Builds an IOS kernel, if supported.
                                If not supported, it will throw cryptic errors.

       -m,--mini:               Builds a kernel targetting the "MINI" firmware.
                                This is the default option when building for
                                the Wii.



Builds a kernel using a locally installed crosstool-ng toolchain.
This script heavily assumes a specific file structure is already set up.

I highly recommend creating a dedicated Wii Linux folder, and cloning at least:
- build-stack
- boot-stack
- kernel of your choice

and generating these ahead of time:
- initrd-src
- loader-img-src
- installer-src

All of these must be present in the parent directory of your kernel source.

Example: build-kernel.sh kernel-4.5 4.5.0-wii+ v4_5_0
This would build the kernel in the directory 'kernel-4.5', which will output
modules to [install dir]/lib/modules/4.5.0-wii+, and will be packaged using
the short version name 'v4_5_0'.

Report any bugs to the GitHub issues page.
EOF
}

checkValid() {
	if [ "$1" = "$2" ]; then
		error "you can't select $3"
		usage; exit 1
	fi
}
if [ -f ./utils.sh ]; then . ./utils.sh
elif [ -f ./build-stack/utils.sh ]; then . ./build-stack/utils.sh
elif [ -f ../build-stack/utils.sh ]; then . ../build-stack/utils.sh
else
	echo "failed to find utils.sh" >&2
	exit 1
fi

# default to building for Wii, MINI bootloader, lz4 compression of initrd
con="wii"
wii_bl="mini"
compression="lz4"
is_installer="false"
ldr_dir="loader-img-src"
make_args="-j$(nproc)"

for arg in "$@"; do
	case "$arg" in
		"") usage; exit 1 ;; # user didn't provide anything
		-g|--gamecube)
			checkValid "$tmp_got_con" true "2 consoles"
			checkValid "$tmp_got_bl"  true "a Wii bootloader on a GameCube"
			con="gamecube" tmp_got_con=true ;;
		-w|--wii)
			checkValid "$tmp_got_con" true "2 consoles"
			con="wii" tmp_got_con=true ;;
		-i|--ios)
			checkValid "$con"        "gamecube" "a Wii bootloader on a GameCube"
			checkValid "$tmp_got_bl" true       "2 bootloaders"
			wii_bl="ios"; tmp_got_bl=true ;;
		-m|--mini)
			checkValid "$con"        "gamecube" "a Wii bootloader on a GameCube"
			checkValid "$tmp_got_bl" true       "2 bootloaders"
			wii_bl="mini"; tmp_got_bl=true ;;
		--installer)
			checkValid "$con"        "gamecube" "the installer on a GameCube"
			is_installer=true ;;
		--lz4|--compress=lz4)
			checkValid "$tmp_got_comp" true "2 compression methods"
			compression="lz4"; tmp_got_comp=true ;;
		--gzip|--compress=gzip)
			checkValid "$tmp_got_comp" true "2 compression methods"
			compression="gzip"; tmp_got_comp=true ;;
		--compress=none)
			checkValid "$tmp_got_comp" true "2 compression methods"
			compression="none"; tmp_got_comp=true ;;
		-j1) make_args="-j1" ;;
		--no-source-env) no_source_env=true ;;
		-h|--help) usage; exit 0 ;; # show help
		--) break ;;
		-*) error "bad argument"; usage; exit 1 ;;
	esac
done

if [ "$#" -gt "8" ] || [ "$#" -lt "3" ]; then
	error "bad number of arguments"
	usage; exit 1
fi

target="${con}"
s_ver="$3"
echo "Building for console: $con"
if [ "$con" = "wii" ]; then
	echo "Building for bootloader: $wii_bl"
	echo "Building installer: $is_installer"

	if [ "$is_installer" = "true" ]; then
		ldr_dir="installer-src"
	fi
	if [ "$wii_bl" != "mini" ]; then
		target="${target}_${wii_bl}"
	fi
fi
echo "defconfig target: $target"

# don't bother cding to it if we're already there
if [ "$(basename "$PWD")" != "$1" ]; then
	cd "$1" || { fatal "specified kernel source does not exist"; usage; }
fi

# clean up any old builds
rm -rf ../initrd-src/lib/modules/* ../$ldr_dir/lib/modules/*

if [ "$no_source_env" != "true" ]; then
	# make sure we have the env, unless the user doesn't want it
	. ../build-stack/kernel-env.sh
fi

if [ "$is_installer" != "true" ]; then
	# build the kernel modules for the internal initramfs
	make ${target}_ultratiny_defconfig
	make "$make_args"
	make INSTALL_MOD_PATH=../initrd-src/usr/ modules_install

	# build the kernel modules for the loader
	make ${target}_smaller_defconfig
	make "$make_args"
	if [ "$is_installer" != "true" ]; then
		make INSTALL_MOD_PATH=../$ldr_dir/usr/ modules_install
	fi
fi


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
if [ "$compression" = "lz4" ]; then
	# legacy compression, force overwrite if exists, delete source file
	lz4 -lf --rm initrd.cpio initrd.cpio.lz4
elif [ "$compression" = "gzip" ]; then
	gzip -9nf initrd.cpio
elif [ "$compression" = "none" ]; then
	# do nothing
	:
fi

# build the real deal kernel and modules
cd "$1" || fatal "kernel directory disappeared"
make ${target}_defconfig
make "$make_args"

if [ "$is_installer" != "true" ]; then
	tmp="$(mktemp -d wii_linux_kernel_build_XXXXXXXXXX --tmpdir=/tmp)"
	if [ "$tmp" = "" ]; then fatal "mktemp didn't give valid output"; fi
	mkdir -p "$tmp/usr/lib/modules"
	make INSTALL_MOD_PATH="$tmp/usr" modules_install
	tar czf "./modules-$s_ver-$(datefmt).tar.gz" --numeric-owner --owner=0 -C "$tmp" .
fi



echo "Kernel built!  Don't forget to rebuild the loader if you changed the wii_smaller_defconfig."
