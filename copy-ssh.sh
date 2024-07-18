#!/bin/sh -e

usage() {
	cat << EOF
Usage: copy-ssh.sh [host] [dest dir] [short ver] [kernel src] [loader path]

Copies the kernel and loader that were already created to a remote host.
Assumes that you've already ran build-kernel.sh & build-loader.sh
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

if [ "$#" != "5" ]; then
	usage
	exit 1
fi

case "$1" in
	-h|--help) usage; exit 0 ;; # show help
	"") usage; exit 1 ;; # user didn't provide anything
esac

if [ -d build-stack ]; then cd build-stack
elif [ -d ../build-stack ]; then cd ../build-stack
else fatal "can't find build-stack"; fi

if ! [ -d "../$4" ]; then fatal "kernel directory doesn't exist"; fi
cd "../$4"
scp arch/powerpc/boot/zImage "$1:$2/wiilinux/$3.krn" || fatal "failed to copy kernel"
cd ../

if ! [ -f "$5" ]; then fatal "loader doesn't exist"; fi
scp "$5" "$1:$2/wiilinux/$3.ldr" || fatal "failed to copy loader"

echo "Successfully copied to $1 at $2"


