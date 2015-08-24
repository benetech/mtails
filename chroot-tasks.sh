#!/bin/bash

# Install deb dependencies and unzip Martus Desktop client into /usr/local/martus
mount /proc
echo -e "\n\nInstalling Debian packages for Martus Desktop client dependencies"
dpkg -i /tmp/libnss3_3.17.2-1.1_i386.deb /tmp/libjpeg62-turbo_1.4.1-1_i386.deb /tmp/openjdk-8-jre-headless_8u66-b01-1_i386.deb
dpkg -i /tmp/openjdk-8-jre_8u66-b01-1_i386.deb /tmp/openjdk-8-jdk_8u66-b01-1_i386.deb
dpkg -i --force-all /tmp/libopenjfx-jni_8u40-b25-3_i386.deb
dpkg -i --force-all /tmp/openjfx_8u40-b25-3_i386.deb /tmp/libopenjfx-java_8u40-b25-3_all.deb /tmp/libicu4j-4.4-java_4.4.2.2-2_all.deb
dpkg -i --force-all /tmp/tzdata-java_2015f-1_all.deb
echo -e "\n\nInstalling Martus 5.1 into /usr/local/martus"
mkdir -p /usr/local/martus
cd /usr/local/martus
if [[ ! -f "/usr/local/martus/MartusClient-5.1" ]]; then
	unzip /tmp/Martus-5.1.zip
fi
chmod 644 /usr/local/martus/MartusClient-5.1.0/ThirdParty/icu4j-3.4.4.jar /usr/local/martus/MartusClient-5.1.0/ThirdParty/velocity-dep-1.4.jar
rm -f /tmp/*.deb /tmp/*.zip
umount -f /proc
exit
