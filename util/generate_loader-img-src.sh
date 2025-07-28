#!/bin/sh -e

if [ "$(basename $PWD)" != "buildroot" ]; then
	echo "in wrong dir"
	exit 1
fi

make distclean
cp loader-img.config .config
make -j$(nproc)

# since we're in -e, we know that make succeded, but just in case
if ! [ -f output/images/rootfs.tar ]; then
	echo "rootfs.tar missing, something above probably failed"
	exit 1
fi

cd ..
rm -rf loader-img-src || true
mkdir loader-img-src
cd loader-img-src
if ! tar -p --xattrs -xf ../buildroot/output/images/rootfs.tar; then
	echo "failed to extract, nuking dir"
	cd ..
	rm -r loader-img-src
fi

# causes SIGILL somehow if setuid.  It runs as root anyways, so it doesn't matter.
chmod -s usr/bin/busybox

# force /sbin/init to exist and point to us
ln -sf /linuxrc usr/sbin/init

# add symlinks for ld.so
ln -sf ld-uClibc.so.1 usr/lib/ld.so.0
ln -sf ld-uClibc.so.1 usr/lib/ld.so.1
