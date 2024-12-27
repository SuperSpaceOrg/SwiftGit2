#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/xcode_functions.sh"

function setup_build_environment ()
{
    # 设置 PATH
    local search_paths=(
        "/usr/local/bin"
        "/opt/homebrew/bin"  # Apple Silicon homebrew 路径
        "/opt/boxen/homebrew/bin"
    )
    PATH="$(IFS=:; echo "${search_paths[*]}"):$PATH"

    # 设置根路径
    pushd "$SCRIPT_DIR/.." > /dev/null
    ROOT_PATH="$PWD"
    popd > /dev/null

    # 编译器设置
    CLANG="/usr/bin/xcrun clang"
    CC="${CLANG}"
    CPP="${CLANG} -E"

    # 清除 Mac 部署目标
    MACOSX_DEPLOYMENT_TARGET="15.6"

    # 设置 iOS 部署目标
    if [ -z "${IPHONEOS_DEPLOYMENT_TARGET}" ]; then
        IPHONEOS_DEPLOYMENT_TARGET="11.0"  # 更新为更现代的版本
    fi

    # 获取 Xcode 版本
    XCODE_MAJOR_VERSION=$(xcode_major_version)

    # 导出 PLATFORM 变量供其他函数使用
    export PLATFORM
    export ARCHS

    # 简化架构设置，现代设备都支持 64 位
    CAN_BUILD_64BIT=1
}

function build_all_archs ()
{
    setup_build_environment
    local setup=$1
    local build_arch=$2
    local finish_build=$3

    # run the prepare function
    eval $setup

    # 设置针对模拟器的构建
    PLATFORM="iphonesimulator"
    SDKVERSION=$(ios_sdk_version)
    SDKNAME="${PLATFORM}${SDKVERSION}"
    SDKROOT="$(sdk_path ${SDKNAME})"
    
    # 模拟器支持 x86_64 (Intel Mac) 和 arm64 (Apple Silicon)
    echo "Building for simulator architectures: x86_64 arm64"
    for ARCH in x86_64 arm64
    do
        if [ "${ARCH}" == "arm64" ] && [ "${PLATFORM}"  != "iphonesimulator" ];
        then
            HOST="aarch64-apple-darwin"
        else
            HOST="${ARCH}-apple-darwin"
        fi
        if [ "${ARCH}" == "arm64" ] && [ "${PLATFORM}"  == "iphonesimulator" ];
        then
            HOST="aarch64-apple-ios-sim"
        fi 
        echo "Building ${LIBRARY_NAME} for ${SDKNAME} ${ARCH} ${PLATFORM} ${HOST}"
        echo "Please stand by..."
        eval $build_arch
    done

    # 设置针对真机的构建
    PLATFORM="iphoneos"
    SDKNAME="${PLATFORM}${SDKVERSION}"
    SDKROOT="$(sdk_path ${SDKNAME})"
    
    # 真机只需要 arm64
    echo "Building for device architecture: arm64"
    ARCH="arm64"
    HOST="aarch64-apple-darwin"
    echo "Building ${LIBRARY_NAME} for ${SDKNAME} ${ARCH}"
    echo "Please stand by..."
    eval $build_arch

    # finish the build (usually lipo)
    eval $finish_build
}
