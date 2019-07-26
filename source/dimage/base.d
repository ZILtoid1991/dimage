/*
 * dimage - base.d
 * by Laszlo Szeremi
 *
 * Copyright under Boost Software License.
 */

module dimage.base;

import std.bitmanip;
import std.range : InputRange;

import dimage.util;

import vfile;
//import std.stdio;

/**
 * Interface for image orientation for files that support them.
 */
/+public interface ImageOrientation{
	public @property bool rightHandOrientation() inout;
	public @property bool topSideOrientation() inout;
	public void flipVertical();
	public void flipHorizontal();
}+/
/**
 * Interface for accessing metadata within images.
 * Any metadata that's not supported should return null.
 */
public interface ImageMetadata{
	public string getID() @safe;
	public string getAuthor() @safe;
	public string getComment() @safe;
	public string getJobName() @safe;
	public string getSoftwareInfo() @safe;
	public string getSoftwareVersion() @safe;
	public void setID(string val) @safe;
	public void setAuthor(string val) @safe;
	public void setComment(string val) @safe;
	public void setJobName(string val) @safe;
	public void setSoftwareInfo(string val) @safe;
	public void setSoftwareVersion(string val) @safe;
}
/**
 * All image classes should be derived from this base.
 * Implements some basic functionality, such as reading and writing pixels, basic data storage, and basic information.
 * Pixeldata should be stored decompressed, but indexing should be preserved on loading with the opinion of upconverting
 * to truecolor.
 */
