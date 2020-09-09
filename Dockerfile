ARG TARGET_ARCH="v850-elf"
ARG TOOLCHAIN_VERSION="master"
ARG TOOLCHAIN_NAME="gcc-${TARGET_ARCH}-${TOOLCHAIN_VERSION}"
ARG TOOLCHAIN_PATH="/opt/${TOOLCHAIN_NAME}"

ARG UBUNTU_VERSION=20.04
FROM ubuntu:$UBUNTU_VERSION AS build

ARG TARGET_ARCH
ARG TOOLCHAIN_VERSION
ARG TOOLCHAIN_NAME
ARG TOOLCHAIN_PATH

ENV PATH="${TOOLCHAIN_PATH}/bin:${PATH}"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update && \
    apt-get -y install --no-install-recommends \
        build-essential \
        texinfo \
        wget \
    && rm -rf /var/lib/apt/lists/*

ENV DOWNLOAD_PATH="/tmp/${TOOLCHAIN_NAME}/download" \
    SOURCES_PATH="/tmp/${TOOLCHAIN_NAME}/sources" \
    BUILD_PATH="/tmp/${TOOLCHAIN_NAME}/build"

ENV BINUTILS_VERSION="2.34" \
    GCC_VERSION="9.3.0" \
    GMP_VERSION="6.2.0" \
    MPC_VERSION="1.1.0" \
    MPFR_VERSION="4.0.2" \
    NEWLIB_VERSION="3.3.0" \
    GDB_VERSION="9.2"

RUN wget --tries=10 --continue --no-check-certificate --no-verbose \
    https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.gz \
    https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz \
    https://gmplib.org/download/gmp/gmp-${GMP_VERSION}.tar.gz \
    https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VERSION}.tar.gz \
    https://www.mpfr.org/mpfr-${MPFR_VERSION}/mpfr-${MPFR_VERSION}.tar.gz \
    ftp://sourceware.org/pub/newlib/newlib-${NEWLIB_VERSION}.tar.gz \
    https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.gz \
    -P ${DOWNLOAD_PATH}

RUN mkdir -p ${SOURCES_PATH} && \
    for f in ${DOWNLOAD_PATH}/*.tar.gz; \
    do \
        tar xf "$f" -C ${SOURCES_PATH}; \
    done

RUN cd ${SOURCES_PATH}/gcc-${GCC_VERSION} && \
    ln -s ../gmp-${GMP_VERSION} gmp && \
    ln -s ../mpc-${MPC_VERSION} mpc && \
    ln -s ../mpfr-${MPFR_VERSION} mpfr

# build binutils
RUN mkdir -p ${BUILD_PATH}/binutils && \
    cd ${BUILD_PATH}/binutils && \
    ${SOURCES_PATH}/binutils-${BINUTILS_VERSION}/configure \
        --target=${TARGET_ARCH} \
        --prefix=${TOOLCHAIN_PATH} \
        --disable-nls \
    && \
    make -j$(nproc) all && \
    make install

ENV GCC_OPTS=" \
        --with-gnu-as \
        --with-gnu-ld \
        --disable-shared \
        --disable-libssp \
        --disable-threads \
        --disable-nls \
        --with-newlib \
    "

# build gcc - 1st pass
RUN mkdir -p ${BUILD_PATH}/gcc && \
    cd ${BUILD_PATH}/gcc && \
    ${SOURCES_PATH}/gcc-${GCC_VERSION}/configure \
        --target=${TARGET_ARCH} \
        --prefix=${TOOLCHAIN_PATH} \
        --enable-languages=c \
        --without-headers \
        ${GCC_OPTS} \
    && \
    make -j$(nproc) all-gcc && \
    make install-gcc

# build newlib
RUN mkdir -p ${BUILD_PATH}/newlib && \
    cd ${BUILD_PATH}/newlib && \
    ${SOURCES_PATH}/newlib-${NEWLIB_VERSION}/configure \
        --target=${TARGET_ARCH} \
        --prefix=${TOOLCHAIN_PATH} \
        --disable-nls \
    && \
    make -j$(nproc) all && \
    make install

# build gcc - 2nd pass
RUN cd ${BUILD_PATH}/gcc && \
    ${SOURCES_PATH}/gcc-${GCC_VERSION}/configure \
        --target=${TARGET_ARCH} \
        --prefix=${TOOLCHAIN_PATH} \
        --enable-languages=c,c++ \
        ${GCC_OPTS} \
    && \
    make -j$(nproc) all && \
    make install-strip

# build gdb
RUN mkdir -p ${BUILD_PATH}/gdb && \
    cd ${BUILD_PATH}/gdb &&\
    ${SOURCES_PATH}/gdb-${GDB_VERSION}/configure \
        --target=${TARGET_ARCH} \
        --prefix=${TOOLCHAIN_PATH} \
        --disable-nls \
    && \
    make -j$(nproc) all && \
    make install

# Toolchain only
FROM ubuntu:$UBUNTU_VERSION AS toolchain

ARG TOOLCHAIN_PATH

COPY --from=build ${TOOLCHAIN_PATH} ${TOOLCHAIN_PATH}
ENV PATH="${TOOLCHAIN_PATH}/bin:${PATH}"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update && \
    apt-get -y install --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        gnupg \
        software-properties-common \
        wget \
    && \
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | apt-key add - && \
    apt-add-repository -n 'https://apt.kitware.com/ubuntu/' && \
    apt-get -y update && \
    apt-get -y install --no-install-recommends \
        build-essential \
        cmake \
        ninja-build \
        python2 \
    && rm -rf /var/lib/apt/lists/* && \
