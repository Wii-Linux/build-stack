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

echo "output dir: $OUT"
echo "base dir: $BASE"

cd "$BASE"
rm -rf "$OUT"
mkdir -p "$OUT"

pacstrap -KMC build-stack/conf/wiilinux-pacman.conf "$OUT" base wii-linux-kernel-stable wii-linux-loader-stable wii-linux-meta gumboot-utils baedit networkmanager vim nano less wget openssh

# pacstrap doesn't maintain our custom pacman.conf
cp build-stack/conf/wiilinux-pacman.conf "$OUT/etc/pacman.conf"
cat << EOF > "$OUT"/setup.sh
#!/bin/sh
pacman-key --init
pacman-key --populate archpower
echo 'root:wiilinux' | chpasswd
gumboot-mkconfig -o /boot/gumboot/gumboot.lst
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
cp /var/lib/wii-linux/configmii/etc-issue/banner_wii-linux.txt /etc/issue
pacman --noconfirm -Scc
echo 'archpower-wii-linux' > /etc/hostname

EOF
chmod +x "$OUT"/setup.sh
chroot "$OUT" /setup.sh

echo "making a tarball of the rootfs"
tar --preserve-permissions --acls --xattrs --sparse -czf "${OUT}-boot.tar.gz" -C "$OUT/boot" .
rm -rf "$OUT"/boot/*
tar --preserve-permissions --acls --xattrs --sparse -czf "${OUT}-root.tar.gz" -C "$OUT/" .
