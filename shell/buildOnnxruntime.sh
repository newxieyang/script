 # 支持16kb对齐 armeabi-v7a
 # onnxruntime源码在OXix64虚拟机上
 
 ./build.sh --android --android_sdk_path /home/oxi/Android/Sdk --android_ndk_path /home/oxi/Android/Sdk/ndk/28.2.13676358 --android_abi armeabi-v7a --android_api 35 --config Release --build_shared_lib --parallel --build_dir android/armeabi-v7a --cmake_extra_defines CMAKE_SHARED_LINKER_FLAGS="-Wl,-z,max-page-size=16384" --cmake_extra_defines BUILD_TESTING=OFF --cmake_extra_defines BUILD_PERF_TESTS=OFF --cmake_generator Ninja