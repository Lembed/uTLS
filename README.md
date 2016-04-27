
#axTLS
a highly configurable client/server TLSv1.1 SSL library designed for platforms with small memory requirements

[![axTLS](https://img.shields.io/badge/build-passing-blue.svg)]()
[![GitHub license](https://img.shields.io/badge/license-New%20BSD-blue.svg)](https://raw.githubusercontent.com/Lembed/axTLS/master/LICENSE)
[![axTLS](https://img.shields.io/badge/version-1.5.3-yellow.svg)]()
[![axTLS](https://img.shields.io/badge/TLSv-1.1-blue.svg)]()

## Compilation

All platforms require GNU make. Configuration now uses a tool called "mconf" which gives a nice way to configure options 
(similar to what is used in BusyBox and the Linux kernel).

Select your platform type, save the configuration, exit, and then type "make" again.
To play with all the various axTLS options, type:
```bash
$ make menuconfig
```
![screen](doc/makemenuconfig.png)

Save the new configuration and rebuild.

Now you can type "make" to build it
```bash
$  make
```

## License
[BSD](https://github.com/Lembed/axTLS/blob/master/LICENSE)
