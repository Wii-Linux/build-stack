#!/bin/sh -e

usage() {
	cat << EOF
Usage: generate-archpower-rootfs.sh [output dir]

Options:
	--help:               Display this help text.

This script generates an ArchPOWER rootfs with Wii Linux packages installed.
It expects that you are using packages.wii-linux.org as the repo.  Should this
not be the case, you can modify conf/pacman.conf to point it at your custom
repo.

Note, this script **WILL** rm -rf whatever directory is passed.  Please
be careful!  No issues will be accepted about
"I hosed my system because I passed '/' as the first argument"!!!!!!

Report any bugs to the GitHub issues page.
EOF
}

first_letter=$(printf %.1s "$1")
if [ "$first_letter" = "/" ] && [ "$1" != "/" ]; then
	# absolute path, but we aren't hosing the host
	OUT="$1"
else
	# relative path
	OUT="$PWD/$1"
fi

# strip trailing /
OUT="${OUT%/}"

if [ -f ./utils.sh ]; then . ./utils.sh; cd ../; BASE="$PWD"; cd - > /dev/null
elif [ -f ./build-stack/utils.sh ]; then . ./build-stack/utils.sh; BASE="$PWD"
elif [ -f ../build-stack/utils.sh ]; then . ../build-stack/utils.sh; cd ../; BASE="$PWD"; cd - > /dev/null
else
	echo "failed to find utils.sh" >&2
	exit 1
fi


if [ "$1" = "/" ]; then
	fatal "Prevented hosing host system"
fi

for arg in "$@"; do
	case "$arg" in
		"") usage; exit 1 ;; # user didn't provide anything
		-h|--help) usage; exit 0 ;; # show help
		--) break ;;
		-*) error "bad argument"; usage; exit 1 ;;
		*) break ;; # probably a directory
	esac
done

if [ "$(id -u)" != "0" ]; then
	fatal "Script must be run as root, as it uses pacstrap."
fi

if ! command -v mkfs.ext4 > /dev/null || ! command -v mkfs.vfat > /dev/null; then
	fatal "Missing mkfs.ext4 or mkfs.vfat"
fi

if ! command -v zip > /dev/null; then
	fatal "Missing zip"
fi

echo "output dir: $OUT"
echo "base dir: $BASE"

cd "$BASE"
rm -rf "$OUT"
mkdir -p "$OUT"

pacstrap -KMC build-stack/conf/wiilinux-pacman.conf "$OUT" base archpower-keyring wii-linux-kernel-stable wii-linux-loader-stable wii-linux-meta gumboot-utils baedit networkmanager vim nano less wget openssh

# pacstrap doesn't maintain our custom pacman.conf
cp build-stack/conf/wiilinux-pacman.conf "$OUT/etc/pacman.conf"
cat << EOF > "$OUT"/setup.sh
#!/bin/sh
# set the pacman keys
pacman-key --init
pacman-key --populate archpower

# set password hash type to SHA256 since yescrypt is so damn slow
sed -i 's/ENCRYPT_METHOD YESCRYPT/ENCRYPT_METHOD SHA256/' /etc/login.defs

# set password
echo 'root:wiilinux' | chpasswd

# generate gumboot config
gumboot-mkconfig -o /boot/gumboot/gumboot.lst

# enable services
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
systemctl enable wii-linux-first-boot

# set default /etc/issue
cp /var/lib/wii-linux/configmii/etc-issue/banner_wii-linux.txt /etc/issue

# clear pacman cache
yes | pacman -Scc

# set default hostname
echo 'archpower-wii-linux' > /etc/hostname
EOF
chmod +x "$OUT"/setup.sh
chroot "$OUT" /setup.sh

echo "making disk images"
fallocate -l 2G "$OUT-full-sd.img"
fallocate -l 1792M "$OUT-root.img"
cat << EOF | fdisk "$OUT-full-sd.img"
o
n
p
1

+256M
n
p
2


w
EOF


loop="$(losetup --show -Pf "$OUT-full-sd.img")"
mkfs.ext4 -O '^verity' -O '^metadata_csum_seed' -L 'arch' "${loop}p2"
mkfs.vfat -F32 "${loop}p1"

mount "${loop}p2" "$OUT-mnt" --mkdir
mount "${loop}p1" "$OUT-mnt/boot" --mkdir
echo "copying boot to mounted image"
cp -a "$OUT"/boot/* "$OUT-mnt/boot/"
umount "$OUT-mnt/boot"

# we're copying this
rmdir "$OUT-mnt/boot"


echo "making a tarball of the boot files"
tar --preserve-permissions --acls --xattrs --sparse -czf "${OUT}-boot.tar.gz" -C "$OUT/boot" .

echo "making a ZIP out of the boot files"
(
	cd "$OUT/boot"
	zip -r "$OUT-boot.zip" .
)

echo "deleting boot files in preparation to make rootfs tarball"
rm -rf "$OUT"/boot/*

echo "making rootfs tarball"
tar --preserve-permissions --acls --xattrs --sparse -czf "${OUT}-root.tar.gz" -C "$OUT/" .

echo "making rootfs image"
cp -a "$OUT"/* "$OUT-mnt/"
umount "$OUT-mnt"

dd if="${loop}p2" of="$OUT-root.img" bs=1M

echo "removing loop devices"
losetup -d "${loop}"

echo "removing temporary mount directory"
rmdir "$OUT-mnt"

echo "compressing disk images"
echo "Full SD..."
gzip "$OUT-full-sd.img"

echo "Rootfs only..."
gzip "$OUT-root.img"

echo "Done!"
