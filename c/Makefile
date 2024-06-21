CC = gcc
FLAGS = -Wall -Wextra -Werror -O3

OBJS = json.o libattopng.o shapes.o types.o

trace: $(OBJS) main.c
	$(CC) $(FLAGS) -o trace main.c $(OBJS)

json.o: json.c json.h
	$(CC) $(FLAGS) -c json.c

libattopng.o: libattopng.c libattopng.h
	$(CC) $(FLAGS) -c libattopng.c

shapes.o: shapes.c shapes.h types.h
	$(CC) $(FLAGS) -c shapes.c

types.o: types.c types.h
	$(CC) $(FLAGS) -c types.c

.PHONY: clean

clean:
	rm $(OBJS) trace
