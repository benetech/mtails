#!/bin/bash

# Martus M-Tails Builder Script
# by Nicholas Merrill nick@calyx.com
#
# Copyright (c) 2015 Benetech
#

if [[ "$1" == "clean" ]]; then
	sudo rm -rf /tmp/mtails-iso /tmp/working
	echo -e "\n\nCleaned up the downloaded packages and other working files."
	echo -e "You can now re-run the script with:"
	echo -e "$0"
	exit 0
elif [[ "$1" == "distclean" ]]; then
	sudo rm -rf /tmp/mtails-iso /tmp/tails-iso /tmp/working
	echo -e "\n\nCleaned up the doanloaded packages, Tails ISO image, and other working files."
	echo -e "You can now re-run the script with:"
	echo -e "$0"
	exit 0
else
	echo -e "M-Tails build script (c) 2015 Benetech\n\n"
fi

#Pull most recent stable Tails ISO and sig
RELEASE_STR=$(curl http://dl.amnesia.boum.org/tails/stable/ 2>&1 | grep -o -E 'href="tails-([^"#]+)"' | tail -n1 | cut -d'"' -f2 | sed 's|/||')
RELEASE_NUM=$(echo $RELEASE_STR | grep -o -E '[0-9]+\.[0-9]+(\.[0-9]+)?')

TAILS_ISO_URL="http://dl.amnesia.boum.org/tails/stable/$RELEASE_STR/$RELEASE_STR.iso"
TAILS_SIG_URL="https://tails.boum.org/torrents/files/$RELEASE_STR.iso.sig"
TAILS_KEY_URL="https://tails.boum.org/tails-signing.key"

#Pull most recent Martus release
MARTUS_REL=($(curl https://martus.org/download.html 2>&1 | grep -o -E 'Martus-[0-9]+\.[0-9]+(\.[0-9]+)?.zip'))

MARTUS_NUM=$(echo ${MARTUS_REL[0]} | grep -o -E '[0-9]+\.[0-9]+(\.[0-9]+)?')

#check if script is running as root, if it is then exit
if [[ "$(id -u)" = "0" ]]; then
	echo -e  "This script should not be run as root.  Please run as an unprivileged user."
	exit 1
fi

echo -e "installing local prerequisites and sources"

sudo apt-get install curl wget squashfs-tools
sudo add-apt-repository "deb http://mirrors.kernel.org/ubuntu wily main universe"
sudo add-apt-repository "deb http://ftp.us.debian.org/debian sid main"
sudo apt-get update

# create needed directories
echo -e  "Creating working directories...\n\n"
mkdir -p "/tmp/tails-iso"
mkdir -p "/tmp/tails-iso/mnt"
mkdir -p "/tmp/working"
cp chroot-tasks.sh martus-documentation.tgz *.desktop *.png martus-documentation /tmp/working/

# get the tails.iso if it isn't already there
echo -e "Checking if we already have the latest Tails ISO."

if [[ -f "/tmp/tails-iso/$RELEASE_STR.iso" ]]; then
	echo -e  "Tails ISO already exists.  Good."
fi

if [[ ! -f "/tmp/tails-iso/$RELEASE_STR.iso" ]]; then
	echo -e  "We don't have it yet.  Retrieving Tails ISO image\n\n"
	cd /tmp/tails-iso
	wget --progress=bar $TAILS_ISO_URL

	cd ..
fi

# verify the tails iso
echo -e  "\n\nVerifying the authenticity of the Tails ISO image using GPG signatures..."
if [[ ! -f "/tmp/tails-iso/tails-signing-key" ]]; then
	curl -o /tmp/tails-iso/tails-signing.key $TAILS_KEY_URL
fi
if [[ ! -f "/tmp/tails-iso/tails-iso.sig" ]]; then
	curl -o /tmp/tails-iso/tails-iso.sig $TAILS_SIG_URL

fi

rm -f /tmp/working/tmp_keyring.pgp
gpg -q --no-default-keyring --keyring /tmp/working/tmp_keyring.pgp --import /tmp/tails-iso/tails-signing.key

if gpg --no-default-keyring --keyring /tmp/working/tmp_keyring.pgp --fingerprint 58ACD84F | grep "A490 D0F4 D311 A415 3E2B  B7CA DBB8 02B2 58AC D84F"; then
	echo -e  "Tails developer key verified..."
else
	echo -e  "ERROR.  Tails developer key does not seem to be the right one.  Something strange is going on.  Exiting."
	exit 1
fi

echo -e "\n\nNow verifying that the signature on the Tails ISO matches the Tails developer key..."

if gpg -q --no-default-keyring --keyring /tmp/working/tmp_keyring.pgp --keyid-format long --verify /tmp/tails-iso/tails-iso.sig /tmp/tails-iso/$RELEASE_STR.iso; then
	echo -e  "Tails ISO signed by the Tails developer key and seems legitimate.  Proceeding."
else
	echo -e  "ERROR.  The Tails ISO does not seem to be signed by the proper signing key.  Something strange is going on. There may be an issue with the iso download, try running mtails-build.sh distclean first. Exiting."
	exit 1
fi

# mount the ISO image
echo -e  "\n\nMounting Tails ISO image.  You may need to enter your password."
sudo mount -o loop /tmp/tails-iso/$RELEASE_STR.iso /tmp/tails-iso/mnt

# extract the squashed filesystem
echo -e  "\n\nExtracting the compressed root filesystem from the Tails ISO image"
sudo cp /tmp/tails-iso/mnt/live/filesystem.squashfs /tmp/working

# decompress the squashed filesystem
if [[ -f "/tmp/working/squashfs-root" ]]; then
	echo -e  "\n\nSquashed filesystem already uncompressed.  Good."
fi

if [[ ! -f "/tmp/working/squashfs-root" ]]; then
	echo -e  "\n\nDecompressing the compressed root filesystem...  You may need to enter your password again."
	cd /tmp/working
	sudo unsquashfs filesystem.squashfs
fi

# download packages
echo -e  "\n\nDownloading Martus and its dependencies..."

PKG='libnss3'
if ! ls /tmp/working/$PKG*.deb 1> /dev/null 2>&1; then
	wget --progress=bar $(apt-get install --reinstall --print-uris -qq $PKG | cut -d"'" -f2 | grep "/${PKG}_")
fi

PKG='libjpeg62-turbo'
if ! ls /tmp/working/$PKG*.deb 1> /dev/null 2>&1; then
	wget --progress=bar $(apt-get install --reinstall --print-uris -qq $PKG | cut -d"'" -f2 | grep "/${PKG}_")
fi

PKG='openjdk-8-jre-headless'
if ! ls /tmp/working/$PKG*.deb 1> /dev/null 2>&1; then
	wget --progress=bar $(apt-get install --reinstall --print-uris -qq $PKG | cut -d"'" -f2 | grep "/${PKG}_")
fi

PKG='openjdk-8-jre'
if ! ls /tmp/working/$PKG*.deb 1> /dev/null 2>&1; then
	wget --progress=bar $(apt-get install --reinstall --print-uris -qq $PKG | cut -d"'" -f2 | grep "/${PKG}_")
fi

PKG='openjdk-8-jdk'
if ! ls /tmp/working/$PKG*.deb 1> /dev/null 2>&1; then
	wget --progress=bar $(apt-get install --reinstall --print-uris -qq $PKG | cut -d"'" -f2 | grep "/${PKG}_")
fi

PKG='openjfx'
if ! ls /tmp/working/$PKG*.deb 1> /dev/null 2>&1; then
	wget --progress=bar $(apt-get install --reinstall --print-uris -qq $PKG | cut -d"'" -f2 | grep "/${PKG}_")
fi

PKG='libopenjfx-java'
if ! ls /tmp/working/$PKG*.deb 1> /dev/null 2>&1; then
	wget --progress=bar $(apt-get install --reinstall --print-uris -qq $PKG | cut -d"'" -f2 | grep "/${PKG}_")
fi

PKG='libopenjfx-jni'
if ! ls /tmp/working/$PKG*.deb 1> /dev/null 2>&1; then
	wget --progress=bar $(apt-get install --reinstall --print-uris -qq $PKG | cut -d"'" -f2 | grep "/${PKG}_")
fi


PKG='libicu4j-4.4-java'
if ! ls /tmp/working/$PKG*.deb 1> /dev/null 2>&1; then
	wget --progress=bar $(apt-get install --reinstall --print-uris -qq $PKG | cut -d"'" -f2 | grep "/${PKG}_")
fi

PKG='tzdata-java'
if ! ls /tmp/working/$PKG*.deb 1> /dev/null 2>&1; then
	wget --progress=bar $(apt-get install --reinstall --print-uris -qq $PKG | cut -d"'" -f2 | grep "/${PKG}_")
fi

if [[ ! -f "/tmp/working/${MARTUS_REL[0]}" ]]; then
	wget --progress=bar "https://martus.org/installers/${MARTUS_REL[0]}"
fi


# copy packages into /tmp directory of squashfs
cp /tmp/working/*.deb /tmp/working/${MARTUS_REL[0]} /tmp/working/squashfs-root/tmp/

# chroot into the squashfs
echo -e "\n\nInstalling Martus into Tails root filesystem"
cp /tmp/working/chroot-tasks.sh /tmp/working/squashfs-root/tmp
sudo chroot /tmp/working/squashfs-root /tmp/chroot-tasks.sh


echo -e "\n\nCreating new Martus Tails ISO image..."
mkdir -p /tmp/mtails-iso
sudo rsync -av /tmp/tails-iso/mnt /tmp/mtails-iso

echo -e "\n\nInstalling Martus Documentation"
cd /tmp/working/squashfs-root/usr/share/doc
sudo tar -xzvf /tmp/working/martus-documentation.tgz
sudo cp /tmp/working/martus-documentation.desktop /tmp/working/squashfs-root/etc/skel/Desktop
sudo cp /tmp/working/martus-application.desktop /tmp/working/squashfs-root/etc/skel/Desktop
sudo cp /tmp/working/martus-documentation /tmp/working/squashfs-root/usr/local/bin/
sudo chmod 755 /tmp/working/squashfs-root/usr/local/bin/martus-documentation

echo -e "\n\nInstalling icons and desktop background"
sudo cp /tmp/working/martus-background.png /tmp/working/squashfs-root/usr/share/tails/desktop_wallpaper.png
sudo cp /tmp/working/martus-app.png /tmp/working/martus-docs.png /tmp/working/squashfs-root/usr/share/icons/gnome/48x48/categories/
sudo rm /tmp/working/squashfs-root/etc/skel/Desktop/Report_an_error.desktop

echo -e "\n\nCompressing the root directory"
sudo mksquashfs /tmp/working/squashfs-root /tmp/mtails-iso/filesystem.squashfs -b 1024k -comp xz -Xbcj x86 -e boot

echo -e "\n\nInserting the root directory into Mtails ISO"
sudo cp /tmp/mtails-iso/filesystem.squashfs /tmp/mtails-iso/mnt/live/

echo -e "\n\nwriting ISO file.."
sudo rm -f /tmp/mtails-iso/mtails$RELEASE_NUM-$MARTUS_NUM.iso
sudo mkisofs -r -V "M-Tails" -cache-inodes -J -l -no-emul-boot -boot-load-size 4 -boot-info-table -o /tmp/mtails-iso/mtails$RELEASE_NUM-$MARTUS_NUM.iso -b isolinux/isolinux.bin -c isolinux/boot.cat /tmp/mtails-iso/mnt

#sudo umount -f /tmp/tails-iso/mnt
#sudo umount -f /tmp/mtails-iso/mnt

echo -e  "\n\nInstallation complete.  You can find the iso image in /tmp/mtails-iso"
exit 0
