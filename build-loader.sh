#!/bin/sh -e

usage() {
	cat << EOF
Usage: build-loader.sh [output file path] <options>

Options:
       --installer:             Builds the installer bootstrap as a loader.




Builds a loader.img for your specified kernel version.
Assumes that you've already ran build-kernel.sh for this version.
This script heavily assumes a specific file structure is already set up.

I highly recommend creating a dedicated Wii Linux folder, and cloning at least:
- build-stack
- boot-stack
- kernel of your choice

and generating these ahead of time:
- initrd-src
- loader-img-src

All of these must be present in the parent directory, or cwd.

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
	-h|--help) usage; exit 0 ;; # show help
	"") usage; exit 1 ;; # user didn't provide anything
esac

dir="loader-img-src"
case "$2" in
	-h|--help) usage; exit 0 ;; # show help
	--installer) is_installer=true; dir="installer-src" ;;
esac

out="$PWD/$1"
if [ -d build-stack ]; then cd build-stack
elif [ -d ../build-stack ]; then cd ../build-stack
else fatal "can't find build-stack"; fi

if [ "$is_installer" != "true" ]; then
	./c.sh
fi

if [ -d ../boot-stack/loader-img-full ]; then cd ../boot-stack/loader-img-full
else fatal "can't find boot-stack/loader-img-full"; fi

tmp="../../$dir"
if ! [ -d "$tmp" ]; then fatal "can't find $tmp"; fi

if [ "$is_installer" = "true" ]; then
	cd ../installer || fatal "can't cd to ../installer"
else
	fatal "balls"
fi

cp support.sh checkBdev.sh network.sh util.sh logging.sh jit_setup.sh "$tmp/"
cp init.sh "$tmp/linuxrc"

if [ "$is_installer" = "true" ]; then
	( cd "$tmp"; ../build-stack/util_installer.sh .; )

	tar --no-recursion -cf "$out" -C "$tmp" -T "$tmp/file_list.txt"

	# XXX: hack to forcibly add a /lib so that jit_setup can bindmount there
	( cd /tmp; mkdir -p garbage_tmp_wii_linux_loader_build; cd garbage_tmp_wii_linux_loader_build; mkdir -p lib; tar -rf "$out" ./lib; cd "$(dirname $out)"; rm -r /tmp/garbage_tmp_wii_linux_loader_build; )
else
	mksquashfs "$tmp" "$out" -all-root -noappend
fi
