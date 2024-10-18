rm -rf build
mkdir build

odin build src -out:build/logl -debug
./build/logl 2> mem_leaks.txt