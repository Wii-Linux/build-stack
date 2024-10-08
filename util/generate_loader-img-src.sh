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
mkdir loader-img-src
cd loader-img-src
if ! tar -p --xattrs -xf ../buildroot/output/images/rootfs.tar; then
	echo "failed to extract, nuking dir"
	cd ..
	rm -r loader-img-src
fi

