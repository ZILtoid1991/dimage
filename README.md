# dimage
Image file handling library for D

# Supported formats and capabilities

## Common features

* Support for indexed reading and writing.
* Through VFile, you can load from memory locations (eg. compressed files)

## Truevision TARGA

* RLE compression is broken, decompression works fine.
* Capable of reading and writing embedded data (developer area). (untested)
* Capable of accessing extension area and generating scanline table. (untested)
* Extra features: less than 8 bit indexed images, scanline boundary ignorance compressing RLE at the sacrifice of easy scanline accessing.

# Planned features

## Planned formats

* BMP
* PNG
* GIF
* JPEG
