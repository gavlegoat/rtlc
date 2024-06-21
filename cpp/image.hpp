#pragma once

#include <vector>

#include "types.hpp"

class Image {
private:
    size_t width;
    size_t height;
    std::vector<Color> pixels;

public:
    Image(size_t, size_t);

    inline Color& operator()(size_t x, size_t y) {
        return pixels[y * width + x];
    }

    void write(std::string filename);
};
