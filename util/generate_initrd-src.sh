#!/bin/sh -e

if [ "$(basename $PWD)" != "buildroot" ]; then
	echo "in wrong dir"
	exit 1
fi

make distclean
cp in-kernel-ramfs.config .config
make -j$(nproc)
