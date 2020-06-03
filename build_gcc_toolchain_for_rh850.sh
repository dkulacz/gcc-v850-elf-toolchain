#!/bin/bash

set -e
set -o pipefail

sudo apt install make m4 binutils coreutils gcc g++ texinfo texlive

TOOLCHAIN_NAME="rh850-hkp-none-eabi"
TOOLCHAIN_PATH="/opt/${TOOLCHAIN_NAME}"
HOST_ARCH="x86_64-pc-linux-gnu"
TARGET_ARCH="v850-elf"

export MAKEFLAGS='-j1' # todo: MAKEFLAGS='-j$(nproc)'
export PATH=$PATH:${TOOLCHAIN_PATH}/bin

DOWNLOAD_PATH="${PWD}/tmp-build/${TOOLCHAIN_NAME}/download"
SOURCES_PATH="${PWD}/tmp-build/${TOOLCHAIN_NAME}/sources"
BUILD_PATH="${PWD}/tmp-build/${TOOLCHAIN_NAME}/build"

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

# download sources
wget -c -P ${DOWNLOAD_PATH} https://ftp.gnu.org/gnu/binutils/binutils-2.34.tar.gz
wget -c -P ${DOWNLOAD_PATH} https://ftp.gnu.org/gnu/gcc/gcc-9.3.0/gcc-9.3.0.tar.gz
wget -c -P ${DOWNLOAD_PATH} https://gmplib.org/download/gmp/gmp-6.2.0.tar.gz
wget -c -P ${DOWNLOAD_PATH} https://ftp.gnu.org/gnu/mpc/mpc-1.1.0.tar.gz
wget -c -P ${DOWNLOAD_PATH} https://www.mpfr.org/mpfr-current/mpfr-4.0.2.tar.gz
wget -c -P ${DOWNLOAD_PATH} https://sourceware.org/pub/newlib/newlib-3.3.0.tar.gz
wget -c -P ${DOWNLOAD_PATH} https://ftp.gnu.org/gnu/gdb/gdb-9.1.tar.gz

tar zxvf ${DOWNLOAD_PATH}/binutils-2.34.tar.gz -C ${SOURCES_PATH}
tar zxvf ${DOWNLOAD_PATH}/gcc-9.3.0.tar.gz -C ${SOURCES_PATH}
tar zxvf ${DOWNLOAD_PATH}/gmp-6.2.0.tar.gz -C ${SOURCES_PATH}
tar zxvf ${DOWNLOAD_PATH}/mpc-1.1.0.tar.gz -C ${SOURCES_PATH}
tar zxvf ${DOWNLOAD_PATH}/mpfr-4.0.2.tar.gz -C ${SOURCES_PATH}
tar zxvf ${DOWNLOAD_PATH}/newlib-3.3.0.tar.gz -C ${SOURCES_PATH}
tar zxvf ${DOWNLOAD_PATH}/gdb-9.1.tar.gz -C ${SOURCES_PATH}

(cd ${SOURCES_PATH}/gcc-9.3.0/ && ln -s ../gmp-6.2.0 gmp)
(cd ${SOURCES_PATH}/gcc-9.3.0/ && ln -s ../mpc-1.1.0 mpc)
(cd ${SOURCES_PATH}/gcc-9.3.0/ && ln -s ../mpfr-4.0.2 mpfr)


# build binutils
mkdir -p ${BUILD_PATH}/binutils
cd ${BUILD_PATH}/binutils

${SOURCES_PATH}/binutils-2.34/configure \
--target=${TARGET_ARCH} \
--prefix=${TOOLCHAIN_PATH} \
--disable-nls \
-v 2>&1 | tee configure.out

make -w 2>&1 | tee make.out
make -w install 2>&1 | tee make.out


# build gcc - 1st pass
mkdir -p ${BUILD_PATH}/gcc
cd ${BUILD_PATH}/gcc

${SOURCES_PATH}/gcc-9.3.0/configure \
--target=${TARGET_ARCH} \
--prefix=${TOOLCHAIN_PATH} \
--enable-languages=c \
--without-headers \
--with-gnu-as \
--with-gnu-ld \
--with-newlib \
--disable-nls \
-v 2>&1 | tee configure.out

make -w all-gcc 2>&1 | tee make.out
make -w install-gcc 2>&1 | tee make.out


# build newlib
mkdir -p ${BUILD_PATH}/newlib
cd ${BUILD_PATH}/newlib

${SOURCES_PATH}/newlib-3.3.0/configure \
--target=${TARGET_ARCH} \
--prefix=${TOOLCHAIN_PATH} \
--disable-nls \
-v 2>&1 | tee configure.out

make -w 2>&1 | tee make.out
make -w install 2>&1 | tee make.out


# build gcc - 2nd pass
cd ${BUILD_PATH}/gcc
${SOURCES_PATH}/gcc-9.3.0/configure \
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
--disable-nls \
-v 2>&1 | tee configure.out

make -w 2>&1 | tee make.out
make -w install 2>&1 | tee make.out


# build gdb
mkdir -p ${BUILD_PATH}/gdb
cd ${BUILD_PATH}/gdb

${SOURCES_PATH}/gdb-9.1/configure \
--target=${TARGET_ARCH} \
--prefix=${TOOLCHAIN_PATH} \
--disable-nls \
-v 2>&1 | tee configure.out

make -w 2>&1 | tee make.out
make -w install 2>&1 | tee make.out


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