abstract class Image{
	protected static const ubyte[2] pixelOrder4BitLE = [0xF0, 0x0F];
	protected static const ubyte[2] pixelOrder4BitBE = [0x0F, 0xF0];
	protected static const ubyte[2] pixelShift4BitLE = [0x04, 0x00];
	protected static const ubyte[2] pixelShift4BitBE = [0x00, 0x04];
	protected static const ubyte[4] pixelOrder2BitLE = [0b1100_0000, 0b0011_0000, 0b0000_1100, 0b0000_0011];
	protected static const ubyte[4] pixelOrder2BitBE = [0b0000_0011, 0b0000_1100, 0b0011_0000, 0b1100_0000];
	protected static const ubyte[4] pixelShift2BitLE = [0x06, 0x04, 0x02, 0x00];
	protected static const ubyte[4] pixelShift2BitBE = [0x00, 0x02, 0x04, 0x06];
	protected static const ubyte[8] pixelOrder1BitLE = [0b1000_0000, 0b0100_0000, 0b0010_0000, 0b0001_0000,
			0b0000_1000, 0b0000_0100, 0b0000_0010, 0b0000_0001];
	protected static const ubyte[8] pixelOrder1BitBE = [0b0000_0001, 0b0000_0010, 0b0000_0100, 0b0000_1000,
			0b0001_0000, 0b0010_0000, 0b0100_0000, 0b1000_0000];
	protected static const ubyte[8] pixelShift1BitLE = [0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 0x00];
	protected static const ubyte[8] pixelShift1BitBE = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07];
	/**
	 * Can be used for foreach through all palette indicles.
	 * Might replace the old method of safe accessing the palette.
	 */
	//struct PaletteRange {
	class PaletteRange : InputRange!Pixel32BitARGB {
		protected size_t 		pos;		///Indicates the current position in the palette
		protected size_t		paletteBitdepth;	///Bitdepth of the palette's indicles
		protected PixelFormat	format;		///Format of the palette
		protected ubyte[]		_palette;	///The source that is being read
		///CTOR
		this (size_t paletteBitdepth, PixelFormat format, ubyte[] _palette) pure @safe @nogc nothrow {
			this.paletteBitdepth = paletteBitdepth;
			this.format = format;
			this._palette = _palette;
		}
		///Returns the current element
    	@property Pixel32BitARGB front() pure @safe {
			const size_t offset = pos * (paletteBitdepth / 8);
			ubyte[] colorInput = _palette[offset..offset + (paletteBitdepth / 8)];
			Pixel32BitARGB colorOutput;
			switch (format) {
				case PixelFormat.ARGB8888, PixelFormat.XRGB8888:
					colorOutput = reinterpretGet!Pixel32BitARGB(colorInput);
					break;
				case PixelFormat.RGBA8888, PixelFormat.RGBX8888:
					colorOutput = Pixel32BitARGB(reinterpretGet!Pixel32BitRGBA(colorInput));
					break;
				case PixelFormat.RGBA5551, PixelFormat.RGBX5551:
					colorOutput = Pixel32BitARGB(reinterpretGet!PixelRGBA5551(colorInput));
					break;
				case PixelFormat.RGB565:
					colorOutput = Pixel32BitARGB(reinterpretGet!PixelRGB565(colorInput));
					break;
				case PixelFormat.RGB888:
					colorOutput = Pixel32BitARGB(reinterpretGet!Pixel24Bit(colorInput));
					break;
				default:
					throw new ImageFormatException("Unknown format");
			}
			return colorOutput;
		}
    	///Returns the first element and increases the position by one
    	Pixel32BitARGB moveFront() pure @safe {
			Pixel32BitARGB colorOutput = front;
			popFront;
			return colorOutput;
		}
    	///Increases the index by one if the end hasn't been reached.
    	void popFront() pure @safe @nogc nothrow {
			if (_palette.length != pos * (paletteBitdepth / 8)) pos++;
		}
    	///Returns true if the end has been reached.
    	@property bool empty() pure @safe @nogc nothrow {
			return _palette.length == pos * (paletteBitdepth / 8);
		}
    	///Used for random access.
    	Pixel32BitARGB opIndex(size_t index) pure @safe {
			const size_t offset = index * (paletteBitdepth / 8);
			ubyte[] colorInput = _palette[offset..offset + (paletteBitdepth / 8)];
			Pixel32BitARGB colorOutput;
			switch (format) {
				case PixelFormat.ARGB8888, PixelFormat.XRGB8888:
					colorOutput = reinterpretGet!Pixel32BitARGB(colorInput);
					break;
				case PixelFormat.RGBA8888, PixelFormat.RGBX8888:
					colorOutput = Pixel32BitARGB(reinterpretGet!Pixel32BitRGBA(colorInput));
					break;
				case PixelFormat.RGBA5551, PixelFormat.RGBX5551:
					colorOutput = Pixel32BitARGB(reinterpretGet!PixelRGBA5551(colorInput));
					break;
				case PixelFormat.RGB565:
					colorOutput = Pixel32BitARGB(reinterpretGet!PixelRGB565(colorInput));
					break;
				case PixelFormat.RGB888:
					colorOutput = Pixel32BitARGB(reinterpretGet!Pixel24Bit(colorInput));
					break;
				default:
					throw new ImageFormatException("Unknown format");
			}
			return colorOutput;
		}
    	///Returns the length of the palette
    	@property size_t length() pure @safe @nogc nothrow {
			return _palette.length / (paletteBitdepth / 8);
		}
    	///
    	alias opDollar = length;
		/**`foreach` iteration uses opApply, since one delegate call per loop
     	 * iteration is faster than three virtual function calls.
     	 */
    	int opApply(scope int delegate(Pixel32BitARGB) dlg){
			if (empty) return 0;
			else {
				return (dlg(moveFront));
			}
		}

    	/// Ditto
    	int opApply(scope int delegate(size_t, Pixel32BitARGB) dlg){
			if (empty) return 0;
			else {
				return (dlg(pos, moveFront));
			}
		}
	}
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
	
	abstract uint width() @nogc @safe @property const pure;
	abstract uint height() @nogc @safe @property const pure;
	abstract bool isIndexed() @nogc @safe @property const pure;
	abstract ubyte getBitdepth() @nogc @safe @property const pure;
	abstract ubyte getPaletteBitdepth() @nogc @safe @property const pure;
	abstract uint getPixelFormat() @nogc @safe @property const pure;
	abstract uint getPalettePixelFormat() @nogc @safe @property const pure;
	/**
	 * Returns a palette range, which can be used to read the palette.
	 */
	public PaletteRange palette() @safe @property pure {
		return PaletteRange(getPaletteBitdepth, cast(PixelFormat)getPalettePixelFormat, paletteData);
	}
	/**
	 * Returns the pixel order for bitdepths less than 8. Almost excusively used for indexed bitmaps.
	 * Returns null if ordering not needed.
	 */
	public ubyte[] getPixelOrder() @safe @property const pure {
		return [];
	}
	/**
	 * Returns which pixel how much needs to be shifted right after a byteread.
	 */
	public ubyte[] getPixelOrderBitshift() @safe @property const pure {
		return [];
	}
	/**
	 * Reads a single 32bit pixel. If the image is indexed, a color lookup will be done.
	 */
	public Pixel32Bit readPixel(uint x, uint y) @safe pure {
		if(x >= width || y >= height || x < 0 || y < 0){
			throw new ImageBoundsException("Image is being read out of bounds");
		}
		if(isIndexed){
			const ushort index = readPixelIndex!ushort(x, y);
			return readPalette(index);
		}else{
			final switch(getBitdepth){
				case 8:
					const ubyte data = imageData[x + y * width];
					return Pixel32Bit(data, data, data, 0xFF);
				case 16:
					PixelRGBA5551 data = reinterpretCast!PixelRGBA5551(imageData)[x + y * width];
					return Pixel32Bit(data);
				case 24:
					Pixel24Bit data = reinterpretCast!Pixel24Bit(imageData)[x + y * width];
					return Pixel32Bit(data);
				case 32:
					Pixel32Bit data = reinterpretCast!Pixel32Bit(imageData)[x + y * width];
					return data;
			}
		}
	}
	/**
	 * Reads the given type of pixel from the image.
	 * Throws an ImageFormatException, if the pixel does not match the requested format.
	 */
	public T readPixel(T)(uint x, uint y) @safe pure {
		if(x >= width || y >= height || x < 0 || y < 0){
			throw new ImageBoundsException("Image is being read out of bounds");
		}
		if(isIndexed){
			const ushort index = readPixelIndex!ushort(x, y);
			return readPalette!(T)(index);
		}else{
			if(T.sizeof * 8 != getBitdepth){
				throw new ImageFormatException("Requested format is invalid");
			}
			T data = reinterpretCast!T(imageData)[x + y * width];
			return data;
		}
	}
	/**
	 * Reads an index, if the image isn't indexed throws an ImageFormatException.
	 */
	public T readPixelIndex(T = ubyte)(uint x, uint y) @safe pure
			if(T.stringof == ushort.stringof || T.stringof == ubyte.stringof) {
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
				ubyte data = imageData[offset >> shift];
				const ubyte currentPO = pixelorder[offset & mod];
				data &= currentPO;
				data >>= getPixelOrderBitshift()[offset & mod];
				return data;
			}
		}else static if(T.stringof == ushort.stringof){
			if(getBitdepth == 16){
				return reinterpretCast!T(imageData)[x + y * width];
			}else if(getBitdepth == 8){
				return imageData[x + y * width];
			}else{
				const ubyte[] pixelorder = getPixelOrder, bitshift = getPixelOrderBitshift;
				const size_t offset = (x + y * width);
				byte data = imageData[offset >> shift];
				const ubyte currentPO = pixelorder[offset & mod];
				data &= currentPO;
				data >>= bitshift[offset & mod];
				return data;
			}
		}else static assert(0, "Use either ubyte or ushort!");
	}
	/**
	 * Looks up the index on the palette, then returns the color value as a 32 bit value.
	 */
	public Pixel32Bit readPalette(ushort index) @safe pure {
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
				PixelRGBA5551 data = reinterpretCast!PixelRGBA5551(paletteData)[index];
				return Pixel32Bit(data);
			case 24:
				if(index * 3 > paletteData.length)
					throw new PaletteBoundsException("Palette index is too high!");
				Pixel24Bit data = reinterpretCast!Pixel24Bit(paletteData)[index];
				return Pixel32Bit(data);
			case 32:
				if(index<<2 > paletteData.length)
					throw new PaletteBoundsException("Palette index is too high!");
				Pixel32Bit data = reinterpretCast!Pixel32Bit(paletteData)[index];
				return data;
		}
	}
	/**
	 * Looks up the index on the palette, then returns the color value in the requested format.
	 */
	public T readPalette(T)(ushort index) @safe pure {
		if(!isIndexed)
			throw new ImageFormatException("Image isn't indexed!");
		if(T.sizeof * 8 != getPaletteBitdepth)
			throw new ImageFormatException("Palette format mismatch!");
		if(paletteData.length / T.sizeof < index)
			throw new PaletteBoundsException("Palette index is too high!");
		T data = reinterpretCast!T(paletteData)[index];
		return data;
	}
	/**
	 * Writes a single pixel.
	 * ubyte: most indexed formats.
	 * ushort: all 16bit indexed formats.
	 * Any other pixel structs are used for direct color.
	 */
	public T writePixel(T)(uint x, uint y, T pixel) @safe pure {
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
				return reinterpretCast!T(imageData)[x + (y * width)] = pixel;
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
			T[] pixels = reinterpretCast!T(imageData);
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
	public ubyte[] getImageData() @nogc @safe nothrow pure {
		return imageData;
	}
	/**
	 * Returns the raw palette data.
	 */
	public ubyte[] getPaletteData() @nogc @safe nothrow pure {
		return paletteData;
	}
	/**
	 * Flips the image on the vertical axis. Useful to set images to the correct top-left screen origin point.
	 */
	public void flipVertical() @safe pure {
		import std.algorithm.mutation : swapRanges;
		//header.topOrigin = !header.topOrigin;
		const size_t workLength = (width * getBitdepth)>>3;
		for(int y ; y < height>>1 ; y++){
			const int rev = height - y;
			swapRanges(imageData[workLength * y..workLength * (y + 1)], imageData[workLength * (rev - 1)..workLength * rev]);
		}
	}
	/**
	 * Flips the image on the vertical axis. Useful to set images to the correct top-left screen origin point.
	 */
	public void flipHorizontal() @safe pure {
		if(isIndexed){
			if(getBitdepth == 16){
				for(int y ; y < height ; y++){
					for(int x ; x < width>>1 ; x++){
						const int x0 = width - x;
						const ushort temp = readPixelIndex!(ushort)(x, y);
						writePixel!(ushort)(x, y, readPixelIndex!(ushort)(x0, y));
						writePixel!(ushort)(x0, y, temp);
					}
				}
			}else{
				for(int y ; y < height ; y++){
					for(int x ; x < width>>1 ; x++){
						const int x0 = width - x;
						const ubyte temp = readPixelIndex!(ubyte)(x, y);
						writePixel!(ubyte)(x, y, readPixelIndex!(ubyte)(x0, y));
						writePixel!(ubyte)(x0, y, temp);
					}
				}
			}
		}else{
			final switch(getBitdepth){
				case 8:
					for(int y ; y < height ; y++){
						for(int x ; x < width>>1 ; x++){
							const int x0 = width - x;
							const ubyte temp = readPixel!(ubyte)(x, y);
							writePixel!(ubyte)(x, y, readPixel!(ubyte)(x0, y));
							writePixel!(ubyte)(x0, y, temp);
						}
					}
					break;
				case 16:
					for(int y ; y < height ; y++){
						for(int x ; x < width>>1 ; x++){
							const int x0 = width - x;
							const ushort temp = readPixel!(ushort)(x, y);
							writePixel!(ushort)(x, y, readPixel!(ushort)(x0, y));
							writePixel!(ushort)(x0, y, temp);
						}
					}
					break;
				case 24:
					for(int y ; y < height ; y++){
						for(int x ; x < width>>1 ; x++){
							const int x0 = width - x;
							const Pixel24Bit temp = readPixel!(Pixel24Bit)(x, y);
							writePixel!(Pixel24Bit)(x, y, readPixel!(Pixel24Bit)(x0, y));
							writePixel!(Pixel24Bit)(x0, y, temp);
						}
					}
					break;
				case 32:
					for(int y ; y < height ; y++){
						for(int x ; x < width>>1 ; x++){
							const int x0 = width - x;
							const Pixel32Bit temp = readPixel!(Pixel32Bit)(x, y);
							writePixel!(Pixel32Bit)(x, y, readPixel!(Pixel32Bit)(x0, y));
							writePixel!(Pixel32Bit)(x0, y, temp);
						}
					}
					break;
			}
		}
	}
}

