#!/bin/bash
#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 引用 MSVC 下注册的 libs
source ${SCRIPT_DIR}/build_scripts/msvc_libs.sh

# 更新下载所有编译好的 lib
lib_download_and_install_runtime zlib
lib_download_and_install_runtime openssl
lib_download_and_install_runtime curl

# lib_build llamacpp "$@"

lib_build_and_install_runtime llamacpp "$@"
