pls follow below step
```
1. open shell Terminal and Enter G6SDKDemo directory
2. pls rewrite "path" in file G6SDKDemo/Test.cpp
3. exc cmd ' sudo chmod -R 777 /dev/bus/usb/ '
4. exc cmd ' cmake . ' 
5. exe cmd ' make '
6. exe cmd './TestFAP '
```

don't unzip G6SDKDemoLinux.zip on windows platform and copy the unzip file to linux


aar build libUSB

```

sudo apt-get update
sudo apt-get install autoconf automake libtool gperf

// download https://dev.gentoo.org/~blueness/eudev/

https://dev.gentoo.org/~blueness/eudev/eudev-3.2.5.tar.gz
tar -zvxf eudev-3.2.5.tar.gz 
cd eudev-3.2.5
./configure 
make
sudo make install

tar -xf libusb-1.0.26.tar 
cd libusb-1.0.26/
sudo ./autogen.sh 
sudo make
sudo make install

// copy libusb.so to testG6SDK_arm
cd testG6SDK_arm/

cmake .
make -j4
./TestG6SDK 
```
  