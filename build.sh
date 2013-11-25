#!/bin/sh
#
#  Author: Rick Boykin
#
#  Installs a gcc cross compiler for compiling code for raspberry pi on OSX.
#  This script is based on several scripts and forum posts I've found around
#  the web, the most significant being: 
#
#  http://okertanov.github.com/2012/12/24/osx-crosstool-ng/
#  http://crosstool-ng.org/hg/crosstool-ng/file/715b711da3ab/docs/MacOS-X.txt
#  http://gnuarmeclipse.livius.net/wiki/Toolchain_installation_on_OS_X
#  http://elinux.org/RPi_Kernel_Compilation
#
#
#  And serveral articles that mostly dealt with the MentorGraphics tool, which I
#  I abandoned in favor of crosstool-ng
#
#  The process:
#      Create case sensitive volume using hdiutil and mount it to /Volumes/$ImageName
#
#      Download, patch and build crosstool-ng
#
#      Configure and build the toolchain.
#
#  License:
#      Please feel free to use this in any way you see fit.
#
set -e
set -u

say() { printf "%s\n" "$*" ; }
abspath() {
    case "$1" in
    /*) say "$*" ;;
    *) say "$(pwd)/$*" ;;
    esac
}

#
# Config. Update here to suit your specific needs.
#
InstallBase="$(abspath "$(dirname "$0")")"
GnuRoot="${GnuRoot:-/opt/local}"
ImageName=CrossTool2NG
ImageNameExt="${ImageName}.sparseimage"
CrossToolVersion=crosstool-ng-1.18.0
ToolChainName=arm-unknown-linux-gnueabi
ToolChainNameConfig="$InstallBase/arm-unknown-linux-gnueabi.config"

die() { say "$*" >&2 ; exit 1 ; }
createCaseSensitiveVolume() {
    diskutil umount "/Volumes/${ImageName}" || diskutil umount force "/Volumes/${ImageName}" || true
    rm -f "$ImageNameExt" || true
    hdiutil create "$ImageName" -volname "$ImageName" -type SPARSE -size 8g -fs HFSX
    hdiutil mount "$ImageNameExt"
}

buildCrosstool() {
	for i in /usr/bin/make \
    "$GnuRoot/bin/gobjcopy" \
	"$GnuRoot/bin/gobjdump" \
	"$GnuRoot/bin/granlib" \
	"$GnuRoot/bin/greadelf" \
	"$GnuRoot/bin/glibtool" \
	"$GnuRoot/bin/glibtoolize" \
	"$GnuRoot/bin/gsed" \
	"$GnuRoot/bin/gawk" \
	"$GnuRoot/bin/automake" \
	"$GnuRoot/bin/bash" \
    ; do type "$i" >/dev/null 2>&1 || die "Please install ${i}." ; done
    tar xjvf "~/Downloads/${CrossToolVersion}.tar.bz2" -C "/Volumes/$ImageName/"
    (cd "/Volumes/$ImageName/$CrossToolVersion"
    sed -i .bak '6i\
#include <stddef.h>' kconfig/zconf.y
    wget -q -O /dev/null https://google.com || die "Either https://google.com is down, or you must set \`ca_directory = /path/to/certs\` in ~/.wgetrc"
    ./configure --enable-local \
    --build=x86_64-apple-darwin --host="$ToolChainName" \
	--with-objcopy="$GnuRoot/bin/gobjcopy"             \
	--with-objdump="$GnuRoot/bin/gobjdump"             \
	--with-ranlib="$GnuRoot/bin/granlib"               \
	--with-readelf="$GnuRoot/bin/greadelf"             \
	--with-libtool="$GnuRoot/bin/glibtool"             \
	--with-libtoolize="$GnuRoot/bin/glibtoolize"       \
	--with-sed="$GnuRoot/bin/gsed"                     \
	--with-awk="$GnuRoot/bin/gawk"                     \
	--with-automake="$GnuRoot/bin/automake"            \
	--with-bash="$GnuRoot/bin/bash"                    \
    --with-make=/usr/bin/make                           \
	CFLAGS="-std=c99 -Doffsetof=__builtin_offsetof"
    # make-3.81 required. make-3.82 has problems with some glibc, eglibc versions.
    /usr/bin/make EXTRA_LDFLAGS="/opt/local/lib/libintl.a /opt/local/lib/libiconv.a -framework CoreFoundation"
    )
}

createToolchain() {
    mkdir "/Volumes/$ImageName/$ToolChainName"
    # the process seems to open a a lot of files at once. The default is 256. Bump it to 1024.
    ulimit -n 1024
    # Downloaded archives go here.
    mkdir "$HOME/src" 2>/dev/null || true
    (cd "/Volumes/$ImageName/$ToolChainName"
    PATH="$GnuRoot/bin:$PATH" "../${CrossToolVersion}/ct-ng" "$ToolChainName"
    PATH="$GnuRoot/bin:$PATH" "../${CrossToolVersion}/ct-ng" clean
    cp "$InstallBase/${ToolChainName}.config" ./.config
    PATH="$GnuRoot/bin:$PATH" "../${CrossToolVersion}/ct-ng" menuconfig
    )
}

buildToolchain() {
    cd "/Volumes/$ImageName/$ToolChainName"
    PATH="$GnuRoot/bin:$PATH" "../${CrossToolVersion}/ct-ng" build.4
}

set -x
createCaseSensitiveVolume
buildCrosstool
createToolchain
buildToolchain
