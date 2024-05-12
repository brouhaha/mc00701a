all: mc00701a.bin mc00701a.lst mc00701a.check

%.p %.lst: %.asm
	asl $< -o $*.p -L

%.bin: %.p
	p2bin -r '$$0000-$$0fff' $<

mc00701a.check: mc00701a.bin
	echo "8b6d5c070f6000604c9e8061e0551bde64191bf60d395bd14ddcc7458e4383ba mc00701a.bin" | sha256sum -c -

clean:
	rm -f mc00701a.bin mc00701a.p mc00701a.lst
