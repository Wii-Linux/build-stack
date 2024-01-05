#!/bin/bash


usage() {
    echo "$0: Assemble a fully-featured rootfs from an assortment of pieces.
OPTIONS:
  -a, --already-built: Use the already compiled pieces instead of invoking
                       the scripts to build them automatically.
                       This can save some build time if you're only
                       rebuilding certain pieces.  You can manually
                       invoke the scripts to build only what you need,
                       then run this script with -a to use them.

  -h, --help:          Display this help message.
"
}

. ./utils.sh || { echo "failed to load utils.sh"; exit 1; }
baseDir=$(pwd)


# go parse the arguments so we know what do
for i in $@; do
    if [ "$i" = "-a" ] || [ "$i" = "--already-built" ]; then
        # probably part of CI, 
        alreadyBuilt=true
    elif [ "$i" = "-h" ] || [ "$i" = "--help" ]; then
        usage
        exit
    else
        error "Unknown argument \"$i\"!"
        usage
        fatal "Unknown argument... exiting"
    fi
done

cd /wii-linux-tools || fatal "failed to cd to /wii-linux-tools"

echo yay
exit 0