#!/bin/bash

set -e

OUT_DIR="out"
mkdir -p ${OUT_DIR}

# V850 compiler
TOOLCHAIN_PREFIX="v850-elf-"

# RH850
FLAGS="-mv850e3v5 -mloop -mrh850-abi"

# C
${TOOLCHAIN_PREFIX}gcc ${FLAGS} test.c -o ${OUT_DIR}/rh850_test_c.elf
${TOOLCHAIN_PREFIX}size --format=berkeley ${OUT_DIR}/rh850_test_c.elf

# C++
${TOOLCHAIN_PREFIX}g++ ${FLAGS} --std=c++14 test.cpp -o ${OUT_DIR}/rh850_test_cpp.elf
${TOOLCHAIN_PREFIX}size --format=berkeley ${OUT_DIR}/rh850_test_cpp.elf

# CMake
(cd ${OUT_DIR} && CC=${TOOLCHAIN_PREFIX}gcc CXX=${TOOLCHAIN_PREFIX}g++ cmake -DFLAGS="${FLAGS}" .. && cmake --build .)
