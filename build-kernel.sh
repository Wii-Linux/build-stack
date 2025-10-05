#!/bin/sh -e

usage() {
	cat << EOF
Usage: build-kernel.sh [kernel src] <options>

Options:
       -w,--wii:                Builds a kernel for the Nintendo Wii.
                                This is the default option if neither -w nor -g
                                are specified.

       -g,--gamecube:           Builds a kernel for the Nintendo GameCube.

       -s,--standalone:         Builds a standalone (non-boot-menu-based) kernel.

       -i,--installer:          Build a kernel with an installer loader,
                                rather than the boot menu loader.

       --android:               Builds a kernel for the specific console
                                and bootloader, targetting Android
                                (if supported).

       -j1:                     Force -j1 mode in make - useful if the build
                                is failing for whatever reason.

       --no-source-env:         Disable sourcing the default kernel build
                                environment variables.  Ensure that you
                                source your own before running the script if
                                you plan to use this!

       --dry-run:               Do not actually build.  Just calculate target
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
- loader-img-src
- installer-src

All of these must be present in the parent directory of your kernel source.

Example: build-kernel.sh kernel-4.19
This would build the kernel in the directory 'kernel-4.19', which will output
modules to modules.tar.gz, and headers to headers.tar.gz

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
ldr_type="bootmenu"
compression="lz4"
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
		-m|--mini)
			checkValid "$con"        "gamecube" "a Wii bootloader on a GameCube"
			checkValid "$tmp_got_bl" true       "2 bootloaders"
			wii_bl="mini"; tmp_got_bl=true ;;
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
		-s|--standalone)
			checkValid "$tmp_got_ldr" true "2 loader types"
			ldr_type="none"; tmp_got_ldr=true ;;
		-i|--installer)
			checkValid "$tmp_got_ldr" true "2 loader types"
			ldr_type="installer"; tmp_got_ldr=true ;;
		-j1) make_args="-j1" ;;
		--no-source-env) no_source_env=true ;;
		-h|--help) usage; exit 0 ;; # show help
		--) break ;;
		-*) error "bad argument"; usage; exit 1 ;;
	esac
done

if [ "$#" -gt "7" ] || [ "$#" -lt "1" ]; then
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

	if [ "$wii_bl" != "mini" ]; then
		target="${target}_${wii_bl}"
	fi
fi
if [ "$standalone" = "true" ]; then
	target="${target}_standalone"
fi
echo "defconfig target: $target"
echo "loader type: $ldr_type"
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

if [ "$no_source_env" != "true" ]; then
	# make sure we have the env, unless the user doesn't want it
	. "$BASE/build-stack/kernel-env.sh"
fi


# rebuild the internal initramfs
if [ "$ldr_type" = "bootmenu" ]; then
	dest="$BASE/loader-img-src"
	"$BASE/build-stack/build-loader.sh" || fatal "failed to build loader"

	cd "$dest"
	find . -print0 | cpio --null --create --verbose --format=newc > "$BASE/initrd.cpio"

	cd "$BASE" || fatal "can't cd back?  wtf?"
elif [ "$ldr_type" = "installer" ]; then
	dest="$BASE/installer-src"
	"$BASE/build-stack/build-installer.sh" || fatal "failed to build loader"

	cd "$dest"
	find . -print0 | cpio --null --create --verbose --format=newc > "$BASE/initrd.cpio"

	cd "$BASE" || fatal "can't cd back?  wtf?"
fi

if [ "$ldr_type" != "none" ]; then
	if [ "$compression" = "lz4" ]; then
		# legacy compression, force overwrite if exists, delete source file
		lz4 -lf --rm initrd.cpio initrd.cpio.lz4
	elif [ "$compression" = "gzip" ]; then
		gzip -9nf initrd.cpio
	elif [ "$compression" = "none" ]; then
		# do nothing
		:
	fi
fi

# build the kernel and modules
cd "$BASE/$1" || fatal "kernel directory disappeared"
make ${target}_defconfig
if ! make "$make_args"; then
	fatal "make failed...."
fi

tmp="$(mktemp -d wii_linux_kernel_build_XXXXXXXXXX --tmpdir=/tmp)"
if [ "$tmp" = "" ]; then fatal "mktemp didn't give valid output"; fi
mkdir -p "$tmp/usr/lib/modules"

# install the modules
make INSTALL_MOD_PATH="$tmp/usr" modules_install

# clean up residual header bits
hdrInstDir=$(echo $tmp/usr/lib/modules/*/build)
rm -rf $hdrInstDir

# package the modules
tar czf "./modules.tar.gz" --numeric-owner --owner=0 -C "$tmp" .

# copy headers
mkdir "$hdrInstDir"
cp -r include "$hdrInstDir/"

# copy build files
buildFiles=$(find . -name 'Kconfig*' -o -name 'Kbuild*' -o -name 'Makefile*' | sed 's/\.\///g')
for f in $buildFiles; do
	mkdir -p "$hdrInstDir/$(dirname $f)"
	cp "$f" "$hdrInstDir/$(dirname $f)/"
done

# copy arch/powerpc/include
mkdir -p "$hdrInstDir/arch/powerpc"
cp -r arch/powerpc/include "$hdrInstDir/arch/powerpc/"

# clean up scripts, these contain host binaries
git clean -xdf scripts

# copy the now-cleaned scripts
cp -r scripts "$hdrInstDir/"

# copy tools
cp -r tools "$hdrInstDir/"

# we need a few important files if we want to do this
mkdir -p "$hdrInstDir/arch/powerpc/kernel" "$hdrInstDir/arch/powerpc/lib" "$hdrInstDir/arch/x86/entry/syscalls"
cp kernel/bounds.c "$hdrInstDir/kernel/"
cp arch/powerpc/kernel/asm-offsets.c "$hdrInstDir/arch/powerpc/kernel/"
cp kernel/time/timeconst.bc "$hdrInstDir/kernel/time/"
cp arch/powerpc/lib/{,.}crtsavres* "$hdrInstDir/arch/powerpc/lib/"

# yes, this is really needed, for checksyscalls.sh
cp arch/x86/entry/syscalls/syscall_32.tbl "$hdrInstDir/arch/x86/entry/syscalls/"

# copy important build related files
for f in .config Module.symvers System.map; do
	cp $f "$hdrInstDir/"
done

# these can fail, they may not exist
for f in localversion*; do
	cp $f "$hdrInstDir/" 2>/dev/null || true
done

# package the headers
tar czf "./headers.tar.gz" --numeric-owner --owner=0 -C "$hdrInstDir" .

rm -rf "$tmp"

echo "Kernel built!"
