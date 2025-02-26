#!/bin/sh -e

usage() {
	cat << EOF
Usage: build-kernel.sh [kernel src] [modules folder] <options>

Options:
       -w,--wii:                Builds a kernel for the Nintendo Wii.
                                This is the default option if neither -w nor -g
                                are specified.

       -g,--gamecube:           Builds a kernel for the Nintendo GameCube.

       --android:               Builds a kernel for the specific console
                                and bootloader, targetting Android
                                (if supported).

       -j1:                     Force -j1 mode in make - useful if the build
                                is failing for whatever reason.

       --no-source-env:         Disable sourcing the default kernel build
                                environment variables.  Ensure that you
                                source your own before running the script if
                                you plan to use this!

       --installer:             Build targetting the Wii Linux Installer.
                                Implies --ios and --wii.

       --dry-run:               Do not actually build.  Just calculate tartget
                                and perform some sanity checks.

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

Example: build-kernel.sh kernel-4.5 4.5.0-wii+
This would build the kernel in the directory 'kernel-4.5', which will output
modules to modules.tar.gz

Report any bugs to the GitHub issues page.
EOF
}


if [ -f ./utils.sh ]; then . ./utils.sh; cd ../; BASE="$PWD"; cd - > /dev/null
elif [ -f ./build-stack/utils.sh ]; then . ./build-stack/utils.sh; BASE="$PWD"
elif [ -f ../build-stack/utils.sh ]; then . ../build-stack/utils.sh; cd ../; BASE="$PWD"; cd - > /dev/null
else
	echo "failed to find utils.sh" >&2
	exit 1
fi

# default to building for Wii, MINI bootloader, lz4 compression of initrd
con="wii"
wii_bl="mini"
compression="lz4"
is_installer="false"
ldr_dir="$BASE/loader-img-src"
make_args="-j$(nproc)"
is_android=false
dry_run=false

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
		--android)
			is_android=true ;;
		--dry-run)
			dry_run=true ;;
		-j1) make_args="-j1" ;;
		--no-source-env) no_source_env=true ;;
		-h|--help) usage; exit 0 ;; # show help
		--) break ;;
		-*) error "bad argument"; usage; exit 1 ;;
	esac
done

if [ "$#" -gt "7" ] || [ "$#" -lt "2" ]; then
	error "bad number of arguments"
	usage; exit 1
fi

target="${con}"
echo "Building for console: $con"
echo "Building for Android: $is_android"
if [ "$is_android" = "true" ]; then
	target="${target}_android"
fi

if [ "$con" = "wii" ]; then
	echo "Building for bootloader: $wii_bl"
	echo "Building installer: $is_installer"

	if [ "$is_installer" = "true" ]; then
		ldr_dir="$BASE/installer-src"
	fi
	if [ "$wii_bl" != "mini" ]; then
		target="${target}_${wii_bl}"
	fi
fi
echo "defconfig target: $target"
echo "base dir: $BASE"

# don't bother cding to it if we're already there
if ! [ -d "$BASE/$1" ]; then
	fatal "specified kernel source does not exist"
	usage
fi

cd "$BASE/$1"


if [ "$dry_run" = "true" ]; then
	echo "Not actually building due to being a dry run"
	exit 0
fi

# clean up any old builds
rm -rf "$BASE/initrd-src/lib/modules/"* "$ldr_dir/lib/modules/"*

if [ "$no_source_env" != "true" ]; then
	# make sure we have the env, unless the user doesn't want it
	. "$BASE/build-stack/kernel-env.sh"
fi

# this is removed
#if [ "$is_installer" != "true" ] && [ "$is_android" != "true" ]; then
	# build the kernel modules for the loader
#	make ${target}_smaller_defconfig
#	make "$make_args"
#	if [ "$is_installer" != "true" ]; then
#		make INSTALL_MOD_PATH="$ldr_dir/usr/" modules_install
#	fi
#fi


# rebuild the internal initramfs
ldr="$BASE/boot-stack/internal-loader"
dest="$BASE/initrd-src"

if [ -d "$ldr" ]; then cd "$ldr"
else fatal "$ldr doesn't exist"; fi

if ! [ -d "$dest" ]; then fatal "$(basename $dest) does not exist!"; fi

rm -f "$dest/init" "$dest/linuxrc" "$dest/usr/sbin/init"
cp init.sh               "$dest/init"
cp init.sh               "$dest/linuxrc"
cp init.sh               "$dest/usr/sbin/init"
cp support.sh logging.sh "$dest/"

cd "$dest"
find . -print0 | cpio --null --create --verbose --format=newc > "$BASE/initrd.cpio"

cd "$BASE" || fatal "can't cd back?  wtf?"
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
cd "$BASE/$1" || fatal "kernel directory disappeared"
make ${target}_defconfig
if ! make "$make_args"; then
	fatal "make failed...."
fi

if [ "$is_installer" != "true" ]; then
	tmp="$(mktemp -d wii_linux_kernel_build_XXXXXXXXXX --tmpdir=/tmp)"
	if [ "$tmp" = "" ]; then fatal "mktemp didn't give valid output"; fi
	mkdir -p "$tmp/usr/lib/modules"
	make INSTALL_MOD_PATH="$tmp/usr" modules_install
	tar czf "./modules.tar.gz" --numeric-owner --owner=0 -C "$tmp" .
fi



echo "Kernel built!  Don't forget to rebuild the loader too!"
