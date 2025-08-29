#!/bin/sh
sys=$(lsb_release -i -s)
name=$(whoami)
dir=/home/${name}/git/oxi/

case "$sys" in
    ubuntu|Ubuntu)
        dir=/home/${name}/git/oxi/
        ;;
    kylin|Kylin)
        dir=/data/usershare/git/oxi/
        ;;
    *)
        echo "not suport: $sys"
        exit 1
        ;;
esac

MATCH_PATTERN="OXiScan*"

# 使用find命令搜索目录，并将结果存储在变量中
proDir=$(find "$dir" -maxdepth 1 -type d -name "$MATCH_PATTERN")

# 检查变量是否为空
if [ -z "$proDir" ]; then
    # 如果为空，则报错
    echo "错误: 在目录 $dir 下没有找到名字包含OXiScan的文件夹" >&2
    exit 1
else
    # 如果不为空，则输出找到的文件夹路径
    echo "在目录 $dir 下找到了名字包含OXiScan的文件夹: $proDir"
fi

echo "system ${sys}"
echo "username ${name}"
echo "git dir ${dir}"
echo "project dir ${proDir}"

cd ${proDir}
rm -rf CMakeFiles
rm -rf cmake-build-release-ubuntu_x64
rm -f CMakeCache.txt
rm -f cmake_install.cmake
rm -f Makefile

cd dev/fap70
rm -rf CMakeFiles
rm -f CMakeCache.txt
rm -f cmake_install.cmake
rm -f Makefile

cd ${proDir}

cmake .
make -j4

echo "cp ${proDir}/dev/fap70/libFAP70.so ${dir}/GSerQtSimple/$sys/ "
cp ${proDir}/dev/fap70/libFAP70.so ${dir}/GSerQtSimple/$sys/