#!/bin/sh -e

usage() {
	cat << EOF
Usage: build-loader.sh <options>

Options:
       --boot-menu-type=[type]: Builds the boot menu targetting [type].
                                Default is PROD_BUILD.
                                The type can be one of:
                                  - 'DEBUG_PC':
                                      Debugging build for running on a PC.
                                      It WILL NOT attempt to actually boot
                                      the system, and WILL produce a logfile.
                                  - 'DEBUG_WII'
                                      Debugging build for running on a Wii.
                                      It WILL attempt to actually boot the
                                      system, and WILL produce a logfile.
                                  - 'PROD_BUILD'
                                      Normal build for running on a Wii.
                                      It WILL attempt to actually boot the
                                      system, and WILL NOT produce a logfile.


Builds a loader.img for your specified kernel version.
Assumes that you've already ran build-kernel.sh for this version.
This script heavily assumes a specific file structure is already set up.

I highly recommend creating a dedicated Wii Linux folder, and cloning at least:
- build-stack
- boot-stack
- kernel of your choice

and generating these ahead of time:
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

dir="loader-img-src"
boot_menu_type=PROD_BUILD

for arg in "$@"; do
	case "$arg" in
		"") usage; exit 1 ;; # user didn't provide anything
		--help) usage; exit 0 ;;
		--boot-menu-type|--boot-menu-type=) fatal "You must provide a type for this argument" ;;
		--boot-menu-type=*)
			type="$(echo "$arg" | sed 's/.*=//')"
			case "$type" in
				DEBUG_WII|DEBUG_PC|PROD_BUILD)
					checkValid "$tmp_got_type" true "2 build types"
					boot_menu_type="$type"; tmp_got_type=true ;;
				*) fatal "Invalid boot menu type \"$type\"" ;;
			esac
			;;
		*)
			error "Invalid parameter $arg"
			usage
			exit 1;;
	esac
done

if [ -d build-stack ]; then cd build-stack
elif [ -d ../build-stack ]; then cd ../build-stack
else fatal "can't find build-stack"; fi
cd ..

base=$PWD
cd "$base/build-stack"

./util/build-boot-menu.sh "-D${boot_menu_type}=1"

if [ -d "$base/boot-stack/loader-img-full" ]; then cd "$base/boot-stack/loader-img-full"
else fatal "can't find boot-stack/loader-img-full"; fi

tmp="$base/$dir"
if ! [ -d "$tmp" ]; then fatal "can't find $tmp"; fi

rm -f "$tmp/jit_setup.sh" || true
cp support.sh checkBdev.sh network.sh util.sh logging.sh "$tmp/" || fatal "Failed to copy files to $tmp"
cp init.sh "$tmp/linuxrc" || fatal "Failed to copy init to $tmp/linuxrc"
cp init.sh "$tmp/init" || fatal "Failed to copy init to $tmp/init"
if ! [ -d "$tmp/sbin" ]; then
	mkdir "$tmp/sbin" || fatal "Failed to mkdir $tmp/sbin"
fi
if [ -L "$tmp/sbin/init" ]; then
	# the copy will fail if it's a symlink, so prevent that
	rm -f "$tmp/sbin/init" || fatal "Failed to remove $tmp/sbin/init"
fi
cp init.sh "$tmp/sbin/init" || fatal "Failed to copy init to $tmp/sbin/init"
