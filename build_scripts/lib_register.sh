#!/bin/bash
###############################################################################
# lib-register ： 用于注册和管理'lib'/'package'
###############################################################################


# 用于上传/下载的远端账户和地址
#
export REMOTE_URL="" # "--user name:password ftp://192.168.129.33/TTTTT/vs2019"

# =============================================================================
#
# download and update package
# 
# lum_download_package "c:\tt\zip_1_2_11" "--user name:password ftp://192.168.129.33/TTTTT/vs2019"
#
# =============================================================================
lum_download_package() 
{

    if [ -z "$1" ]; then
        echo "error : please input install dir"
        return 3
    fi

    if [ -z "$2" ]; then
        echo "error : please input download URL"
        return 4
    fi

    # 输入的完整路径
    local FULL_PATH="$1"
    # 判断最后一个字符是否是 '/'
    if [[ "${FULL_PATH: -1}" == "/" ]]; then
        # 去掉最后的 '/'
        FULL_PATH="${FULL_PATH%/}"
    fi

    # 获取父级路径作为存储压缩包的工作目录 
    local PARENT_DIR="${FULL_PATH%/*}"

    # 获取当前目录名称（作为 package 的名称）
    local PACKAGE_NAME="${FULL_PATH##*/}"

    echo "DOWNLOAD To : ${PARENT_DIR}"
    echo "PACKAGE_NAME=${PACKAGE_NAME}"


    local DOWNLOAD_URL="$2"
    local TAR_FILE="${PACKAGE_NAME}.tar.gz"
    local SHA_FILE="${PACKAGE_NAME}.tar.gz.sha256"

    local NEED_DOWNLOAD=0
    local NEED_OVERRIED=0

    cd "$PARENT_DIR"

    echo "====== Start Updating '${PACKAGE_NAME}' "
    echo "--- downloading '${SHA_FILE}...'"

    curl --insecure -L ${DOWNLOAD_URL}/${SHA_FILE} -o ${PARENT_DIR}/${SHA_FILE} 

    if [ ! -e "${PARENT_DIR}/${TAR_FILE}" ]; then
        NEED_DOWNLOAD=1
    fi

    if [ -e "${PARENT_DIR}/${SHA_FILE}" ]; then

        if ! sha256sum -c "${SHA_FILE}"; then

            echo "'${SHA_FILE} file SHA mismatch'"
            NEED_DOWNLOAD=1

        fi

    fi

    if [ $NEED_DOWNLOAD -eq 1 ]; then
        echo "--- downloading ${TAR_FILE} please wait..."

        curl --insecure -L ${DOWNLOAD_URL}/${TAR_FILE} -o ${PARENT_DIR}/${TAR_FILE}

        if [ ! -e "${PARENT_DIR}/${TAR_FILE}" ]; then
            echo "Failed to download ${TAR_FILE}! Please download '${TAR_FILE}' to '${PARENT_DIR}/${TAR_FILE}'"
            echo "====== Finished Updating '${PACKAGE_NAME}'"
            return 5
        fi

        NEED_OVERRIED=1

    fi

    if [ ! -d "${PARENT_DIR}/${PACKAGE_NAME}" ]; then
        NEED_OVERRIED=1
    fi

    if [ $NEED_OVERRIED -eq 1 ]; then

        if [ -e "${PARENT_DIR}/${PACKAGE_NAME}" ]; then
            rm -rf "${PARENT_DIR}/${PACKAGE_NAME}"
        fi

        echo "--- unpacking ${PACKAGE_NAME}"

        tar -xvf "${PARENT_DIR}/${TAR_FILE}" -C "${PARENT_DIR}"

        echo "====== Finished Updating '${PACKAGE_NAME}' ***"
        return 1
    fi

    echo "====== Finished Updating '${PACKAGE_NAME}'"
    return 0
}

