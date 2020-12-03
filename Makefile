
TARGET = fire.hex
ELFTARGET = fire.elf
EXTRATARGETS = fire_nodelay.hex fire_nodelay.elf
OBJECTS=fire.o fire_nodelay.o

.PHONY: clean

all: $(TARGET) $(ELFTARGET) $(EXTRATARGETS)


%.hex: %.elf
	avr-objcopy -j .text -j .data -O ihex $< $@

%.elf: %.o
	avr-ld -m avr25 -o $@ $^

%.o: %.S
	avr-gcc -g -mmcu=attiny85 -c -o $@ $< 

flash:
	avrdude -v -c usbtiny -pt85 -U flash:w:$(TARGET)

fuses:
	avrdude -v -c usbtiny -pt85 -U lfuse:w:0xe2:m -U hfuse:w:0xdf:m -U efuse:w:0xff:m

clean:
	-rm $(TARGET) $(ELFTARGET) $(EXTRATARGETS) $(OBJECTS)
