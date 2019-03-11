/*
 * dimage - base.d
 * by Laszlo Szeremi
 *
 * Copyright under Boost Software License.
 */

module dimage.base;

import std.bitmanip;

/**
 * Interface for image orientation for files that support them.
 */
public interface ImageOrientation{
	public @property bool rightHandOrientation() inout;
	public @property bool topSideOrientation() inout;
	public void flipVertical();
	public void flipHorizontal();
}
/**
 * Interface for accessing metadata within images.
 * Any metadata that's not supported should return null.
 */
public interface ImageMetadata{
	public string getID();
	public string getAuthor();
	public string getComment();
	public string getJobName();
	public string getSoftwareInfo();
	public string getSoftwareVersion();
	public void setID(string val);
	public void setAuthor(string val);
	public void setComment(string val);
	public void setJobName(string val);
	public void setSoftwareInfo(string val);
	public void setSoftwareVersion(string val);
}
/**
 * All image classes should be derived from this base.
 * Implements some basic functionality, such as reading and writing pixels, basic data storage, and basic information.
 * Pixeldata should be stored decompressed, but indexing should be preserved on loading with the opinion of upconverting
 * to truecolor.
 */
abstract class Image{
	protected static const ubyte[2] pixelOrder4BitBE = [0xF0, 0x0F];
	protected static const ubyte[2] pixelOrder4BitLE = [0x0F, 0xF0];
	protected static const ubyte[2] pixelShift4BitBE = [0x04, 0x00];
	protected static const ubyte[2] pixelShift4BitLE = [0x00, 0x04];
	protected static const ubyte[4] pixelOrder2BitBE = [0b1100_0000, 0b0011_0000, 0b0000_1100, 0b0000_0011];
	protected static const ubyte[4] pixelOrder2BitLE = [0b0000_0011, 0b0000_1100, 0b0011_0000, 0b1100_0000];
	protected static const ubyte[4] pixelShift2BitBE = [0x06, 0x04, 0x02, 0x00];
	protected static const ubyte[4] pixelShift2BitLE = [0x00, 0x02, 0x04, 0x06];
	protected static const ubyte[8] pixelOrder1BitBE = [0b1000_0000, 0b0100_0000, 0b0010_0000, 0b0001_0000,
			0b0000_1000, 0b0000_0100, 0b0000_0010, 0b0000_0001];
	protected static const ubyte[8] pixelOrder1BitLE = [0b0000_0001, 0b0000_0010, 0b0000_0100, 0b0000_1000,
			0b0001_0000, 0b0010_0000, 0b0100_0000, 0b1000_0000];
	protected static const ubyte[8] pixelShift1BitBE = [0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 0x00];
	protected static const ubyte[8] pixelShift1BitLE = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07];
	/**
	 * Raw image data. Cast the data to whatever data you need at the moment.
	 */
	protected ubyte[] imageData;
	/**
	 * Raw palette data. Null if image is not indexed.
	 */
	protected ubyte[] paletteData;

	protected ubyte mod;	///used for fast access of indexes
	protected ubyte shift;	///used for fast access of indexes
	
	abstract int width() @nogc @safe @property const pure;
	abstract int height() @nogc @safe @property const pure;
	abstract bool isIndexed() @nogc @safe @property const pure;
	abstract ubyte getBitdepth() @nogc @safe @property const pure;
	abstract ubyte getPaletteBitdepth() @nogc @safe @property const pure;
	abstract uint getPixelFormat() @nogc @safe @property const pure;
	abstract uint getPalettePixelFormat() @nogc @safe @property const pure;
	/**
	 * Returns the pixel order for bitdepths less than 8. Almost excusively used for indexed bitmaps.
	 * Returns null if ordering not needed.
	 */
	public ubyte[] getPixelOrder() @safe @property const{
		return [];
	}
	/**
	 * Returns which pixel how much needs to be shifted right after a byteread.
	 */
	public ubyte[] getPixelOrderBitshift() @safe @property const{
		return [];
	}
	/**
	 * Reads a single 32bit pixel. If the image is indexed, a color lookup will be done.
	 */
	public Pixel32Bit readPixel(int x, int y){
		if(x >= width || y >= height || x < 0 || y < 0){
			throw new ImageBoundsException("Image is being read out of bounds");
		}
		if(isIndexed){
			ushort index = readPixelIndex!ushort(x, y);
			return readPalette(index);
		}else{
			final switch(getBitdepth){
				case 8:
					ubyte data = imageData[x + y * width];
					return Pixel32Bit(data, data, data, 0xFF);
				case 16:
					PixelRGBA5551 data = (cast(PixelRGBA5551[])(cast(void[])imageData))[x + y * width];
					return Pixel32Bit(data);
				case 24:
					Pixel24Bit data = (cast(Pixel24Bit[])(cast(void[])imageData))[x + y * width];
					return Pixel32Bit(data);
				case 32:
					Pixel32Bit data = (cast(Pixel32Bit[])(cast(void[])imageData))[x + y * width];
					return data;
			}
		}
	}
	/**
	 * Reads the given type of pixel from the image.
	 * Throws an ImageFormatException, if the pixel does not match the requested format.
	 */
	public T readPixel(T)(int x, int y){
		if(x >= width || y >= height || x < 0 || y < 0){
			throw new ImageBoundsException("Image is being read out of bounds");
		}
		if(isIndexed){
			ushort index = readPixelIndex!ushort(x, y);
			return readPalette!(T)(index);
		}else{
			if(T.sizeof * 8 != getBitdepth){
				throw new ImageFormatException("Requested format is invalid");
			}
			T data = (cast(T[])(cast(void[])imageData))[x + y * width];
			return data;
		}
	}
	/**
	 * Reads an index, if the image isn't indexed throws an ImageFormatException.
	 */
	public T readPixelIndex(T = ubyte)(int x, int y)
			if(T.stringof == ushort.stringof || T.stringof == ubyte.stringof){
		if(x >= width || y >= height || x < 0 || y < 0){
			throw new ImageBoundsException("Image is being read out of bounds!");
		}
		if(!isIndexed){
			throw new ImageFormatException("Image isn't indexed!");
		}
		static if(T.stringof == ubyte.stringof){
			if(getBitdepth == 16){
				throw new ImageFormatException("Image is in 16 bit indexed format!");
			}else if(getBitdepth == 8){
				return imageData[x + y * width];
			}else{
				const ubyte[] pixelorder = getPixelOrder;
				const size_t offset = (x + y * width);
				ubyte data = imageData[offset >> shift], currentPO = pixelorder[offset & mod];
				data &= currentPO;
				data >>= getPixelOrderBitshift()[offset & mod];
				return data;
			}
		}else static if(T.stringof == ushort.stringof){
			if(getBitdepth == 16){
				return (cast(ushort[])(cast(void[])imageData))[x + y * width];
			}else if(getBitdepth == 8){
				return imageData[x + y * width];
			}else{
				const ubyte[] pixelorder = getPixelOrder, bitshift = getPixelOrderBitshift;
				const size_t offset = (x + y * width);
				ubyte data = imageData[offset >> shift], currentPO = pixelorder[offset & mod];
				data &= currentPO;
				data >>= bitshift[offset & mod];
				return data;
			}
		}else static assert(0, "Use either ubyte or ushort!");
	}
	/**
	 * Looks up the index on the palette, then returns the color value as a 32 bit value.
	 */
	public Pixel32Bit readPalette(ushort index){
		if(!isIndexed)
			throw new ImageFormatException("Image isn't indexed!");
		final switch(getPaletteBitdepth){
			case 8:
				if(index > paletteData.length)
					throw new PaletteBoundsException("Palette index is too high!");
				const ubyte data = paletteData[index];
				return Pixel32Bit(data, data, data, 0xFF);
			case 16:
				if(index<<1 > paletteData.length)
					throw new PaletteBoundsException("Palette index is too high!");
				PixelRGBA5551 data = (cast(PixelRGBA5551[])(cast(void[])paletteData))[index];
				return Pixel32Bit(data);
			case 24:
				if(index * 3 > paletteData.length)
					throw new PaletteBoundsException("Palette index is too high!");
				Pixel24Bit data = (cast(Pixel24Bit[])(cast(void[])paletteData))[index];
				return Pixel32Bit(data);
			case 32:
				if(index<<2 > paletteData.length)
					throw new PaletteBoundsException("Palette index is too high!");
				Pixel32Bit data = (cast(Pixel32Bit[])(cast(void[])paletteData))[index];
				return data;
		}
	}
	/**
	 * Looks up the index on the palette, then returns the color value in the requested format.
	 */
	public T readPalette(T)(ushort index){
		if(!isIndexed)
			throw new ImageFormatException("Image isn't indexed!");
		if(T.sizeof * 8 != getPaletteBitdepth)
			throw new ImageFormatException("Palette format mismatch!");
		if(paletteData.length / T.sizeof < index)
			throw new PaletteBoundsException("Palette index is too high!");
		T data = (cast(T[])(cast(void[])paletteData))[index];
		return data;
	}
	/**
	 * Writes a single pixel.
	 * ubyte: most indexed formats.
	 * ushort: all 16bit indexed formats.
	 * Any other pixel structs are used for direct color.
	 */
	public T writePixel(T)(int x, int y, T pixel) if(T.stringof == ubyte.stringof || T.stringof == ushort.stringof
			|| T.stringof == PixelRGBA5551.stringof || T.stringof == PixelRGB565.stringof || 
			T.stringof == Pixel24Bit.stringof || T.stringof == Pixel32Bit.stringof){
		if(x >= width || y >= height)
			throw new ImageBoundsException("Image is being written out of bounds!");
		
		static if(T.stringof == ubyte.stringof || T.stringof == ushort.stringof){
			/*if(!isIndexed)
				throw new ImageFormatException("Image isn't indexed!");*/
			
			static if(T.stringof == ubyte.stringof)
				if(getBitdepth == 16)
					throw new ImageFormatException("Image cannot be written as 8 bit!");
			static if(T.stringof == ushort.stringof){
				if(getBitdepth <= 8)
					throw new ImageFormatException("Image cannot be written as 16 bit!");
				return (cast(ushort[])(cast(void[])imageData))[x + (y * width)] = pixel;
			}else{
				switch(getBitdepth){
					case 8 :
						return imageData[x + (y * width)] = pixel;
					default:
						const size_t offset = x + (y * width);
						size_t offsetA = offset & ((1 << getBitdepth) - 1), offsetB = offset>>1;
						if(getBitdepth == 2)
							offsetB >>= 1;
						else if (getBitdepth == 1)
							offsetB >>= 2;
						pixel <<= getPixelOrderBitshift[offsetA];
						return imageData[offsetB] = cast(ubyte)((imageData[offsetB] & !getPixelOrder[offsetB]) | pixel);
				}
			}
		}else{
			T[] pixels = cast(T[])(cast(void[])imageData);
			if(T.sizeof != getBitdepth / 8)
				throw new ImageFormatException("Image format mismatch exception");
			return pixels[x + (y * width)] = pixel;
		}
	}
	/**
	 * Writes to the palette.
	 */
	/**
	 * Returns the raw image data.
	 */
	public ubyte[] getImageData() @nogc nothrow{
		return imageData;
	}
	/**
	 * Returns the raw palette data.
	 */
	public ubyte[] getPaletteData() @nogc nothrow{
		return paletteData;
	}
}

