#!/bin/sh -e

usage() {
	cat << EOF
Usage: copy-ssh.sh [host] [dest] [short ver] [pretty ver] [kernel src]
                   [loader] <options>

Options:
         -i,--ios:            Use a different directory structure for booting
                              this kernel from the Homebrew Channel, or similar
                              homebrew loader that uses the standard "IOS"
                              firmware that standard Wii apps and games use.

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

Examples:

IOS kernel version 4.5.0, residing in 'kernel-4.5-clean', copy to
techflash@172.16.4.10, and on that machine, the directory /mnt/sd is where
you want to place the files.
copy-ssh.sh techflash@172.16.4.10 /mnt/sd v4_5_0i 4.5.0 kernel-4.5-clean \
            v4_5_0i.ldr -i

MINI kernel version 4.4.302-cip80, residing in 'kernel-4.4-cip80', copy to
techflash@172.16.4.10, and on that machine, the directory /mnt/sd is where
you want to place the files.
copy-ssh.sh techflash@172.16.4.10 /mnt/sd v4_4_302 4.4.302-cip80 \
            kernel-4.4-cip80 v4_4_302.ldr


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
		-i|--ios) use_ios_dirs=true ;;
		-h|--help) usage; exit 0 ;; # show help
	esac
done
if [ "$#" -lt "5" ] || [ "$#" -gt "7" ]; then
	error "invalid number of arguments"
	usage; exit 1
fi

if [ -d build-stack ]; then cd build-stack
elif [ -d ../build-stack ]; then cd ../build-stack
else fatal "can't find build-stack"; fi

if ! [ -d "../$5" ]; then fatal "kernel directory doesn't exist"; fi
cd "../$5"
if [ "$use_ios_dirs" = "true" ]; then
	ssh "$1" mkdir -p "$2/apps/linux$3"
	rm -rf ../tmp-sd
	mkdir ../tmp-sd || fatal "failed to make temp sd dir"
	cd ../tmp-sd

	cp "../$5/arch/powerpc/boot/zImage" boot.elf || fatal "failed to copy kernel locally"
	cp ../build-stack/sd_files/apps/'linux{{ver}}'/* .

	sed -i "s/{{fullver}}/$4/g" meta.xml
	scp ./* "$1:$2/apps/linux$3/" || fatal "failed to copy files to remote"
else
	scp arch/powerpc/boot/zImage "$1:$2/wiilinux/$3.krn" || fatal "failed to copy kernel"

	rm -rf ../tmp-sd
fi
cd ../

if ! [ -f "$6" ]; then fatal "loader doesn't exist"; fi
scp "$6" "$1:$2/wiilinux/$3.ldr" || fatal "failed to copy loader"

ssh "$1" umount "$2"
echo "Successfully copied to $1 at $2"


