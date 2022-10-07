
yasm: encode.asm
	yasm -f elf64 -m amd64 -g dwarf2 encode.asm -l encode.lst
	gcc -g -no-pie -o program encode.o

gas: encode.s
	as encode.s -o encode.o --gstabs+
	ld encode.o -o encode


clean:
	rm -f *.lst *.o program encode
