#include <iostream>

#include "fpng.h"
#include "scene.hpp"
#include "image.hpp"

int main(int argc, char* argv[]) {
    if (argc != 3) {
        std::cout << "Usage: ./trace <scene-file> <output-file>" << std::endl;
        return 0;
    }
    Scene scene(argv[1]);

    fpng::fpng_init();

    Image img(scene.pixel_width, scene.pixel_height);
    for (size_t i = 0; i < scene.pixel_width; i++) {
        for (size_t j = 0; j < scene.pixel_height; j++) {
            img(i, j) = scene.compute_pixel_color(i, j);
        }
    }

    img.write(argv[2]);
}
