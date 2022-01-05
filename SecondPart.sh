DEVICE=linux-rasp-pi4-v3d-g++
IP=192.168.1.128
CORES=$(nproc)
DIRECTORY=~/RaspberryQt
COMPILER_PATH=/opt/RaspCompiler
QT_VER=5.15
QT_SUB_VER=${QT_VER}.2

Red="\033[0;31m"
Green="\033[0;32m"
Reset="\033[0m"
Yellow="\033[0;33m"
Cyan="\033[0;36m"

echo -e ${Yellow}"Configure Qt..."${Reset}
cd ${DIRECTORY}/build
../qt-everywhere-src-5.15.2/configure -release -opengl es2 -eglfs -device ${DEVICE} -device-option CROSS_COMPILE=${COMPILER_PATH}/bin/arm-linux-gnueabihf- -sysroot ${COMPILER_PATH}/sysroot -prefix /usr/local/RaspberryQt -extprefix ~/CrossCompilers/${DEVICE}/${QT_SUB_VER} -opensource -confirm-license -skip qtscript -nomake tests -make libs -pkg-config -no-use-gold-linker -v -recheck | tee ${DIRECTORY}/log/config.log
#../qt-everywhere-src-5.15.2/configure -opengl es2 -release -eglfs -device ${DEVICE} -device-option CROSS_COMPILE=/opt/cross-pi-gcc/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin/arm-linux-gnueabihf- -sysroot ${COMPILER_PATH}/sysroot -prefix /usr/local/RaspberryQt -extprefix ~/CrossCompilers/${DEVICE}/${QT_SUB_VER} -opensource -confirm-license -skip qtscript -nomake tests -make libs -pkg-config -no-use-gold-linker -v -recheck | tee ${DIRECTORY}/log/config.log

