#!/bin/bash

# Only set variable if it's not already set.
# This allows the caller to easily override these values using env vars.
maybe_set () { eval "[ -z \${$1+set} ] && $1=$2"; }

maybe_set basedir "/home/vagrant/avr8-toolchain-build"
maybe_set destdir "/vagrant/releases"
maybe_set platform x86_64-linux-gnu
maybe_set archname x86_64
maybe_set atversion "3.6.1"
maybe_set atbuildnr "$(date --utc +%Y%m%d%H%M%S)-pfs"
maybe_set installbase "avr8-gnu-toolchain-linux"
maybe_set tarbase "avr8-gnu-toolchain-$atversion.$atbuildnr.linux.any"
maybe_set aturl "http://distribute.atmel.no/tools/opensource/Atmel-AVR-GNU-Toolchain/$atversion"
maybe_set dlcache "/var/cache/wget"

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

wget_with_cache ()
{
    for url in "$@"; do
        local filename=$(basename "$url")
        echo "fetching $filename"
        mkdir -p "$dlcache"
        if [ ! -e "$dlcache/$filename" ]; then
            wget -O "$dlcache/$filename" "$url"
        fi
        cp "$dlcache/$filename" "$PWD"
    done
}

untar ()
{
    local tarfile="$1"
    echo "expanding $tarfile"
    tar -xf "$tarfile"
}

do_prepare ()
{
    [ -n "$skip_prepare" ] && return
    
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
}

do_build ()
{
    [ -n "$skip_build" ] && return
    
    local platform="$1"
    local installdir="$2"
    
    echo "platform triple is: $platform"
    echo "prefix directory is: $installdir (relative to $(pwd))"
    
    mkdir -p "$installdir"
    
    AVR_PREFIX="$installdir" \
    AVR_8_GNU_TOOLCHAIN_VERSION="$atversion" \
    BUILD_NUMBER="$atbuildnr" \
    PARALLEL_JOBS=-j$(nproc) \
        ./build-avr8-gnu-toolchain-git.sh -s src -H "$platform"
}

do_package ()
{
    [ -n "$skip_package" ] && return
    
    local installdir="$1"
    local tarfile="$2"
    
    echo -n "Packaging $installdir"
    fakeroot -- tar -cJf "$tarfile" "$installdir" --checkpoint=.100
    echo " done."
}

squawk ()
{
    echo
    echo "################################################################################"
    echo "##### $(date) ##### $@"
    echo "################################################################################"
    echo
}

################################################################################

mkdir -p "$basedir"
mkdir -p "$destdir"
cd "$basedir"

squawk "Configuration:"

echo "           basedir: $basedir"
echo "           destdir: $destdir"
echo "          platform: $platform"
echo "          archname: $archname"
echo "         atversion: $atversion"
echo "         atbuildnr: $atbuildnr"
echo "       installbase: $installbase"
echo "           tarbase: $tarbase"

squawk "Preparing for build..."
do_prepare

squawk "Compiling $archname toolchain..."
do_build "$platform" "${installbase}_$archname"

squawk "Packaging $archname toolchain..."
do_package "${installbase}_$archname" "$destdir/$tarbase.$archname.tar.xz"

squawk "Build complete!"
echo "If nothing bad happened, you can find a toolchain package here:"
echo
echo "    $destdir/$tarbase.$archname.tar.xz"
echo
