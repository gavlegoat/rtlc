LDFLAGS = -lSystem -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib
ASFLAGS = -g
OBJECTS = main.o vector.o printing.o shapes.o scene.o

trace: $(OBJECTS)
	ld $(LDFLAGS) -o trace $(OBJECTS)

%.o: %.s
	as $(ASFLAGS) -o $@ $<

.PHONY: clean

clean:
	rm $(OBJECTS) trace
