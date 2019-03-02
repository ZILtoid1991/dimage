# dimage
Image file handling library for D

# Supported formats and capabilities

## Common features

* Support for indexed reading and writing.
* Through VFile, you can load from memory locations (eg. compressed files)

## Truevision TARGA (tga)

* RLE compression and decompression works mostly fine, lack of testcases.
* Capable of reading and writing embedded data (developer area). (untested)
* Capable of accessing extension area and generating scanline table. (untested)
* Extra features not present in standard: less than 8 bit indexed images, scanline boundary ignorance compressing RLE at the sacrifice of easy scanline accessing.

## Portable Network Graphics (png)

* Compression and decompression through phobos' std.zlib.
* Error with compression due to improper flushing in std.zlib.
* No interlace support yet.
* Only basic functions are supported

# Planned features

## Planned formats

* BMP
* GIF
* JPEG
