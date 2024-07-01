
# Install prerequisites for x64 architecture
# vcpkg install openssl:x64-windows
# vcpkg install getopt:x64-windows
# vcpkg install check:x64-windows
# vcpkg install zlib:x64-windows
# vcpkg install check:x64-windows-static

$env:Path ="C:\dev\vcpkg\packages\openssl_x64-windows;$env:Path"
$env:include ="C:\dev\vcpkg\packages\openssl_x64-windows/include;$env:include"
$env:OPENSSL_ROOT_DIR ="C:\dev\vcpkg\packages\openssl_x64-windows"

rm -r build; mkdir build; cd build
cmake -A x64 -DCMAKE_BUILD_TYPE=Release -DVERBOSE_CMAKE=ON -DBACKEND=winscard -DGETOPT_LIB_DIR=C:/dev/vcpkg/packages/getopt-win32_x64-windows/lib -DGETOPT_INCLUDE_DIR=C:/dev/vcpkg/packages/getopt-win32_x64-windows/include -DCHECK_PATH=C:/dev/vcpkg/packages/check_x64-windows-static -DZLIB_LIB_DIR=C:/dev/vcpkg/packages/zlib_x64-windows/lib -DZLIB_INCL_DIR=C:/dev/vcpkg/packages/zlib_x64-windows/include -DOPENSSL_STATIC_LINK=ON -DYKPIV_STATIC_LINK=ON ..
cmake --build . -v --config=Release
