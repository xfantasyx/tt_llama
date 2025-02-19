#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 添加lib注册表
source ${SCRIPT_DIR}/lib_register.sh

export ARCH="x64"
export VS_VERSION="Visual Studio 16 2019"
export ROOT_DIR="$( cd ${SCRIPT_DIR}/.. && pwd )"

# 设置远端账户和地址
REMOTE_URL=""

INSTALL_DIR=${ROOT_DIR}/install/vs2019/sdk
BUILD_GEN_DIR=${ROOT_DIR}/build_generated/vs2019
RUNTIME_DIR=${ROOT_DIR}/install/vs2019/runtime
SOURCE_ROOT_DIR=${ROOT_DIR}/sources

if [ ! -e "${INSTALL_DIR}" ]; then
    mkdir -p "${INSTALL_DIR}"
fi

if [ ! -e "${RUNTIME_DIR}" ]; then
    mkdir -p "${RUNTIME_DIR}"
fi
if [ ! -e "${RUNTIME_DIR}/Debug" ]; then
    mkdir -p  ${RUNTIME_DIR}/Debug
fi
if [ ! -e "${RUNTIME_DIR}/Debug/bin" ]; then
    mkdir -p  ${RUNTIME_DIR}/Debug/bin
fi
if [ ! -e "${RUNTIME_DIR}/Release" ]; then
    mkdir -p  ${RUNTIME_DIR}/Release
fi
if [ ! -e "${RUNTIME_DIR}/Release/bin" ]; then
    mkdir -p  ${RUNTIME_DIR}/Release/bin
fi
if [ ! -e "${RUNTIME_DIR}/RelWithDebInfo" ]; then
    mkdir -p  ${RUNTIME_DIR}/RelWithDebInfo
fi
if [ ! -e "${RUNTIME_DIR}/RelWithDebInfo/bin" ]; then
    mkdir -p  ${RUNTIME_DIR}/RelWithDebInfo/bin
