if [ "$1" = "" ]; then
	echo "you must specify a version"
	exit 1
fi

./versioned_deploy.sh ../$1.ldr loaders "wii_linux_loader_$1-{timestamp}.img"