# =============================================================================
#
# remove package
#
# =============================================================================
lum_remove_package() 
{
    if [ -z "$1" ]; then
        echo "error : please input remove dir"
        return 1
    fi

    if [ ! -e "$1" ]; then
        return 0
    fi

    # 输入的完整路径
    local FULL_PATH="$1"
    # 判断最后一个字符是否是 '/'
    if [[ "${FULL_PATH: -1}" == "/" ]]; then
        # 去掉最后的 '/'
        FULL_PATH="${FULL_PATH%/}"
    fi

    # 获取父级路径作为 tar 工作路径
    local PARENT_DIR="${FULL_PATH%/*}"

    # 获取当前目录名称（作为 package 的名称）
    local PACKAGE_NAME="${FULL_PATH##*/}"

    local TAR_FILE="${PACKAGE_NAME}.tar.gz"
    local SHA_FILE="${PACKAGE_NAME}.tar.gz.sha256"

    # rm lib dir
    if [ -e "${PARENT_DIR}/${PACKAGE_NAME}" ]; then
       rm -rf "${PARENT_DIR}/${PACKAGE_NAME}"
    fi

    # rm lib .tar.gz
    if [ -e "${PARENT_DIR}/${TAR_FILE}" ]; then
       rm -rf "${PARENT_DIR}/${TAR_FILE}"
    fi

    # rm lib .tar.gz.sha256
    if [ -e "${PARENT_DIR}/${SHA_FILE}" ]; then
       rm -rf "${PARENT_DIR}/${SHA_FILE}"
    fi

    echo "remove ${PACKAGE_NAME} finished"

    return 0
}
# =============================================================================
#
# upload package
#
# =============================================================================
lum_upload_package()
{
    if [ -z "$1" ]; then
        echo "error : please input upload dir."
        return -1
    fi

    if [ ! -e "$1" ]; then
        echo "error : input upload '$1' dir doesn't exist."
        return -1
    fi

    if [ -z "$2" ]; then
        echo "error : please input upload URL"
        return -1
    fi

    # 输入的完整路径
    local FULL_PATH="$1"
    # 判断最后一个字符是否是 '/'
    if [[ "${FULL_PATH: -1}" == "/" ]]; then
        # 去掉最后的 '/'
        FULL_PATH="${FULL_PATH%/}"
    fi

    # 获取父级路径作为 tar 工作路径
    local TAR_WARKING_DIR="${FULL_PATH%/*}"

    # 获取当前目录名称（作为 package 的名称）
    local PACKAGE_NAME="${FULL_PATH##*/}"


    local UPLOAD_URL="$2"
    local TAR_FILE="${PACKAGE_NAME}.tar.gz"
    local SHA_FILE="${PACKAGE_NAME}.tar.gz.sha256"

    echo "=== start upload ${PACKAGE_NAME} ==="

    cd ${TAR_WARKING_DIR}

    set -e

    tar -czvf ${PACKAGE_NAME}.tar.gz ${PACKAGE_NAME} --dereference

    shasum -a 256 ${PACKAGE_NAME}.tar.gz > ${PACKAGE_NAME}.tar.gz.sha256

    curl --insecure --ftp-create-dirs -T ${PACKAGE_NAME}.tar.gz ${UPLOAD_URL}/
    curl --insecure --ftp-create-dirs -T ${PACKAGE_NAME}.tar.gz.sha256 ${UPLOAD_URL}/

    echo "=== finished upload ${PACKAGE_NAME} ==="

    return 0
}


###############################################################################
#
# 注册 lib 
#
###############################################################################

# 返回给定名称的变量的值
# $1: 变量名
#
# 例如:
#    FOO=BAR
#    BAR=ZOO
#    echo `var_value $FOO`
# 
#    打印输出：'ZOO'
#
var_value ()
{
    eval echo "$`echo $1`"
}


export LIB_NAMES=""
export LIB_INSTALL_PATHS=""

# 设置给定的选项属性
# $1: lib name
# $2: lib attr name
# $2: lib attr value
lib_attr_set ()
{
   eval LIBS_$1_$2=\"$3\"
}

# 获取给定的选项属性
# $1: lib name
# $2: lib attr name
lib_attr_get ()
{
    echo `var_value LIBS_$1_$2`
}


