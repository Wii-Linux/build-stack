#!/bin/sh -e

usage() {
	cat << EOF
Usage: setup.sh <options>

Options:
       --help:                Display this usage info. 


Sets up the build environment to build Wii Linux.
This only needs to be run once - or, if it failed, multiple times, until
successful, if your environment fails some basic sanity checks.

This script will double check that your folder structure is what is expected
of the other scripts of the build stack.  If they are, then it proceeds to do
some simple first time setup (like generating initrd-src and loader-img-src).

Return codes:
       0                      Looks good
       1                      Internal error
       2                      Missing critical host programs
       3                      Missing critical files/directories

Report any bugs to the GitHub issues page.
EOF
}

if [ -f ./utils.sh ]; then . ./utils.sh; cd ..; BASE="$PWD"; cd - > /dev/null
elif [ -f ./build-stack/utils.sh ]; then . ./build-stack/utils.sh; BASE="$PWD"
elif [ -f ../build-stack/utils.sh ]; then cd ..; . ./build-stack/utils.sh; BASE="$PWD"
else
	echo "failed to find utils.sh" >&2
	exit 1
fi

case "$1" in
	-h|--help) usage; exit 0 ;; # show help
esac

cd "$BASE/build-stack"

if ! gcc -o util/doCheck util/checkStuff.c; then
	fatal "Failed to compile checkStuff.c"
fi

exec util/doCheck "$BASE"

