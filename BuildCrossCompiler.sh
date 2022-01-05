Red="\033[0;31m"
Green="\033[0;32m"
Reset="\033[0m"
Yellow="\033[0;33m"
Cyan="\033[0;36m"

CORES=$(nproc)
PI_IP=192.168.1.128
Destination=/opt/RaspCompiler

optstring="i:c:"
while getopts ${optstring} arg; do
  case ${arg} in
	i)
		PI_IP=${OPTARG};;
	c)
		Destination=${OPTARG};;
	?)
		echo "Invalid option: -${OPTARG}."
		exit 1;;
	esac
done

echo -e ${Yellow}"Installing prerequisites..."${Reset}
sudo apt-get update
sudo apt-get install -y build-essential gawk git texinfo bison file wget

echo -e ${Yellow}"Creating dirs..."${Reset}
sudo mkdir -p ${Destination}/gcc_all && cd ${Destination}/gcc_all
sudo chown -R $USER ${Destination}

echo -e ${Yellow}"Downloading source..."${Reset}
wget https://ftpmirror.gnu.org/binutils/binutils-2.31.tar.bz2
wget https://ftpmirror.gnu.org/glibc/glibc-2.28.tar.bz2
wget https://ftpmirror.gnu.org/gcc/gcc-8.3.0/gcc-8.3.0.tar.gz
wget https://ftpmirror.gnu.org/gcc/gcc-10.1.0/gcc-10.1.0.tar.gz
git clone --depth=1 https://github.com/raspberrypi/linux

echo -e ${Yellow}"Extracting source..."${Reset}
tar xf binutils-2.31.tar.bz2
tar xf glibc-2.28.tar.bz2
tar xf gcc-8.3.0.tar.gz
tar xf gcc-10.1.0.tar.gz
rm *.tar.*

echo -e ${Yellow}"Getting GCC prerequisites..."${Reset}
cd gcc-8.3.0
contrib/download_prerequisites
rm *.tar.*
cd ../gcc-10.1.0
contrib/download_prerequisites
rm *.tar.*
cd ..

echo -e ${Yellow}"Creating cross compiler dir..."${Reset}
cd ${Destination}/gcc_all
sudo mkdir -p ${Destination}
sudo chown $USER ${Destination}
export PATH=${Destination}/bin:$PATH

echo -e ${Yellow}"Copying kernel headers..."${Reset}
cd ${Destination}/gcc_all
cd linux
KERNEL=kernel7l
eval 'KERNEL=kernel7l'
make ARCH=arm INSTALL_HDR_PATH=${Destination}/arm-linux-gnueabihf headers_install

echo -e ${Yellow}"Building Binutils..."${Reset}
cd ${Destination}/gcc_all
mkdir build-binutils && cd build-binutils
../binutils-2.31/configure --prefix=${Destination} --target=arm-linux-gnueabihf --with-arch=armv8-a --with-fpu=crypto-neon-fp-armv8 --with-float=hard --disable-multilib
make -j${CORES} -s
make install

echo -e ${Yellow}"Building first part of GCC..."${Reset}
cd ${Destination}/gcc_all
mkdir build-gcc && cd build-gcc
../gcc-8.3.0/configure --prefix=${Destination} --target=arm-linux-gnueabihf --enable-languages=c,c++,fortran --with-arch=armv8-a --with-fpu=crypto-neon-fp-armv8 --with-float=hard --disable-multilib
make -j${CORES} -s all-gcc
make install-gcc

echo -e ${Yellow}"Building first part of Glibc..."${Reset}
cd ${Destination}/gcc_all
mkdir build-glibc && cd build-glibc
# A weird error occurs if this is set
eval 'LD_LIBRARY_PATH='
../glibc-2.28/configure --prefix=${Destination}/arm-linux-gnueabihf --build=$MACHTYPE --host=arm-linux-gnueabihf --target=arm-linux-gnueabihf --with-arch=armv8-a --with-fpu=crypto-neon-fp-armv8 --with-float=hard --with-headers=${Destination}/arm-linux-gnueabihf/include --disable-multilib libc_cv_forced_unwind=yes
make install-bootstrap-headers=yes install-headers
make -j${CORES} -s csu/subdir_lib
install csu/crt1.o csu/crti.o csu/crtn.o ${Destination}/arm-linux-gnueabihf/lib
arm-linux-gnueabihf-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o ${Destination}/arm-linux-gnueabihf/lib/libc.so
touch ${Destination}/arm-linux-gnueabihf/include/gnu/stubs.h

