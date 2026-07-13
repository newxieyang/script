#!/bin/bash
# ================================================
# g++  运行G6demo
# ================================================

g++ -std=c++11 -pthread ./Test.cpp  -o TestG6SDK  -Wl,-rpath,/data/resipG6SDK libusb-1.0.so libFAP60.so libopencv_world.so
