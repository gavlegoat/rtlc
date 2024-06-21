#include <fstream>

#include "fpng.h"
#include "image.hpp"

Image::Image(size_t w, size_t h):
    width{w},
    height{h},
    pixels{std::vector<Color>(w * h)}
{}

uint8_t convert(double val) {
    return std::max(0, std::min(255, (int) val));
}

void Image::write(std::string filename) {
    std::vector<uint8_t> png_file;
    uint8_t pix[this->width * this->height * 3];
    for (size_t i = 0; i < width; i++) {
        for (size_t j = 0; j < height; j++) {
            pix[j * width * 3 + i * 3    ] = convert(pixels[j * width + i].red);
            pix[j * width * 3 + i * 3 + 1] = convert(pixels[j * width + i].green);
            pix[j * width * 3 + i * 3 + 2] = convert(pixels[j * width + i].blue);
        }
    }
    bool res = fpng::fpng_encode_image_to_memory(pix, width, height, 3, png_file);
    if (!res) {
        throw std::runtime_error("Failed to encode PNG file");
    }

    std::ofstream file(filename, std::ios_base::binary | std::ios_base::out);
    file.write((char*) png_file.data(), png_file.size());
}