alias Pixel32Bit = Pixel32BitARGB;

/**
 * Standard 32 bit pixel representation.
 */
struct Pixel32BitARGB {
    union{
        ubyte[4] bytes;     /// BGRA
        uint base;          /// Direct address
    }
	///Red
    @safe @nogc @property pure ref auto r() inout { return bytes[2]; }
	///Green
    @safe @nogc @property pure ref auto g() inout { return bytes[1]; }
	///Blue
    @safe @nogc @property pure ref auto b() inout { return bytes[0]; }
	///Alpha
    @safe @nogc @property pure ref auto a() inout { return bytes[3]; }
	///Creates a standard pixel representation out from a 4 element array
    this(ubyte[4] bytes) @safe @nogc pure{
        this.bytes = bytes;
    }
	///Creates a standard pixel representation out from 4 separate values
    this(ubyte r, ubyte g, ubyte b, ubyte a) @safe @nogc pure {
        bytes[0] = b;
        bytes[1] = g;
        bytes[2] = r;
        bytes[3] = a;
    }
	///Creates a standard pixel representation out of an RGBA5551 value
    this(PixelRGBA5551 p) @safe @nogc pure {
        bytes[0] = cast(ubyte)(p.b<<3 | p.b>>2);
        bytes[1] = cast(ubyte)(p.g<<3 | p.g>>2);
        bytes[2] = cast(ubyte)(p.r<<3 | p.r>>2);
        bytes[3] = p.a ? 0xFF : 0x00;
    }
	///Creates a standard pixel representation out of an RGB565 value
	this(PixelRGB565 p) @safe @nogc pure {
        bytes[0] = cast(ubyte)(p.b<<3 | p.b>>2);
        bytes[1] = cast(ubyte)(p.g<<2 | p.g>>4);
        bytes[2] = cast(ubyte)(p.r<<3 | p.r>>2);
        bytes[3] = 0xFF;
    }
	///Creates a standard pixel representation out of an RGB888 value
    this(Pixel24Bit p) @safe @nogc pure {
        bytes[0] = p.b;
        bytes[1] = p.g;
        bytes[2] = p.r;
        bytes[3] = 0xFF;
    }
	///Creates a standard  pixel representation out of an RGBA8888 value
	this(Pixel32BitRGBA p) @safe @nogc pure {
		bytes[0] = p.b;
        bytes[1] = p.g;
        bytes[2] = p.r;
        bytes[3] = p.a;
	}
}
/**
 * Standard 32 bit pixel representation.
 */
