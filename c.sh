#!/bin/sh -e

sudo powerpc-unknown-linux-gnu-gcc -Wall -Wextra -std=gnu2x \
	-nostdlib -nostartfiles -nostdinc \
	-Ofast -DPROD_BUILD \
	-Wl,-rpath ../loader-img-src/usr/lib -L ../loader-img-src/usr/lib \
	-isystem ../dummy-sysroot-src/powerpc-buildroot-linux-uclibc/sysroot/usr/include/ \
	-isystem ../dummy-sysroot-src/lib/gcc/powerpc-buildroot-linux-uclibc/13.3.0/include \
	-l:libc.so.1 -lblkid -e main \
	../boot-stack/loader-img-full/bootMenu.c -o ../loader-img-src/bin/boot_menu
