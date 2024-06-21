OBJS = scenes.o vectors.o shapes.o
FLAGS = -g

trace: main.f90 $(OBJS)
	gfortran $(FLAGS) -o trace main.f90 $(OBJS) -I/opt/homebrew/include -L/opt/homebrew/lib -ljsonfortran

vectors.o: vectors.f90
	gfortran $(FLAGS) -c vectors.f90

shapes.o: shapes.f90 vectors.o
	gfortran $(FLAGS) -c shapes.f90

scenes.o: scenes.f90 shapes.o vectors.o
	gfortran $(FLAGS) -c scenes.f90

.PHONY: clean

clean:
	rm trace *.mod *.o