echo -e ${Yellow}"Finish building GCC..."${Reset}
cd ../build-gcc
make -j${CORES} -s all-target-libgcc
make install-target-libgcc

echo -e ${Yellow}"Finish building Glibc..."${Reset}
cd ../build-glibc
make -j${CORES} -s
make install

echo -e ${Yellow}"Finish building GCC 8.3.0..."${Reset}
cd ../build-gcc
make -j${CORES} -s
make install
cd ..

echo -e ${Yellow}"Backing up GCC 8.3.0..."${Reset}
sudo cp -r ${Destination} ${Destination}-8.3.0

echo -e ${Yellow}"Updating asan_linux.cpp..."${Reset}
cd ${Destination}/gcc_all
sed -i.back '66i #ifndef PATH_MAX' gcc-10.1.0/libsanitizer/asan/asan_linux.cpp
sed -i.back '67i #define PATH_MAX 4096' gcc-10.1.0/libsanitizer/asan/asan_linux.cpp
sed -i.back '68i #endif' gcc-10.1.0/libsanitizer/asan/asan_linux.cpp

echo -e ${Yellow}"Building GCC 10.1.0..."${Reset}
cd ${Destination}/gcc_all
mkdir build-gcc10 && cd build-gcc10
../gcc-10.1.0/configure --prefix=${Destination} --target=arm-linux-gnueabihf --enable-languages=c,c++,fortran --with-arch=armv8-a --with-fpu=crypto-neon-fp-armv8 --with-float=hard --disable-multilib
make -j${CORES} -s
make install

echo -e ${Yellow}"Cross compiling GCC 10.1.0..."${Reset}
sudo mkdir -p /opt/gcc-10.1.0
sudo chown $USER /opt/gcc-10.1.0
cd ${Destination}/gcc_all
mkdir build-native-gcc10 && cd build-native-gcc10
../gcc-10.1.0/configure --prefix=/opt/gcc-10.1.0 --build=$MACHTYPE --host=arm-linux-gnueabihf --target=arm-linux-gnueabihf --enable-languages=c,c++,fortran --with-arch=armv8-a --with-fpu=crypto-neon-fp-armv8 --with-float=hard --disable-multilib --program-suffix=-10.1
make -j${CORES} -s
make install-strip

echo "export PATH=${Destination}/bin:"'$PATH' >> ~/.bashrc
source ~/.bashrc

echo -e ${Yellow}"Cleaning up..."${Reset}
cd ${Destination}
rm -rf gcc_all

cd /opt
tar -cjvf ${Destination}/gcc-10.1.0-armhf-raspbian.tar.bz2 gcc-10.1.0
cd ~

scp gcc-10.1.0-armhf-raspbian.tar.bz2 pi@${PI_IP}:~
cd ~/CrossCompiler
scp CrossCompilerPI.sh pi@${PI_IP}:~

ssh pi@${PI_IP} "~/CrossCompilerPI.sh"

ssh pi@${PI_IP} "mkdir /home/pi/CompilerTests"

scp if_test.cpp pi@${PI_IP}:~/CompilerTests
scp fs_test.cpp pi@${PI_IP}:~/CompilerTests

scp PIBuildTestIf.sh pi@${PI_IP}:~/CompilerTests
scp PIBuildTestFS.sh pi@${PI_IP}:~/CompilerTests

echo -e ${Yellow}"Finished building Cross Compiler"${Reset}
echo -e ${Yellow}"To verify if the compiler works go to ~/CompilerTests on the pi"${Reset}

#ssh pi@${PI_IP} "cd ~/CompilerTests && g++-10.1 -std=c++17 -Wall -pedantic if_test.cpp -o if_test && ./if_test"
#ssh pi@${PI_IP} "cd ~/CompilerTests && g++-10.1 -std=c++17 -Wall -pedantic fs_test.cpp -o fs_test && ./fs_test"