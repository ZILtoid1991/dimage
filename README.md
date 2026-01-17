**Notice: Project moved to the following link:** https://codeberg.org/ZILtoid1991/dimage

# dimage
Image file handling library for D by László Szerémi (laszloszeremi@outlook.com, https://twitter.com/ziltoid1991, 
https://www.patreon.com/ShapeshiftingLizard, https://ko-fi.com/D1D45NEN).

# Supported formats and capabilities

## Common features

* Support for indexed reading and writing.
* Through VFile, you can load from memory locations (eg. compressed files)

## Truevision TARGA (tga)

* RLE compression and decompression works mostly fine, but needs further testing.
* Capable of reading and writing embedded data (developer area). (untested)
* Capable of accessing extension area and generating scanline table. (untested)
* Extra features not present in standard: less than 8 bit indexed images, scanline boundary ignorance compressing RLE at the 
sacrifice of easy scanline accessing.

## Portable Network Graphics (png)

* Compression and decompression through phobos' etc.c.zlib.
* Output mostly works. Certain ancillary chunks generate bad checksums on writing, which might not be liked by certain readers.
* No interlace support yet.
* Basic processing is fully supported, unsupported chunks are stored as extra embedded data. Background indexes, transparencies 
(including indexed) are supported. Embedded text support, and APNG extension support will be added.
* Most common formats are supported up to 16 bits.
* Filtering and defiltering works. Note that there might be a few bugs with the filters (please send me examples if you encounter
one), and currently there's no automatic filtering.

## Windows Bitmap (bmp)

* All versions are supported with some caveats (e.g. 1.x has no built in palette support, so normal reads are problematic).
* Currently truecolor images are only supported with up to 8 bit per channel.

# Usage

## Loading images

The following example shows how to load a TGA image file:

```d
File source = File("example.tga");
Image texture = TGA.load(source);
```

The file can be replaced with any other structure that uses the same functions, such as `VFile`, which enables it to load files
from memory e.g. after loading from a package. Be noted that while there may be size reduction in compressing already compressed
image formats, this will have diminishing results in space saved (and might end up with bigger files), and will slow down access
speeds.

## Accessing data

Most images should have `imageData` return the imagedata as the interface `IImageData`, which have some basic function that 
could be sufficient in certain cases, especially when data must be handled by some other library.

```d
ARGB8888 backgroundColor = texture.read(0,0);
assert(texture.getPixelFormat == PixelFormat.ARGB8888, "Unsupported pixel format!");
myFancyTextureLoader(texture.raw.ptr, texture.width, texture.height);
```

`IImageData` can be casted to different other types, which enable more operations. However one must be careful with the types,
which can be checked by using the property `pixelFormat`.

```d
if (indexedImageData.pixelformat == PixelFormat.Indexed)
{
    IndexedImageData!ubyte iif = cast(IndexedImageData!ubyte)indexedImageData;
    for (int y ; y < iif.height; ; y++)
    {
        for (int x ; x < iif.width ; x++)
        {
            iif[x, y] = 0;
        }
    }
}
```

## Palettes

If an image format supports palettes, then it can be accessed with the `palette` property.

The `IPalette` interface provides the `length` property and the `read(size_t pos)` function, which can be used to create a
for loop:

```d
IPalette pal = indexedImage.palette;
for(size_t i ; i < pal.length ; i++) 
{
    //Do things that require reading the palette.
}
```

A more complex method is casting the `IPalette` interface into a more exact type, which gives access to the original pixel format,
an `opIndex` function, and basic range functionality:

```d
Palette!RGBA5551 pal = cast(Palette!RGBA5551)indexedImage.palette;
foreach(colorIndex ; pal)
{
    //Do things with the palette
}
```

# Planned features

* Better memory safety. (Partly done)
* Use of floating points for conversion. (Mostly done)

## Planned formats

* MNG
* TIFF (requires LZW and JPEG codec)
* GIF (requires LZW)
* JPEG (requires codec)