fi
# =============================================================================
#
#  common install rumtime
#
# =============================================================================
common_install_runtime()
{
    if [ -z "$1" ]; then
        echo "error : please input lib name"
        return 1
    fi

    local lib_name="$1"
    local _label=$(lib_get_label $lib_name)
    local _install_path=$(lib_get_install_path $lib_name)

    echo "=== start copy ${_label} runtime files ===" 

    local _BUILD_TYPES=("Debug" "Release" "RelWithDebInfo")

    for build_type in "${_BUILD_TYPES[@]}" ; do
        if [ -e "${_install_path}/${build_type}/bin" ]; then
            for _filepath in ${_install_path}/${build_type}/bin/*.dll; do
                if [ -f "$_filepath" ]; then
                cp --verbose -rf "$_filepath" "$RUNTIME_DIR/${build_type}/bin"
                fi
            done

            for _filepath in ${_install_path}/${build_type}/bin/*.pdb; do
                if [ -f "$_filepath" ]; then
                cp --verbose -rf "$_filepath" "$RUNTIME_DIR/${build_type}/bin"
                fi
            done
        fi
    done

    echo "=== finished copy ${_label} runtime files ===" 
}

# =============================================================================
#
#  upload runtime
#
# =============================================================================
upload_runtime_release()
{
    (lum_upload_package "$RUNTIME_DIR/Release" "$REMOTE_URL/runtime")
}

# =============================================================================
#
#  zlib
#
# =============================================================================
register_lib zlib   \
            "zlib_1_3_11" \
            "${INSTALL_DIR}/zlib_1_3_11" \
            "common_install_runtime" \
            "${SOURCE_ROOT_DIR}/zlib" \
            "zlib_build"

zlib_build()
{
    local label=$(lib_get_label zlib)
    local install_path=$(lib_get_install_path zlib)
    local source_path=$(get_lib_source_path zlib)
    local build_path="${BUILD_GEN_DIR}/${label}"

    if [ ! -e "$source_path" ]; then
        echo "'${label}' source directory does not exist!"
        exit 1
    fi

    echo "*** start build ${label} ***"
   

    echo "install_path=${install_path}"
    echo "build_path=${build_path}"

    # rm exsit install
    if [ -e "${install_path}" ]; then
        rm -rf ${install_path}
    fi
    # rm exsit generated
    if [ -e "${build_path}" ]; then
        rm -rf ${build_path}
    fi

    # make generated dir
    mkdir -p  ${build_path}

    cd ${build_path}

    cmake -G "${VS_VERSION}" \
    -A "${ARCH}" \
    -DZLIB_BUILD_EXAMPLES=OFF \
    -DCMAKE_CONFIGURATION_TYPES="Debug;Release;RelWithDebInfo" \
    -DCMAKE_INSTALL_PREFIX="${install_path}" \
    -DINSTALL_BIN_DIR="$<CONFIGURATION>/bin" \
    -DINSTALL_LIB_DIR="$<CONFIGURATION>/lib" \
    -DINSTALL_INC_DIR="include" \
    -DINSTALL_MAN_DIR="share/man" \
    -DINSTALL_PKGCONFIG_DIR="share/pkgconfig" \
    ${source_path} || exit 1

    cmake --build . --target install --config Debug -- /maxcpucount:8 || exit 1
    cmake --build . --target install --config Release -- /maxcpucount:8 || exit 1
    cmake --build . --target install --config RelWithDebInfo -- /maxcpucount:8 || exit 1

    rm -rf ${install_path}/share

    echo "*** build finised ${label} ***"
}

# =============================================================================
#
#  TBB
#
# =============================================================================    
register_lib tbb \
            "tbb_2021_9" \
            "${INSTALL_DIR}/tbb_2021_9" \
            "common_install_runtime" \
            "${SOURCE_ROOT_DIR}/tbb-2021.9.0" \
            "tbb_build"

_tbb_build()
{
    local label=$(lib_get_label tbb)
    local install_path=$(lib_get_install_path tbb)
    local source_path=$(get_lib_source_path tbb)
    local build_path="${BUILD_GEN_DIR}/${label}"

    if [ -z "$1" ]; then
      echo "please input build type: ['debug', 'release', 'relwithdebinfo']"
      exit
    fi

    param="$1"
    low_build_type="${param,,}"

    build_type=""
    if [ "${low_build_type}" == "debug" ] ;then
        build_type="Debug"
    elif [ "${low_build_type}" == "release" ] ;then
        build_type="Release"
    elif [ "${low_build_type}" == "relwithdebinfo" ] ;then
        build_type="RelWithDebInfo"
    else
        echo "please input build type: ['debug', 'release', 'relwithdebinfo']"
        exit
    fi

    echo "*** start build ${label} ${build_type} ***"
    
    # make generated dir
    mkdir -p  ${build_path}/${build_type}

    cd ${build_path}/${build_type}

    cmake -G "${VS_VERSION}" \
    -A "${ARCH}" \
    -DTBB_TEST=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DTBBMALLOC_BUILD=OFF \
    -DCMAKE_CONFIGURATION_TYPES="Debug;Release;RelWithDebInfo" \
    -DCMAKE_INSTALL_PREFIX="${install_path}" \
    -DCMAKE_INSTALL_BINDIR="${build_type}/bin" \
    -DCMAKE_INSTALL_LIBDIR="${build_type}/lib" \
    ${source_path} || exit 1

    cmake --build . --target install --config ${build_type} -- /maxcpucount:8 || exit 1

    echo "*** build finised ${build_type} ${build_type} ***"
}
tbb_build()
{
    local label=$(lib_get_label tbb)
    local install_path=$(lib_get_install_path tbb)
    local source_path=$(get_lib_source_path tbb)
    local build_path="${BUILD_GEN_DIR}/${label}"

    if [ ! -e "$source_path" ]; then
        echo "'${label}' source directory does not exist!"
        exit 1
    fi

    echo "*** start build ${label} ***"
   

    echo "install_path=${install_path}"
    echo "build_path=${build_path}"

    # rm exsit install
    if [ -e "${install_path}" ]; then
        rm -rf ${install_path}
    fi
    # rm exsit generated
    if [ -e "${build_path}" ]; then
        rm -rf ${build_path}
    fi

    # make generated dir
    mkdir -p  ${build_path}

    cd ${build_path}

    _tbb_build debug
    _tbb_build release
    _tbb_build relwithdebinfo
    
    echo "*** build finised ${label} ***"
}   



# =============================================================================
#
#  openssl 
#
# =============================================================================
register_lib openssl \
            "openssl_3_0_5" \
            "${INSTALL_DIR}/openssl_3_0_5" \
            "openssl_install_runtime" \
            "${SOURCE_ROOT_DIR}/openssl-3.0.5" \
            "openssl_build"

openssl_build()
{
    local label=$(lib_get_label openssl)
    local install_path=$(lib_get_install_path openssl)
    local source_path=$(get_lib_source_path openssl)
    local build_path="${BUILD_GEN_DIR}/${label}"

    if [! -e "$source_path" ]; then
        echo "'${label}' source directory does not exist!"
        exit 1
    fi

    echo "*** start build ${label} ***" 
    
    echo "install_path=${install_path}"
    echo "build_path=${build_path}"
    echo "DPENS=$DPENS"

    # rm exsit install
    if [ -e "${install_path}" ]; then
    rm -rf ${install_path}
    fi
    # rm exsit generated
    if [ -e "${build_path}" ]; then
    rm -rf ${build_path}
    fi

    # make generated dir
    mkdir -p  ${build_path}

    cd ${build_path}

    perl ${source_path}/Configure VC-WIN64A no-shared --prefix=${install_path}/Release --openssldir=${source_path}

    nmake

    nmake install


    echo "*** build finised ${label} ***"

}

openssl_install_runtime()
{
    local _label=$(lib_get_label openssl)
    local package_dir=$(lib_get_install_path openssl)

    echo "=== start copy ${_label} runtime files ===" 


    for _filepath in ${package_dir}/Release/lib/ossl-modules/*.dll; do
        cp --verbose -rf "$_filepath" "$RUNTIME_DIR/Debug/bin"
        cp --verbose -rf "$_filepath" "$RUNTIME_DIR/RelWithDebInfo/bin"
        cp --verbose -rf "$_filepath" "$RUNTIME_DIR/Release/bin"
    done

    # for _filepath in ${package_dir}/Release/bin/*; do
    #     cp --verbose -rf "$_filepath" "$RUNTIME_DIR/Debug/bin"
    #     cp --verbose -rf "$_filepath" "$RUNTIME_DIR/RelWithDebInfo/bin"
    #     cp --verbose -rf "$_filepath" "$RUNTIME_DIR/Release/bin"
    # done

    echo "=== finished copy ${_label} runtime files ===" 
}

# =============================================================================
#
#  curl 
#
# =============================================================================
register_lib curl \
            "curl_7_84_0" \
            "${INSTALL_DIR}/curl_7_84_0" \
            "common_install_runtime" \
            "${SOURCE_ROOT_DIR}/curl-7.84.0" \
            "curl_build"

curl_build()
{
    local label=$(lib_get_label curl)
    local install_path=$(lib_get_install_path curl)
    local source_path=$(get_lib_source_path curl)
    local build_path="${BUILD_GEN_DIR}/${label}"

    if [ ! -e "$source_path" ]; then
        echo "'${label}' source directory does not exist!"
        exit 1
    fi

    DPENS="$(lib_get_install_path zlib)"
    DPENS+=":$(lib_get_install_path openssl)"


    echo "*** start build ${label} ***" 
    
    echo "install_path=${install_path}"
    echo "build_path=${build_path}"
    echo "DPENS=$DPENS"

    # rm exsit install
    if [ -e "${install_path}" ]; then
    rm -rf ${install_path}
    fi
    # rm exsit generated
    if [ -e "${build_path}" ]; then
    rm -rf ${build_path}
    fi

    # make generated dir
    mkdir -p  ${build_path}

    cd ${build_path}

    cmake -G "${VS_VERSION}" \
    -A "${ARCH}" \
    -DBUILD_SHARED_LIBS=ON \
    -DCURL_ZLIB=ON \
    -DCURL_USE_OPENSSL=ON \
    -DENABLE_IDN=OFF \
    -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON \
    -DCMAKE_CONFIGURATION_TYPES="Debug;Release;RelWithDebInfo" \
    -DCMAKE_INSTALL_PREFIX="${install_path}" \
    -DCMAKE_INSTALL_BINDIR="$<CONFIGURATION>/bin" \
    -DCMAKE_INSTALL_LIBDIR="$<CONFIGURATION>/lib" \
    -DCURL_INSTALL_CMAKE_DIR="cmake" \
    -DCMAKE_PREFIX_PATH="$DPENS" \
    ${source_path} || exit 1

    cmake --build . --target install --config Debug -- /maxcpucount:8 || exit 1
    cmake --build . --target install --config Release -- /maxcpucount:8 || exit 1
    cmake --build . --target install --config RelWithDebInfo -- /maxcpucount:8 || exit 1
    echo "*** build finised ${label} ***" 
}

# =============================================================================
#
#  llamacpp 
#
# =============================================================================
register_lib llamacpp \
            "llamacpp" \
            "${INSTALL_DIR}/llamacpp" \
            "llamacpp_install_runtime" \
            "${SOURCE_ROOT_DIR}/llama.cpp" \
            "llamacpp_build"

llamacpp_build()
{
    
    local label=$(lib_get_label llamacpp)
    local install_path=$(lib_get_install_path llamacpp)
    local source_path=$(get_lib_source_path llamacpp)
    local build_path="${BUILD_GEN_DIR}/${label}"

    if [ ! -e "$source_path" ]; then
        echo "'${label}' source directory does not exist!"
        exit 1
    fi

    DPENS="$(lib_get_install_path zlib)"
    DPENS+=":$(lib_get_install_path openssl)/release"
    DPENS+=":$(lib_get_install_path curl)"


    echo "*** start build ${label} ***" 
    
    echo "install_path=${install_path}"
    echo "build_path=${build_path}"
    echo "DPENS=$DPENS"

    # rm exsit install
    if [ -e "${install_path}" ]; then
    rm -rf ${install_path}
    fi
    # rm exsit generated
    if [ -e "${build_path}" ]; then
    rm -rf ${build_path}
    fi

    # make generated dir
    mkdir -p  ${build_path}

    cd ${build_path}

    cmake -G "${VS_VERSION}" \
    -A "${ARCH}" \
    -DBUILD_SHARED_LIBS=ON \
    -DLLAMA_CURL=ON \
    -DLLAMA_SERVER_SSL=ON \
    -DGGML_CUDA=OFF \
    -DGGML_VULKAN=ON \
    -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON \
    -DCMAKE_CONFIGURATION_TYPES="Debug;Release;RelWithDebInfo" \
    -DCMAKE_INSTALL_PREFIX="${install_path}" \
    -DCMAKE_INSTALL_BINDIR="$<CONFIGURATION>/bin" \
    -DCMAKE_INSTALL_LIBDIR="$<CONFIGURATION>/lib" \
    -DCMAKE_PREFIX_PATH="$DPENS" \
    ${source_path} || exit 1

    cmake --build . --target install --config Debug -- /maxcpucount:8 || exit 1
    cmake --build . --target install --config Release -- /maxcpucount:8 || exit 1
    cmake --build . --target install --config RelWithDebInfo -- /maxcpucount:8 || exit 1
    echo "*** build finised ${label} ***" 

    return 0
}

llamacpp_install_runtime()
{
    local _label=$(lib_get_label llamacpp)
    local package_dir=$(lib_get_install_path llamacpp)


    echo "=== start copy ${_label} runtime files ===" 

    cp --verbose -rf "${package_dir}/Debug/bin" "$RUNTIME_DIR/Debug"
    cp --verbose -rf "${package_dir}/Release/bin" "$RUNTIME_DIR/Release"
    cp --verbose -rf "${package_dir}/RelWithDebInfo/bin" "$RUNTIME_DIR/RelWithDebInfo"

    echo "=== finished copy ${_label} runtime files ===" 
}