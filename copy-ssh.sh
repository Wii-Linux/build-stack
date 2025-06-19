#!/bin/sh -e
# we WANT those variable to expand client side
# shellcheck disable=SC2029

usage() {
	cat << EOF
Usage: copy-ssh.sh [host] [dest] [short ver] [kernel src] <options>

Options:
	None

Copies the already-built kernel to a remote host.
Assumes that you've already ran build-kernel.sh to build the kernel.
Also assumes that you are using SSH keys, since a few of the commands
won't be able to take stdin to ask for your password.
This script heavily assumes a specific file structure is already set up.

I highly recommend creating a dedicated Wii Linux folder, and cloning at least:
- build-stack
- boot-stack
- kernel of your choice

and generating these ahead of time:
- loader-img-src

All of these must be present in the parent directory, or cwd.

Examples:

MINI kernel version 4.4.302-cip80, residing in 'kernel-4.4-cip80', copy to
techflash@172.16.4.10, and on that machine, the directory /mnt/sd is where
you want to place the files.
copy-ssh.sh techflash@172.16.4.10 /mnt/sd v4_4_302 kernel-4.4-cip80


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

for arg in "$@"; do
	case "$arg" in
		"") usage; exit 1 ;; # user didn't provide anything
		-h|--help) usage; exit 0 ;; # show help
	esac
done
if [ "$#" != "4" ]; then
	error "invalid number of arguments"
	usage; exit 1
fi

if [ -d build-stack ]; then cd build-stack
elif [ -d ../build-stack ]; then cd ../build-stack
else fatal "can't find build-stack"; fi

if ! [ -d "../$4" ]; then fatal "kernel directory doesn't exist"; fi
cd "../$4"
scp arch/powerpc/boot/zImage "$1:$2/wiilinux/$3.krn" || fatal "failed to copy kernel"
cd ../

ssh "$1" umount "$2"
echo "Successfully copied to $1 at $2"
