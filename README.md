# Atmel AVR8 GNU Toolchain Builder

We are building our own Atmel AVR8 GNU Toolchain for 64-bit Linux now because Microchip is bad about distributing binaries.

## Build Your Own

```
git clone https://bitbucket.org/profirmserv/pfs-avr8_toolchain_builder
cd pfs-avr8_toolchain_builder
vagrant up
vagrant ssh
/vagrant/avr8-toolchain-build.bash
```

When you get back from your smoke break, there should be a new tarball named something like `avr8-gnu-toolchain-3.6.1.20180428203441-pfs.linux.any.x86_64.tar.xz` in the project directory.

## Pre-Built Binaries

You can also download binaries we've built if you like:

* [avr8-gnu-toolchain-3.6.1.20180428203441-pfs.linux.any.x86_64.tar.xz](https://bitbucket.org/profirmserv/pfs-toolchain/downloads/avr8-gnu-toolchain-3.6.1.20180428203441-pfs.linux.any.x86_64.tar.xz)
