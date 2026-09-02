cmake -S . -B build -G "Visual Studio 16 2019" -A x64
cmake --build build --config Release

cmake -S . -B build_x86 -G "Visual Studio 16 2019" -A Win32
cmake --build build_x86 --config Release