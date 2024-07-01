# Authentrend Variant of Yubico PIV Tool

## Building static linked binary for macOS

```
$ cd <PROJECT_FOLDER>
$ mkdir build; cd build
$ cmake -DOPENSSL_STATIC_LINK=ON -DYKPIV_STATIC_LINK=ON ..
$ make
```
Or just run the build.sh.
```
./build.sh
```

The binary file will be generated under ```<PROJECT_FOLDER>/build/tool/```.

## Building static linked binary for Windows

```
Set-ExecutionPolicy RemoteSigned
.\build.ps1
```

The binary file will be generated under ```<PROJECT_FOLDER>\build\tool\Release```.

Check [here](https://github.com/Yubico/yubico-piv-tool/blob/master/.github/workflows/windows_build.yml
) for more details about Windows build.

Check Yubico's [README](./README) for details.

## Test script

Check [here](./resources/tests/README.md)