struct Pixel32BitRGBA {
    union{
        ubyte[4] bytes;     /// RGBA
        uint base;          /// Direct address
    }
	///Red
    @safe @nogc @property pure ref auto r() inout { return bytes[0]; }
	///Green
    @safe @nogc @property pure ref auto g() inout { return bytes[1]; }
	///Blue
    @safe @nogc @property pure ref auto b() inout { return bytes[2]; }
	///Alpha
    @safe @nogc @property pure ref auto a() inout { return bytes[3]; }
	///Creates a standard pixel representation out from a 4 element array
    @nogc this(ubyte[4] bytes) @safe{
        this.bytes = bytes;
    }
	///Creates a standard pixel representation out from 4 separate values
    @nogc this(ubyte r, ubyte g, ubyte b, ubyte a) @safe{
        bytes[0] = r;
        bytes[1] = g;
        bytes[2] = b;
        bytes[3] = a;
    }
	///Creates a standard pixel representation out of an RGBA5551 value
    @nogc this(PixelRGBA5551 p) @safe{
        b = cast(ubyte)(p.b<<3 | p.b>>2);
        g = cast(ubyte)(p.g<<3 | p.g>>2);
        r = cast(ubyte)(p.r<<3 | p.r>>2);
        a = p.a ? 0xFF : 0x00;
    }
	///Creates a standard pixel representation out of an RGB565 value
	@nogc this(PixelRGB565 p) @safe{
        b = cast(ubyte)(p.b<<3 | p.b>>2);
        g = cast(ubyte)(p.g<<2 | p.g>>4);
        r = cast(ubyte)(p.r<<3 | p.r>>2);
        a = 0xFF;
    }
	///Creates a standard pixel representation out of an RGB888 value
    @nogc this(Pixel24Bit p) @safe{
        b = p.b;
        g = p.g;
        r = p.r;
        a = 0xFF;
    }
}
/**
 * For monochrome images with a single channel
 */
