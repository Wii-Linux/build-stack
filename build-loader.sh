#!/bin/sh -e

usage() {
	cat << EOF
Usage: build-loader.sh [output file path]

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

out="$PWD/$1"

if [ -d build-stack ]; then cd build-stack
elif [ -d ../build-stack ]; then cd ../build-stack
else fatal "can't find build-stack"; fi

./c.sh

if [ -d ../boot-stack/loader-img-full ]; then cd ../boot-stack/loader-img-full
else fatal "can't find boot-stack/loader-img-full"; fi

tmp="../../loader-img-src"
if ! [ -d "$tmp" ]; then fatal "can't find $tmp"; fi

cp init.sh      "$tmp/linuxrc"
cp support.sh jit_setup.sh checkBdev.sh network.sh util.sh logging.sh "$tmp/"


mksquashfs "$tmp" "$out" -all-root -noappend
