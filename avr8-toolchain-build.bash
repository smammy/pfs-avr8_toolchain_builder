#!/bin/bash

basedir="~/avr8-gnu-toolchain-linux_x86_64"
pkgdir="/vagrant"
atversion="3.6.1"
atbuildnr="$(date --utc +%Y%m%d%H%M%S)-pfs"
aturl="https://office.innovative-electronics.com/third-party/atmel/distribute.atmel.no/tools/opensource/Atmel-AVR-GNU-Toolchain/$atversion"

################################################################################
# 
# This script will build the Atmel AVR8 GNU Toolchain for Linux on a fresh
# installation of Ubuntu 16.04. It handles dependency installation, source
# download, and packaging. It works around some braindead things in the Atmel
# build script.
# 
# It has been tested only with toolchain version 3.6.1 but it's possible that it
# would work with other toolchain versions.
# 
# It has only been tested on 64-bit Ubuntu, but it's possible that it would work
# on 32-bit Ubuntu as well.
# 
# It assumes that /var/cache/wget exists and is writable by the user executing
# the script. (We use this with vagrant-cachier to persist downloads between
# guest instances.)
# 
# Written by Sam Hathaway <sam@sam-hathaway.com>. To the extent possible under
# law, I waive all copyright and related or neighboring rights to this work.
# https://creativecommons.org/publicdomain/zero/1.0/
# 
################################################################################

mkdir -p "$basedir"
cd "$basedir"

hostarch=$(gcc -dumpmachine | awk -F- '{print$1}')
installdir="avr8-gnu-toolchain-linux_$hostarch"

wget_with_cache_dir="/var/cache/wget"
wget_with_cache ()
{
    for url in "$@"; do
        filename=$(basename "$url")
        echo "fetching $filename"
        mkdir -p "$wget_with_cache_dir"
        if [ ! -e "$wget_with_cache_dir/$filename" ]; then
            wget -O "$wget_with_cache_dir/$filename" "$url"
        fi
        cp "$wget_with_cache_dir/$filename" "$PWD"
    done
}

untar ()
{
    tarfile="$1"
    echo "expanding $tarfile"
    tar -xf "$tarfile"
}

################################################################################
if [ -z "$skip_prep" ]; then

sudo apt install -y \
    autoconf \
    make \
    gcc \
    tar \
    unzip \
    patch \
    texlive \
    netpbm \
    doxygen \
    texinfo \
    g++ \
    flex \
    transfig \
    texlive-latex-extra \
    bison \
    libpython2.7-dev \
    xz-utils

mkdir -p src
( cd src && wget_with_cache "$aturl"/avr-binutils.tar.bz2 \
                            "$aturl"/avr-gcc.tar.bz2 \
                            "$aturl"/avr-gdb.tar.bz2 \
                            "$aturl"/avr-libc.tar.bz2 \
  && for x in *.tar.*; do untar "$x"; done )

mkdir -p src/headers
( cd src/headers && wget_with_cache "$aturl"/avr8-headers.zip )

mkdir -p src/gmp
( cd src/gmp && wget_with_cache https://gmplib.org/download/gmp/gmp-5.0.2.tar.bz2 )

mkdir -p src/mpfr
( cd src/mpfr && wget_with_cache http://www.mpfr.org/mpfr-3.0.0/mpfr-3.0.0.tar.gz )

mkdir -p src/mpc
( cd src/mpc && wget_with_cache http://www.multiprecision.org/downloads/mpc-0.9.tar.gz )

mkdir -p src/ncurses
( cd src/ncurses && wget_with_cache ftp://ftp.invisible-island.net/ncurses/ncurses-5.9.tar.gz )

wget_with_cache "$aturl"/build-avr8-gnu-toolchain-git.sh
patch -p1 <<'EOT'
--- a/build-avr8-gnu-toolchain-git.sh	2018-04-27 21:21:15.205999999 +0000
+++ b/build-avr8-gnu-toolchain-git.sh	2018-04-27 21:21:53.833999999 +0000
@@ -1071,7 +1071,7 @@
     remove_build_folder "ncurses"
     do_mkpushd ${builddir}/ncurses

-    CFLAGS="-fPIC" $(ls -d ${srcdir}/ncurses-[0-9].*)/configure \
+    CPPFLAGS="-P" CFLAGS="-fPIC" $(ls -d ${srcdir}/ncurses-[0-9].*)/configure \
         --build=${build_platform} \
         --host=${host_platform} \
         --libdir=${PREFIX_HOSTLIBS}/${LIB_DIR} \
EOT
chmod +x build-avr8-gnu-toolchain-git.sh

mkdir -p "$installdir"

fi
################################################################################
if [ -z "$skip_build" ]; then

AVR_8_GNU_TOOLCHAIN_VERSION="$atversion" \
BUILD_NUMBER="$atbuildnr" \
    ./build-avr8-gnu-toolchain-git.sh -s src -p "$installdir"

fi
################################################################################
if [ -z "$skip_package" ]; then

tarfile="avr8-gnu-toolchain-$atversion.$atbuildnr.linux.any.$hostarch.tar.xz"
echo -n "Packaging toolchain"
fakeroot -- tar -cJf "$pkgdir/$tarfile" "$installdir" --checkpoint=.100
echo " done."
echo
echo
echo "If noting bad happened, you can find a toolchain package here:"
echo
echo "    $pkgdir/$tarfile"
echo
echo "Thanks for playing!"

fi
################################################################################
