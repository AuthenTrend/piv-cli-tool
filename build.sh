#!/bin/sh

PLATFORM=$(uname)

if [ "${PLATFORM}" = "Darwin" ]; then
    HOMEBREW_PREFIX=$(brew config | grep HOMEBREW_PREFIX | awk -F':' '{print $2}' | tr -d ' ')
    #export PKG_CONFIG_PATH="${HOMEBREW_PREFIX}/opt/openssl@1.1/lib/pkgconfig"
    export PKG_CONFIG_PATH="${HOMEBREW_PREFIX}/opt/openssl@3/lib/pkgconfig"
fi

rm -rf build; mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DOPENSSL_STATIC_LINK=ON -DYKPIV_STATIC_LINK=ON .. && make

