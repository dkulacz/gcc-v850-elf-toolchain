# gcc-v850-elf-toolchain
GCC-based toolchain for V850/RH850

## Usage for RH850
```
v850-elf-gcc -mv850e3v5 -mloop -mrh850-abi <file>
```
## Docker
### Image
https://hub.docker.com/r/dkulacz/gcc-v850-elf-toolchain
### Usage example
```
docker run -it --rm --volume "$(pwd)":"$(pwd)" --workdir "$(pwd)" --user "$(id -u):$(id -g)" --env CC=v850-elf-gcc --env CXX=v850-elf-g++ dkulacz/gcc-v850-elf-toolchain  
```
