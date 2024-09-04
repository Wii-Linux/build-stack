#!/bin/sh -e

sudo powerpc-unknown-linux-gnu-gcc -Wall -Wextra -std=gnu2x \
	-nostdlib -nostartfiles -nostdinc \
	-Ofast -DPROD_BUILD \
	-Wl,-rpath ../loader-img-src/usr/lib -L ../loader-img-src/usr/lib \
	-isystem ../buildroot/output/host/powerpc-buildroot-linux-uclibc/sysroot/usr/include/ \
	-isystem ../buildroot/output/host/opt/ext-toolchain/lib/gcc/powerpc-buildroot-linux-uclibc/13.3.0/include \
	-l:libc.so.1 -lblkid -e main \
	../boot-stack/loader-img-full/bootMenu.c -o ../loader-img-src/bin/boot_menu