# =============================================================================
#
# 注册一个新 lib 
# $1: lib name 
# $2: lib label
# $3: lib install path
# $4: lib runtime install function
# $5: lib source path
# $6: lib build function
#
# ep: register_lib zlib  zlib_1_2_11 "/c/install/zlib_1_2_11" "zlib_install_runtime" "/d/tt/source/zlib_1_2_11" "zlib_build"
# zlib_install_runtime()
# {}
#
# zlib_build()
# {}
#
# =============================================================================
register_lib ()
{
    if [ -z "$1" ]; then
        echo "error : please input lib name"
        return 1
    fi

    if [ -z "$2" ]; then
        echo "error : please input lib label"
        return 1
    fi

    if [ -z "$3" ]; then
        echo "error : please input lib install path"
        return 1
    fi

    local lib_name="$1"
    local lib_label="$2"
    local lib_install_path="$3"

    LIB_NAMES="$LIB_NAMES $lib_name"

    if [ -n "$LIB_INSTALL_PATHS" ] ; then
        LIB_INSTALL_PATHS+=":"
    fi
    LIB_INSTALL_PATHS+="$lib_install_path"

    lib_attr_set ${lib_name} label "$lib_label"
    lib_attr_set ${lib_name} install "$lib_install_path"
    lib_attr_set ${lib_name} rt_install_func "$4"
    lib_attr_set ${lib_name} src "$5"
    lib_attr_set ${lib_name} build_func "$6"
}
export -f register_lib


# =============================================================================
#
# 获取 lib label
# 
# ep: zlib_label=$(lib_get_label zlib)
#
# =============================================================================
lib_get_label()
{
    if [ -z "$1" ]; then
        echo "error : please input lib name"
        return 1
    fi

    local lib_name="$1"
    label=`lib_attr_get $lib_name label`
    echo "$label"
}
export -f lib_get_label


# =============================================================================
#
# 获取 lib install path
#
# ep: zlib_install_path=$(lib_get_install_path zlib)
#
# =============================================================================
lib_get_install_path()
{
    if [ -z "$1" ]; then
        echo "error : please input lib name"
        return 1
    fi

    local lib_name="$1"
    path=`lib_attr_get $lib_name install`
    echo "$path"
}
export -f lib_get_install_path


# =============================================================================
#
# 获取 lib source path
#
# ep: zlib_source_path=$(get_lib_source_path zlib)
#
# =============================================================================
get_lib_source_path()
{
    if [ -z "$1" ]; then
        echo "error : please input lib name"
        return 1
    fi

    local lib_name="$1"
    path=`lib_attr_get $lib_name src`
    echo "$path"
}
export -f get_lib_source_path



# =============================================================================
#
# 获取所有库的安装目录合并后的字符串
#
# ep: depens=$(get_all_install_paths)
#
# =============================================================================
get_all_install_paths()
{
    echo "$LIB_INSTALL_PATHS"
}
export -f get_all_install_paths


# =============================================================================
#
# 打印所有库的安装路径
#
# =============================================================================
print_install_paths()
{
    for lib_name in $LIB_NAMES; do
        path=`lib_attr_get $lib_name install`
        echo "*** $lib_name=$path"
    done
}
export -f print_install_paths


# =============================================================================
#
# 打包上传 lib 的源码
#
# ep: lib_source_upload zlib
#
# =============================================================================
lib_source_upload()
{
    if [ -z "$1" ]; then
        echo "error : please input lib name"
        return 1
    fi

    if [ -z "$REMOTE_URL" ]; then
        echo "error : 'REMOTE_URL' is null."
        return 2
    fi

    local lib_name="$1"
    local source_path=$(get_lib_source_path $lib_name)

    if [ -z "$source_path" ]; then
        return 3
    fi

    (lum_upload_package "$source_path" "$REMOTE_URL/sources")
}
export -f lib_source_upload