alias Pixel32Bit = Pixel32BitARGB;

struct Pixel32BitARGB {
    union{
        ubyte[4] bytes;     /// BGRA
        uint base;          /// Direct address
    }
	///Red
    @nogc @property pure ref auto r() inout { return bytes[2]; }
	///Green
    @nogc @property pure ref auto g() inout { return bytes[1]; }
	///Blue
    @nogc @property pure ref auto b() inout { return bytes[0]; }
	///Alpha
    @nogc @property pure ref auto a() inout { return bytes[3]; }
    @nogc this(ubyte[4] bytes){
        this.bytes = bytes;
    }
    @nogc this(ubyte r, ubyte g, ubyte b, ubyte a){
        bytes[0] = b;
        bytes[1] = g;
        bytes[2] = r;
        bytes[3] = a;
    }
    @nogc this(PixelRGBA5551 p){
        bytes[0] = cast(ubyte)(p.b<<3 | p.b>>2);
        bytes[1] = cast(ubyte)(p.g<<3 | p.g>>2);
        bytes[2] = cast(ubyte)(p.r<<3 | p.r>>2);
        bytes[3] = p.a ? 0xFF : 0x00;
    }
	@nogc this(PixelRGB565 p){
        bytes[0] = cast(ubyte)(p.b<<3 | p.b>>2);
        bytes[1] = cast(ubyte)(p.g<<2 | p.g>>4);
        bytes[2] = cast(ubyte)(p.r<<3 | p.r>>2);
        bytes[3] = 0xFF;
    }
    @nogc this(Pixel24Bit p){
        bytes[0] = p.b;
        bytes[1] = p.g;
        bytes[2] = p.r;
        bytes[3] = 0xFF;
    }
}

