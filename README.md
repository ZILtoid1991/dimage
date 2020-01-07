# dimage
Image file handling library for D by László Szerémi (laszloszeremi@outlook.com, https://twitter.com/ziltoid1991, https://www.patreon.com/ShapeshiftingLizard, https://ko-fi.com/D1D45NEN).

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
* Output mostly works. Certain ancillary chunks generate bad checksums on writing, which might not be liked by certain readers.
* No interlace support yet.
* Basic processing is fully supported, unsupported chunks are stored as extra embedded data.

# Planned features

* Better memory safety.

## Planned formats

* BMP
* TIFF (requires LZW)
* GIF (requires LZW)
* JPEG (requires codec)