# =============================================================================
#
# 打包上传所有已注册的 lib 的源码
#
# =============================================================================
lib_source_upload_all()
{
    if [ -z "$REMOTE_URL" ]; then
        echo "error : 'REMOTE_URL' is null."
        return 1
    fi

    for lib_name in $LIB_NAMES; do
        (lib_source_upload $lib_name)
    done
    
}
export -f lib_source_upload_all
# =============================================================================
#
# 下载远端打包好的 lib 的源码包
#
# ep: lib_source_download zlib
#
# =============================================================================
lib_source_download()
{
    if [ -z "$1" ]; then
        echo "error : please input lib name"
        return 1
    fi

    if [ -z "$REMOTE_URL" ]; then
        echo "error : 'REMOTE_URL' is null."
        return 2
    fi

    local lib_name="$1"
    local local_source_save_path=$(get_lib_source_path $lib_name)

    if [ -z "$local_source_save_path" ]; then
        return 3
    fi

    (lum_download_package "$local_source_save_path" "$REMOTE_URL/sources")

}
export -f lib_source_download

# =============================================================================
#
# 下载所有已注册的 lib 的源码
#
# =============================================================================
lib_source_download_all()
{

    if [ -z "$REMOTE_URL" ]; then
        echo "error : 'REMOTE_URL' is null."
        return 2
    fi

    for lib_name in $LIB_NAMES; do
        (lib_source_download $lib_name)
    done

}
export -f lib_source_download_all
# =============================================================================
#
# 打包上传构建好的 lib install 目录 
#
# ep: lib_install_upload zlib
#
# =============================================================================
lib_install_upload()
{
    if [ -z "$1" ]; then
        echo "error : please input lib name"
        return 1
    fi

    if [ -z "$REMOTE_URL" ]; then
        echo "error : 'REMOTE_URL' is null."
        return 2
    fi

    local lib_name="$1"
    local install_path=$(lib_get_install_path $lib_name)

    if [[ "$install_path" == *:* ]]; then
        IFS=':' read -r -a paths <<< "$install_path"
        (lum_upload_package "${paths[0]}" "$REMOTE_URL")
    else
        (lum_upload_package "$install_path" "$REMOTE_URL")
    fi

}
export -f lib_install_upload

# =============================================================================
#
# 打包上传所有已注册 lib 的 install 目录 
#
# =============================================================================
lib_install_upload_all()
{

    if [ -z "$REMOTE_URL" ]; then
        echo "error : 'REMOTE_URL' is null."
        return 2
    fi

    for lib_name in $LIB_NAMES; do
        (lib_install_upload $lib_name)
    done

}
export -f lib_install_upload_all

# =============================================================================
#
# 下载远端打包好的 lib install
#
# ep: lib_install_download zlib
#
# =============================================================================
lib_install_download()
{
    if [ -z "$1" ]; then
        echo "error : please input lib name"
        return 2
    fi

    if [ -z "$REMOTE_URL" ]; then
        echo "error : 'REMOTE_URL' is null."
        return 3
    fi

    local lib_name="$1"
    local install_path=$(lib_get_install_path $lib_name)

    if [[ "$install_path" == *:* ]]; then
        IFS=':' read -r -a paths <<< "$install_path"
        (lum_download_package "${paths[0]}" "$REMOTE_URL")
    else
        (lum_download_package "$install_path" "$REMOTE_URL")
    fi
}
export -f lib_install_download