struct PixelYA88{
	union{
		ushort		base;		/// direct access
		ubyte[2]	channels;	/// individual access
	}
	/// luminance
	@safe @nogc @property pure ref auto y() inout { return channels[0]; }
	/// alpha
    @safe @nogc @property pure ref auto a() inout { return channels[1]; }
}
/**
 * 16 Bit colorspace with a single bit alpha. This is should be used with RGBX5551 with channel a ignored
 */
struct PixelRGBA5551{
	union{
		ushort base;			/// direct access
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
		ushort base;			/// direct access
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
    ubyte[3] bytes;				///individual access
	///red
    @safe @nogc @property pure ref auto r() inout { return bytes[2]; }
	///green
    @safe @nogc @property pure ref auto g() inout { return bytes[1]; }
	///blue
    @safe @nogc @property pure ref auto b() inout { return bytes[0]; }
	///direct access read
	@safe @nogc @property pure uint base(){ return 0xff_00_00_00 | bytes[2] | bytes[1] | bytes[0]; }
}
/**
 * Pixel formats where its needed.
 * Undefined should be used for all indexed bitmaps, except 16 bit big endian ones, in which case a single BigEndian bit should be set high.
 * Lower 16 bits should be used for general identification, upper 16 bits are general identificators (endianness, valid alpha channel, etc).
 * 0x01 - 0x1F are reserved for 16 bit truecolor, 0x20 - 0x2F are reserved for 24 bit truecolor, 0x30 - 3F are reserved for integer grayscale,
 * 0x40 - 0x5F are reserved for 32 bit truecolor, 0xF00-0xF0F are reserved for "chunky" indexed images.
 */
enum PixelFormat : uint {
	BigEndian		=	0x00_01_00_00,		///Always little endian if bit not set
	ValidAlpha		=	0x00_02_00_00,		///If high, alpha is used
	RGBX5551		=	0x1,
	RGBA5551		=	RGBX5551 | ValidAlpha,
	RGB565			=	0x2,
	RGB888			=	0x20,
	YX88			=	0x30,
	YA88			=	YX88 | ValidAlpha,
	RGBX8888		=	0x40,
	RGBA8888		=	RGBX8888 | ValidAlpha,
	XRGB8888		=	0x41,
	ARGB8888		=	XRGB8888 | ValidAlpha,
	Indexed1Bit		=	0xF00,
	Indexed2Bit		=	0xF01,
	Indexed4Bit		=	0xF02,
	Indexed8Bit		=	0xF03,
	Indexed16Bit	=	0xF04,
	
	Undefined		=	0,
}
/+/**
 * Function pointer to set up external virtual file readers from e.g. archives if extra files need to be read.
 * If null, then the file will be read from disk instead from the same folder as the image file that needs the extra file.
 */
shared VFile delegate(string filename) getVFile @trusted;+/
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