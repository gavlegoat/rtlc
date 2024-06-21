FLAGS = -Wall -Wextra -std=c++17 -g
CC = clang++
OBJS = main.o scene.o object.o image.o fpng.o types.o

trace: $(OBJS)
	$(CC) $(FLAGS) -o trace $(OBJS)

main.o: main.cpp scene.hpp image.hpp fpng.h
	$(CC) $(FLAGS) -c main.cpp

scene.o: scene.hpp scene.cpp json.hpp types.hpp
	$(CC) $(FLAGS) -c scene.cpp

object.o: object.hpp object.cpp types.hpp
	$(CC) $(FLAGS) -c object.cpp

types.o: types.hpp types.cpp
	$(CC) $(FLAGS) -c types.cpp

image.o: image.hpp image.cpp fpng.h types.hpp
	$(CC) $(FLAGS) -c image.cpp

fpng.o: fpng.h fpng.cpp
	$(CC) $(FLAGS) -c fpng.cpp

clean:
	rm $(OBJS) trace