# =============================================================================
#
# 下载所有已注册 lib 的远端 install 包
#
# =============================================================================
lib_install_download_all()
{

    if [ -z "$REMOTE_URL" ]; then
        echo "error : 'REMOTE_URL' is null."
        return 2
    fi

    for lib_name in $LIB_NAMES; do
        (lib_install_download $lib_name)
    done

}
export -f lib_install_download_all
# =============================================================================
#
# 调用 lib build 函数进行编译
#
# ep: lib_build zlib
#
# =============================================================================
lib_build()
{
    if [ -z "$1" ]; then
        echo "error : please input lib name" >&2
        return 1
    fi

    lib_name="$1"
    function_name=`lib_attr_get $lib_name build_func`

    if [ -z "$function_name" ]; then
        echo "error : can't find lib '$lib_name'" >&2
        return 2
    fi


    # shift 
    
    if declare -f "$function_name" > /dev/null; then
        ($function_name \"$@\")
    else
         echo "warn : '$lib_name' build function is unregister or null." >&2
    fi
}
export -f lib_build

# =============================================================================
#
# 构建所有已注册的 lib（如果带源码）
#
# =============================================================================
lib_build_all()
{
    for lib_name in $LIB_NAMES; do
        (lib_build $lib_name)
    done
}
export -f lib_build_all

# =============================================================================
#
# 调用 lib 运行时需要拷贝文件的函数
#
# ep: lib_install_runtime zlib
#
# =============================================================================
lib_install_runtime()
{
    if [ -z "$1" ]; then
        echo "error : please input lib name" >&2
        return 1
    fi

    local lib_name="$1"
    function_name=`lib_attr_get $lib_name rt_install_func`

    # shift 
    
    if declare -f "$function_name" > /dev/null; then
        ($function_name $@)
    else
         echo "info : '$lib_name' no install runtime function." >&2
    fi
}
export -f lib_install_runtime

# =============================================================================
#
# 拷贝所有已注册 lib 的运行时文件
#
# =============================================================================
lib_install_runtime_all()
{
    for lib_name in $LIB_NAMES; do
        (lib_install_runtime $lib_name)
    done
}
export -f lib_install_runtime_all

# =============================================================================
#
# 对 lib 进行构建，并且成功构建后进行打包上传 install 目录
#
# ep: lib_build_and_upload zlib
#
# =============================================================================
lib_build_and_upload_install()
{

    (lib_build $@)

    if [ $? -eq 0 ]; then
        (lib_install_upload $@)
    fi
}
export -f lib_build_and_upload_install

# =============================================================================
#
# 对所有已注册的 lib 进行构建并上传上传 install 目录
#
# =============================================================================
lib_build_and_upload_install_all()
{
    for lib_name in $LIB_NAMES; do
        (lib_build $lib_name)
        (lib_install_upload $lib_name)
    done
}
export -f lib_build_and_upload_install_all

# =============================================================================
#
# 首先下载远端打包好的 install 文件，如果缺失则进行构建
#
# ep: lib_download_or_build zlib
#
# =============================================================================
lib_download_or_build()
{
    if [ -z "$1" ]; then
        echo "error : please input lib name"
        return 1
    fi

    if [ -z "$REMOTE_URL" ]; then
        echo "error : 'REMOTE_URL' is null."
        return 2
    fi

    local lib_name="$1"
    local install_path=$(lib_get_install_path $lib_name)

    (lum_download_package $install_path $REMOTE_URL)


    if [ $? -gt 1 ]; then
        # 需要构建
        (lib_build $lib_name)
    fi

}
export -f lib_download_or_build

# =============================================================================
#
# 下载远端打包好的 lib 并拷贝 runtime
#
# ep: lib_download_and_install_runtime zlib
#
# =============================================================================
lib_download_and_install_runtime()
{
    if [ -z "$1" ]; then
        echo "error : please input lib name"
        return 2
    fi

    if [ -z "$REMOTE_URL" ]; then
        echo "error : 'REMOTE_URL' is null."
        return 3
    fi

    local lib_name="$1"
    local install_path=$(lib_get_install_path $lib_name)

    if [[ "$install_path" == *:* ]]; then
        IFS=':' read -r -a paths <<< "$install_path"
        (lum_download_package "${paths[0]}" "$REMOTE_URL")
    else
        (lum_download_package "$install_path" "$REMOTE_URL")
    fi

    if [ $? -eq 1 ]; then
        (lib_install_runtime $lib_name)
    fi

}
export -f lib_download_and_install_runtime

# =============================================================================
#
# 调用函数进行编译并拷贝 runtime 所需的文件
#
# ep: lib_build_and_install_runtime zlib
#
# =============================================================================
lib_build_and_install_runtime()
{
    if [ -z "$1" ]; then
        echo "error : please input lib name" >&2
        return 1
    fi

    lib_name="$1"
    function_name=`lib_attr_get $lib_name build_func`

    if [ -z "$function_name" ]; then
        echo "error : can't find lib '$lib_name'" >&2
        return 2
    fi


    # shift 
    
    if declare -f "$function_name" > /dev/null; then
        ($function_name \"$@\")

        if [ $? -eq 0 ]; then
            (lib_install_runtime $lib_name)
        fi
    else
         echo "warn : '$lib_name' build function is unregister or null." >&2
    fi
}
export -f lib_build