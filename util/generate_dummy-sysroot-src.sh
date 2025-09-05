#!/bin/sh -e

if [ "$(basename $PWD)" != "buildroot" ]; then
	echo "in wrong dir"
	exit 1
fi

make distclean
cp sdk.config .config
make -j$(nproc) sdk

# since we're in -e, we know that make succeded, but just in case
if ! [ -f output/images/powerpc-buildroot-linux-uclibc_sdk-buildroot.tar.gz ]; then
	echo "powerpc-buildroot-linux-uclibc_sdk-buildroot.tar.gz missing, something above probably failed"
	exit 1
fi

mkdir -p sdk
cp output/images/powerpc-buildroot-linux-uclibc_sdk-buildroot.tar.gz sdk/wii-linux.tar.gz

rm -rf ../dummy-sysroot-src || true
cp -r output/host ../dummy-sysroot-src

