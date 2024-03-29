#!/bin/bash

set -e
set -o pipefail

sudo apt-get -y update
sudo apt-get -y install make m4 binutils coreutils gcc g++ texinfo texlive

TOOLCHAIN_NAME="gcc-v850-elf-master"
TOOLCHAIN_PATH="/opt/${TOOLCHAIN_NAME}"
TARGET_ARCH="v850-elf"

NUMJOBS="-j$(nproc)"
export PATH=$PATH:${TOOLCHAIN_PATH}/bin

DOWNLOAD_PATH="/tmp/${TOOLCHAIN_NAME}/download"
SOURCES_PATH="/tmp/${TOOLCHAIN_NAME}/sources"
BUILD_PATH="/tmp/${TOOLCHAIN_NAME}/build"

# prepare install path
sudo mkdir -p ${TOOLCHAIN_PATH}
sudo chown ${UID}.${UID} ${TOOLCHAIN_PATH}
rm -rf ${TOOLCHAIN_PATH:?}/*

# prepare temporary build folders
mkdir -p ${DOWNLOAD_PATH}
mkdir -p ${SOURCES_PATH}
mkdir -p ${BUILD_PATH}

rm -rf ${DOWNLOAD_PATH:?}/*
rm -rf ${SOURCES_PATH:?}/*
rm -rf ${BUILD_PATH:?}/*

# software versions
BINUTILS_VERSION="2.36.1"
GCC_VERSION="10.3.0"
GMP_VERSION="6.2.1"
MPC_VERSION="1.2.1"
MPFR_VERSION="4.1.0"
GDB_VERSION="10.2"
NEWLIB_VERSION="4.1.0"

# download sources
wget -c -P ${DOWNLOAD_PATH} https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.gz
wget -c -P ${DOWNLOAD_PATH} https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz
wget -c -P ${DOWNLOAD_PATH} https://ftp.gnu.org/gnu/gmp/gmp-${GMP_VERSION}.tar.bz2
wget -c -P ${DOWNLOAD_PATH} https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VERSION}.tar.gz
wget -c -P ${DOWNLOAD_PATH} https://ftp.gnu.org/gnu/mpfr/mpfr-${MPFR_VERSION}.tar.gz
wget -c -P ${DOWNLOAD_PATH} https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.gz
wget -c -P ${DOWNLOAD_PATH} ftp://sourceware.org/pub/newlib/newlib-${NEWLIB_VERSION}.tar.gz

for f in ${DOWNLOAD_PATH}/*.tar.gz
do
    tar xf "$f" -C ${SOURCES_PATH}
done

for f in ${DOWNLOAD_PATH}/*.tar.bz2
do
    tar xjf "$f" -C ${SOURCES_PATH}
done

(cd ${SOURCES_PATH}/gcc-${GCC_VERSION}/ && ln -sf ../gmp-${GMP_VERSION} gmp)
(cd ${SOURCES_PATH}/gcc-${GCC_VERSION}/ && ln -sf ../mpc-${MPC_VERSION} mpc)
(cd ${SOURCES_PATH}/gcc-${GCC_VERSION}/ && ln -sf ../mpfr-${MPFR_VERSION} mpfr)


# build binutils
mkdir -p ${BUILD_PATH}/binutils
cd ${BUILD_PATH}/binutils

${SOURCES_PATH}/binutils-${BINUTILS_VERSION}/configure \
--target=${TARGET_ARCH} \
--prefix=${TOOLCHAIN_PATH} \
--disable-nls

make ${NUMJOBS}
make install


# build gcc - 1st pass
mkdir -p ${BUILD_PATH}/gcc
cd ${BUILD_PATH}/gcc

${SOURCES_PATH}/gcc-${GCC_VERSION}/configure \
--target=${TARGET_ARCH} \
--prefix=${TOOLCHAIN_PATH} \
--enable-languages=c \
--without-headers \
--with-gnu-as \
--with-gnu-ld \
--with-newlib \
--disable-nls

make ${NUMJOBS} all-gcc
make install-gcc


# build newlib
mkdir -p ${BUILD_PATH}/newlib
cd ${BUILD_PATH}/newlib

# -fcommon forced to mitigate newlib syscalls.c issue with
# 'multiple definition of `errno' due to -fno-common enabled
# by default since gcc-10

export CFLAGS_FOR_TARGET="-Os -fcommon"
${SOURCES_PATH}/newlib-${NEWLIB_VERSION}/configure \
--target=${TARGET_ARCH} \
--prefix=${TOOLCHAIN_PATH} \
--enable-newlib-nano-formatted-io \
--disable-nls

make ${NUMJOBS}
make install


# build gcc - 2nd pass
cd ${BUILD_PATH}/gcc
${SOURCES_PATH}/gcc-${GCC_VERSION}/configure \
--target=${TARGET_ARCH} \
--prefix=${TOOLCHAIN_PATH} \
--enable-languages=c,c++ \
--with-headers=yes \
--with-gnu-as \
--with-gnu-ld \
--with-newlib \
--disable-libssp \
--disable-threads \
--disable-shared \
--disable-nls

make ${NUMJOBS}
make install


# build gdb
mkdir -p ${BUILD_PATH}/gdb
cd ${BUILD_PATH}/gdb

${SOURCES_PATH}/gdb-${GDB_VERSION}/configure \
--target=${TARGET_ARCH} \
--prefix=${TOOLCHAIN_PATH} \
--disable-nls

make ${NUMJOBS}
make install


# run test compilation - C
echo "
int main() {
    int a = 0;
    return 0;
}
" > ${BUILD_PATH}/rh850_test.c
v850-elf-gcc -mv850e3v5 -mloop -mrh850-abi ${BUILD_PATH}/rh850_test.c  -o ${BUILD_PATH}/rh850_test_c.elf
v850-elf-size --format=berkeley ${BUILD_PATH}/rh850_test_c.elf

# run test compilation - C++
echo "
#include <vector>
#include <array>

auto get_value() { return 0.0; }

int main() {
    std::vector<int> test_vec;
    std::array<int, 5> test_array{ {3, 4, 5, 1, 2} };
    for(auto i: test_array)
        test_vec.push_back(i);
    double value = get_value();
    return 0;
}
" > ${BUILD_PATH}/rh850_test.cpp
v850-elf-g++ -mv850e3v5 -mloop -mrh850-abi --std=c++14 ${BUILD_PATH}/rh850_test.cpp -o ${BUILD_PATH}/rh850_test_cpp.elf
v850-elf-size --format=berkeley ${BUILD_PATH}/rh850_test_cpp.elf