struct Pixel32BitRGBA {
    union{
        ubyte[4] bytes;     /// RGBA
        uint base;          /// Direct address
    }
	///Red
    @nogc @property pure ref auto r() inout { return bytes[0]; }
	///Green
    @nogc @property pure ref auto g() inout { return bytes[1]; }
	///Blue
    @nogc @property pure ref auto b() inout { return bytes[2]; }
	///Alpha
    @nogc @property pure ref auto a() inout { return bytes[3]; }
    @nogc this(ubyte[4] bytes){
        this.bytes = bytes;
    }
    @nogc this(ubyte r, ubyte g, ubyte b, ubyte a){
        bytes[0] = r;
        bytes[1] = g;
        bytes[2] = b;
        bytes[3] = a;
    }
    @nogc this(PixelRGBA5551 p){
        b = cast(ubyte)(p.b<<3 | p.b>>2);
        g = cast(ubyte)(p.g<<3 | p.g>>2);
        r = cast(ubyte)(p.r<<3 | p.r>>2);
        a = p.a ? 0xFF : 0x00;
    }
	@nogc this(PixelRGB565 p){
        b = cast(ubyte)(p.b<<3 | p.b>>2);
        g = cast(ubyte)(p.g<<2 | p.g>>4);
        r = cast(ubyte)(p.r<<3 | p.r>>2);
        a = 0xFF;
    }
    @nogc this(Pixel24Bit p){
        b = p.b;
        g = p.g;
        r = p.r;
        a = 0xFF;
    }
}
struct PixelCA88{
	union{
		ushort		base;
		ubyte[2]	channels;
	}
	@nogc @property pure ref auto c() inout { return channels[0]; }
    @nogc @property pure ref auto a() inout { return channels[1]; }
}
/**
 * 16 Bit colorspace with a single bit alpha. This is should be used with RGBX5551 with channel a ignored
 */
