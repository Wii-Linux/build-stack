if [ "$1" = "" ]; then
	echo "you must specify a version"
	exit 1
fi

./versioned_deploy.sh ../kernel/arch/powerpc/boot/zImage kernels "wii_linux_kernel_$1-{timestamp}.elf"
./versioned_deploy.sh ../kernel/modules.tar.gz modules "wii_linux_modules_$1-{timestamp}.tar.gz"
