Main.class: Main.java Shape.class Sphere.class Color.class Vector.class Plane.class Scene.class
	javac -cp .:json-20240303.jar Main.java

Scene.class: Scene.java Shape.class Vector.class Color.class Collision.class
	javac Scene.java

Shape.class: Shape.java Vector.class Color.class
	javac Shape.java

Sphere.class: Sphere.java Shape.class Vector.class Color.class
	javac Sphere.java

Plane.class: Plane.java Shape.class Vector.class Color.class
	javac Plane.java

Vector.class: Vector.java
	javac Vector.java

Color.class: Color.java
	javac Color.java

Collision.class: Collision.java Shape.class
	javac Collision.java

.PHONY: clean

clean:
	rm *.class