struct PixelRGBA5551{
	union{
		ushort base;
		mixin(bitfields!(
			ubyte, "b", 5,
			ubyte, "g", 5,
			ubyte, "r", 5,
			bool, "a", 1,
		));
	}
}
/**
 * 16 Bit RGB565 colorspace with no alpha.
 */
struct PixelRGB565{
	union{
		ushort base;
		mixin(bitfields!(
			ubyte, "b", 5,
			ubyte, "g", 6,
			ubyte, "r", 5,
		));
	}
}
/**
 * 24 Bit colorspace
 */
align(1) struct Pixel24Bit {
    ubyte[3] bytes;
    @nogc @property pure ref auto r() inout { return bytes[2]; }
    @nogc @property pure ref auto g() inout { return bytes[1]; }
    @nogc @property pure ref auto b() inout { return bytes[0]; }
	@nogc @property pure uint base(){ return 0xff_00_00_00 | bytes[2] | bytes[1] | bytes[0]; }
}
/**
 * Pixel formats where its needed.
 * Undefined should be used for all indexed bitmaps, except 16 bit big endian ones, in which case a single BigEndian bit should be set high.
 * Lower 16 bits should be used for general identification, upper 16 bits are general identificators (endianness, valid alpha channel, etc).
 * 0x00 - 0x1F are reserved for 16 bit truecolor, 0x20 - 0x2F are reserved for 24 bit truecolor, 0x30 - 3F are reserved for integer grayscale,
 * 0x40 - 0x5F are reserved for 32 bit truecolor 
 */
enum PixelFormat : uint{
	BigEndian		=	0x00_01_00_00,		///Always little endian if bit not set
	ValidAlpha		=	0x00_02_00_00,		///If high, alpha is used
	RGBX5551		=	0x1,
	RGBA5551		=	RGBX5551 | ValidAlpha,
	RGB565			=	0x2,
	RGB888			=	0x20,
	CX88			=	0x30,
	CA88			=	CX88 | ValidAlpha,
	RGBX8888		=	0x40,
	RGBA8888		=	RGBX8888 | ValidAlpha,
	XRGB8888		=	0x41,
	ARGB8888		=	XRGB8888 | ValidAlpha,
	
	Undefined		=	0,
}

/**
 * Thrown if image is being read or written out of bounds.
 */
class ImageBoundsException : Exception{
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}
/**
 * Thrown if palette is being read or written out of bounds.
 */
class PaletteBoundsException : Exception{
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}
/**
 * Thrown if image format doesn't match.
 */
class ImageFormatException : Exception{
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}
/**
 * Thrown if the file has a checksum error.
 */
public class ChecksumMismatchException : Exception{
	@nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}