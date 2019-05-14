# dimage
Image file handling library for D

# Supported formats and capabilities

## Common features

* Support for indexed reading and writing.
* Through VFile, you can load from memory locations (eg. compressed files)

## Truevision TARGA (tga)

* RLE compression and decompression works mostly fine, but needs further testing.
* Capable of reading and writing embedded data (developer area). (untested)
* Capable of accessing extension area and generating scanline table. (untested)
* Extra features not present in standard: less than 8 bit indexed images, scanline boundary ignorance compressing RLE at the sacrifice of easy scanline accessing.

## Portable Network Graphics (png)

* Compression and decompression through phobos' etc.c.zlib.
* Output mostly works, output is disliked by most applications due to bad chunks, the image might have some errors.
* No interlace support yet.
* Only basic functions are supported

# Planned features

* Better memory safety.

## Planned formats

* BMP
* TIFF
* GIF
* JPEG
