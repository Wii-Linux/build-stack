#!/bin/sh -e

if [ "$(basename $PWD)" != "buildroot" ]; then
	echo "in wrong dir"
	exit 1
fi

make distclean
cp in-kernel-ramfs.config .config
make -j$(nproc)

# since we're in -e, we know that make succeded, but just in case
if ! [ -f output/images/rootfs.tar ]; then
	echo "rootfs.tar missing, something above probably failed"
	exit 1
fi

cd ..
mkdir initrd-src
cd initrd-src
if ! tar -p --xattrs -xf ../buildroot/output/images/rootfs.tar; then
	echo "failed to extract, nuking dir"
	cd ..
	rm -r initrd-src
fi

# causes SIGILL somehow if setuid.  It runs as root anyways, so it doesn't matter.
chmod -s usr/bin/busybox
