/*
 * dimage - base.d
 * by Laszlo Szeremi
 *
 * Copyright under Boost Software License.
 */

module dimage.base;

import std.bitmanip;
import std.range : InputRange;
import std.conv : to;

import dimage.util;

import bitleveld.datatypes;

public import dimage.types;
public import dimage.exceptions;

/**
 * Interface for accessing metadata within images.
 * Any metadata that's not supported should return null.
 */
public interface ImageMetadata {
	public string getID() @safe pure;
	public string getAuthor() @safe pure;
	public string getComment() @safe pure;
	public string getJobName() @safe pure;
	public string getSoftwareInfo() @safe pure;
	public string getSoftwareVersion() @safe pure;
	public string getDescription() @safe pure;
	public string getSource() @safe pure;
	public string getCopyright() @safe pure;
	public string getCreationTimeStr() @safe pure;

	public string setID(string val) @safe pure;
	public string setAuthor(string val) @safe pure;
	public string setComment(string val) @safe pure;
	public string setJobName(string val) @safe pure;
	public string setSoftwareInfo(string val) @safe pure;
	public string setSoftwareVersion(string val) @safe pure;
	public string setDescription(string val) @safe pure;
	public string setSource(string val) @safe pure;
	public string setCopyright(string val) @safe pure;
	public string setCreationTime(string val) @safe pure;
}
/**
 * Allows to access custom-tagged textual metadata in images.
 */
public interface CustomImageMetadata : ImageMetadata {
	/**
	 * Returns the metadata with the given `id`.
	 * Returns null if not found.
	 */
	public string getMetadata(string id) @safe pure;
	/**
	 * Sets the given metadata to `val` at the given `id`, then returns the new value.
	 */
	public string setMetadata(string id, string val) @safe pure;
}
/**
 * Interface for common multi-image (eg. animation) functions.
 */
public interface MultiImage {
	///Returns which image is being set to be worked on.
	public uint getCurrentImage() @safe pure;
	///Sets which image is being set to be worked on.
	public uint setCurrentImage(uint frame) @safe pure;
	///Sets the current image to the static if available
	public void setStaticImage() @safe pure;
	///Number of images in a given multi-image.
	public uint nOfImages() @property @safe @nogc pure const;
	///Returns the frame duration in hmsec if animation for the given frame.
	///Returns 0 if not an animation.
	public uint frameTime() @property @safe @nogc pure const;
	///Returns true if the multi-image is animated
	public bool isAnimation() @property @safe @nogc pure const;
}
/**
 * Basic palette wrapper.
 */
public interface IPalette {
	///Returns the number of indexes within the palette.
	public @property size_t length() @nogc @safe pure nothrow const;
	///Returns the bitdepth of the palette.
	public @property ubyte bitDepth() @nogc @safe pure nothrow const;
	///Returns the color format of the palette.
	public @property uint paletteFormat() @nogc @safe pure nothrow const;
	///Converts the palette to the given format if supported
	public IPalette convTo(uint format) @safe;
	///Reads palette in standard indexed format
	public ARGB8888 read(size_t index) @safe pure;
	///Reads palette in standard floating point format
	public RGBA_f32 readF(size_t index) @safe pure;
	///Returns the raw data cast to ubyte
	public ubyte[] raw() @safe pure;
}
/**
 * Contains palette information.
 * Implements some range capabilities.
 */
public class Palette(T) : IPalette {
	protected T[]			data;	///Raw data
	//protected size_t		_length;///The number of items in the palette (should be less than 65536)
	protected size_t		begin, end;
	protected uint			format;
	protected ubyte			_bitDepth;
	///CTOR
	this(T[] data, uint format, ubyte bitDepth) @nogc @safe pure nothrow {
		this.data = data;
		this.format = format;
		_bitDepth = bitDepth;
		end = data.length;
	}
	///Copy CTOR
	this(Palette!T src) @nogc @safe pure nothrow {
		data = src.data;
		format = src.format;
		_bitDepth = src._bitDepth;
		end = data.length;
	}
	///Returns the number of indexes within the palette.
	public @property size_t length() @nogc @safe pure nothrow const {
		return data.length;
	}
	///Returns the bitdepth of the palette.
	public @property ubyte bitDepth() @nogc @safe pure nothrow const {
		return _bitDepth;
	}
	///Returns the color format of the palette.
	public @property uint paletteFormat() @nogc @safe pure nothrow const {
		return format;
	}
	///Converts the palette to the given format if supported.
	public IPalette convTo(uint format) @safe {
		IPalette result;
		void converter(OutputType)() @safe {
			OutputType[] array;
			array.length = data.length;
			for(int i ; i < data.length ; i++)
				array[i] = OutputType(data[i]);
			result = new Palette!OutputType(array, format, getBitDepth(format));
		}
		switch (format & ~(PixelFormat.BigEndian | PixelFormat.ValidAlpha)) {
			case PixelFormat.RGB888:
				if(format & PixelFormat.BigEndian)
					converter!(RGB888BE);
				else
					converter!(RGB888);
				break;
			case PixelFormat.RGBX8888:
				if(format & PixelFormat.BigEndian)
					converter!(RGBA8888BE);
				else
					converter!(RGBA8888);
				break;
			case PixelFormat.XRGB8888:
				if(format & PixelFormat.BigEndian)
					converter!(ARGB8888BE);
				else
					converter!(ARGB8888);
				break;
			case PixelFormat.RGB565:
				converter!(RGB565);
				break;
			case PixelFormat.RGBX5551:
				converter!(RGBA5551);
				break;
			default:
				throw new ImageFormatException("Format not supported");
		}
		return result;
	}
	///Returns the raw data as an array.
	public T[] getRawData() @nogc @safe pure nothrow {
		return data;
	}
	///Reads palette in standard format.
	public ARGB8888 read(size_t index) @safe pure {
		if (index < data.length) return ARGB8888(data[index]);
		else throw new PaletteBoundsException("Palette is being read out of bounds!");
	}
	///Reads palette in standard format.
	public RGBA_f32 readF(size_t index) @safe pure {
		if (index < data.length) return RGBA_f32(data[index]);
		else throw new PaletteBoundsException("Palette is being read out of bounds!");
	}
	///Palette indexing.
	public ref T opIndex(size_t index) @safe pure {
		if (index < data.length) return data[index];
		else throw new PaletteBoundsException("Palette is being read out of bounds!");
	}
	/+
	///Assigns a value to the given index
	public T opIndexAssign(T value, size_t index) @safe pure {
		if (index < data.length) return data[index] = value;
		else throw new PaletteBoundsException("Palette is being read out of bounds!");
	}+/
	///Returns true if the range have reached its end
	public @property bool empty() @nogc @safe pure nothrow const {
		return begin == end;
	}
	///Returns the element at the front
	public ref T front() @nogc @safe pure nothrow {
		return data[begin];
	}
	alias opDollar = length;
	///Moves the front pointer forward by one
	public void popFront() @nogc @safe pure nothrow {
		if (begin != end) begin++;
	}
	///Moves the front pointer forward by one and returns the element
	public ref T moveFront() @nogc @safe pure nothrow {
		if (begin != end) return data[begin++];
		else return data[begin];
	}
	///Returns the element at the back
	public ref T back() @nogc @safe pure nothrow {
		return data[end - 1];
	}
	///Moves the back pointer backward by one
	public void popBack() @nogc @safe pure nothrow {
		if (begin != end) end--;
	}
	///Moves the back pointer backward and returns the element
	public ref T moveBack() @nogc @safe pure nothrow {
		if (begin != end) return data[--end];
		else return data[end];
	}
	///Creates a copy with the front and back pointers reset
	public Palette!T save() @safe pure nothrow {
		return new Palette!T(this);
	}
	///Returns the raw data cast to ubyte
	public ubyte[] raw() @safe pure {
		return reinterpretCast!ubyte(data);
	}
}
/**
 * Palette with separate alpha field, used primarily by PNG.
 */
public class PaletteWithSepA(T) : Palette!T {
	protected ubyte[]		alphaField;
	///CTOR
	this(T[] data, ubyte[] alphaField, uint format, ubyte bitDepth) @nogc @safe pure nothrow {
		assert(data.length == alphaField.length);
		super(data, format, bitDepth);
		this.alphaField = alphaField;
	}
	///Reads palette in standard format.
	public override ARGB8888 read(size_t index) @safe pure {
		if (index < data.length) return ARGB8888(data[index].r, data[index].g, data[index].b, alphaField[index]);
		else throw new PaletteBoundsException("Palette is being read out of bounds!");
	}
	///Reads palette in standard format.
	public override RGBA_f32 readF(size_t index) @safe pure {
		if (index < data.length) {
			RGBA_f32 result = RGBA_f32(data[index]);
			result.fA = alphaField[index] * (1.0 / ubyte.max);
			return result;
		}
		else throw new PaletteBoundsException("Palette is being read out of bounds!");
	}
	///Returns the raw data cast to ubyte
	public override ubyte[] raw() @safe pure {
		return reinterpretCast!ubyte(data) ~ alphaField;
	}
	///Converts the palette to the given format if supported.
	public override IPalette convTo(uint format) @safe {
		IPalette result;
		void converter(OutputType)() @safe {
			OutputType[] array;
			array.length = data.length;
			for(int i ; i < data.length ; i++)
				array[i] = OutputType(read(i));
			result = new Palette!OutputType(array, format, getBitDepth(format));
		}
		switch (format & ~(PixelFormat.BigEndian | PixelFormat.ValidAlpha)) {
			case PixelFormat.RGB888:
				if(format & PixelFormat.BigEndian)
					converter!(RGB888BE);
				else
					converter!(RGB888);
				break;
			case PixelFormat.RGBX8888:
				if(format & PixelFormat.BigEndian)
					converter!(RGBA8888BE);
				else
					converter!(RGBA8888);
				break;
			case PixelFormat.XRGB8888:
				if(format & PixelFormat.BigEndian)
					converter!(ARGB8888BE);
				else
					converter!(ARGB8888);
				break;
			case PixelFormat.RGB565:
				converter!(RGB565);
				break;
			case PixelFormat.RGBX5551:
				converter!(RGBA5551);
				break;
			default:
				throw new ImageFormatException("Format not supported");
		}
		return result;
	}
}
/**
 * Auxiliary data wrapper.
 * Stores data like filters for PNG images.
 */
public interface AuxData {
	///Returns the type of the auxiliary data.
	public @property uint type() @nogc @safe pure nothrow const;
}
/**
 * Frame data for animation.
 */
public class AnimData {
	public uint		hOffset;		///Horizontal offset
	public uint		vOffset;		///Vertical offset
	public uint		hold;			///msecs to display this animation
}
/**
 * Basic imagedata wrapper.
 */
public interface IImageData {
	///Returns the width of the image.
	public @property uint width() @nogc @safe pure nothrow const;
	///Returns the height of the image.
	public @property uint height() @nogc @safe pure nothrow const;
	///Returns the bitdepth of the image.
	public @property ubyte bitDepth() @nogc @safe pure nothrow const;
	///Returns the number of bitplanes per image.
	///Default should be 1.
	public @property ubyte bitplanes() @nogc @safe pure nothrow const;
	///Returns the color format of the image.
	public @property uint pixelFormat() @nogc @safe pure nothrow const;
	///Converts the imagedata to the given format if supported
	public IImageData convTo(uint format) @safe;
	///Reads the image at the given point in ARGB32 format.
	///Does palette lookup if needed.
	public ARGB8888 read(uint x, uint y) @safe pure;
	///Reads the image at the given point in RGBA_f32 format.
	///Does palette lookup if needed.
	public RGBA_f32 readF(uint x, uint y) @safe pure;
	///Flips the image horizontally
	public void flipHorizontal() @safe pure;
	///Flips the image vertically
	public void flipVertical() @safe pure;
	///Returns the raw data cast to ubyte
	public ubyte[] raw() @safe pure;
}
/**
 * Imagedata container.
 */
public class ImageData(T) : IImageData {
	protected T[]			data;
	protected uint			_width, _height, _pixelFormat;
	protected ubyte			_bitDepth;
	///CTOR
	public this(T[] data, uint width, uint height, uint pixelFormat, ubyte bitDepth) @safe pure {
		//assert(data.length == _width * _height);
		this.data = data;
		this._width = width;
		this._height = height;
		this._pixelFormat = pixelFormat;
		this._bitDepth = bitDepth;
	}
	///CTOR with no preexisting image data
	public this(uint width, uint height, uint pixelFormat, ubyte bitDepth) @safe pure {
		//assert(data.length == _width * _height);
		this.data.length = width * height;
		this._width = width;
		this._height = height;
		this._pixelFormat = pixelFormat;
		this._bitDepth = bitDepth;
	}
	///Returns the raw data
	public @property T[] getData() @nogc @safe pure nothrow {
		return data;
	}
	///Returns the raw data cast to ubyte
	public ubyte[] raw() @safe pure {
		return reinterpretCast!ubyte(data);
	}
	///Returns the width of the image.
	public @property uint width() @nogc @safe pure nothrow const {
		return _width;
	}
	///Returns the height of the image.
	public @property uint height() @nogc @safe pure nothrow const {
		return _height;
	}
	///Returns the bitdepth of the image.
	public @property ubyte bitDepth() @nogc @safe pure nothrow const {
		return _bitDepth;
	}

	public @property ubyte bitplanes() @nogc @safe pure nothrow const {
		return 1;
	}

	public @property uint pixelFormat() @nogc @safe pure nothrow const {
		return _pixelFormat;
	}

	public IImageData convTo(uint format) @safe {
		IImageData result;
		void converter(OutputType)() @safe {
			OutputType[] array;
			array.length = data.length;
			for(int i ; i < data.length ; i++)
				array[i] = OutputType(data[i]);
			result = new ImageData!OutputType(array, _width, _height, format, getBitDepth(format));
		}
		switch (format & ~(PixelFormat.BigEndian | PixelFormat.ValidAlpha)) {
			case PixelFormat.Grayscale16Bit:
				ushort[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ushort mid = new MonochromeImageData!ushort(datastream, _width, _height, format, 16);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const RGBA_f32 pixel = readF(x,y);
						mid[x,y] = cast(ushort)((pixel.fR * 0.2125 + pixel.fG * 0.7154 + pixel.fB * 0.0721) / MonochromeImageData!ushort.fYStepping);
					}
				}
				result = mid;
				break;
			case PixelFormat.Grayscale8Bit:
				ubyte[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ubyte mid = new MonochromeImageData!ubyte(datastream, _width, _height, format, 8);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const RGBA_f32 pixel = readF(x,y);
						mid[x,y] = cast(ubyte)((pixel.fR * 0.2125 + pixel.fG * 0.7154 + pixel.fB * 0.0721) / MonochromeImageData!ubyte.fYStepping);
					}
				}
				result = mid;
				break;
			case PixelFormat.YX88:
				if(format & PixelFormat.BigEndian)
					converter!(YA88BE);
				else
					converter!(YA88);
				break;
			case PixelFormat.RGB888:
				if(format & PixelFormat.BigEndian)
					converter!(RGB888BE);
				else
					converter!(RGB888);
				break;
			case PixelFormat.RGBX8888:
				if(format & PixelFormat.BigEndian)
					converter!(RGBA8888BE);
				else
					converter!(RGBA8888);
				break;
			case PixelFormat.XRGB8888:
				if(format & PixelFormat.BigEndian)
					converter!(ARGB8888BE);
				else
					converter!(ARGB8888);
				break;
			case PixelFormat.RGB565:
				converter!(RGB565);
				break;
			case PixelFormat.RGBX5551:
				converter!(RGBA5551);
				break;
			default:
				throw new ImageFormatException("Format not supported");
		}
		return result;
	}
	public ARGB8888 read(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return ARGB8888(data[x + (y * _width)]);
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public RGBA_f32 readF(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return RGBA_f32(data[x + (y * _width)]);
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public ref T opIndex(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return data[x + (y * _width)];
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	///Flips the image horizontally
	public void flipHorizontal() @safe pure {
		for (uint y ; y < _height ; y++) {
			for (uint x ; x < _width / 2 ; x++) {
				const T tmp = opIndex(x, y);
				opIndex(x, y) = opIndex(_width - x, y);
				opIndex(_width - x, y) = tmp;
			}
		}
	}
	///Flips the image vertically
	public void flipVertical() @safe pure {
		import std.algorithm.mutation : swapRanges;
		for (uint y ; y < _height / 2 ; y++) {
			const uint y0 = _height - y - 1;
			T[] a = data[(y * _width)..((y + 1) * _width)];
			T[] b = data[(y0 * _width)..((y0 + 1) * _width)];
			swapRanges(a, b);
		}
	}
}
/**
 * Monochrome imagedata container for 8 and 16 bit types.
 */
public class MonochromeImageData (T) : IImageData {
	public static immutable double fYStepping = 1.0 / T.max;
	protected T[]			data;
	protected uint			_width, _height, _pixelFormat;
	protected ubyte			_bitDepth;
	public this(T[] data, uint width, uint height, uint pixelFormat, ubyte bitDepth) @safe pure {
		//assert(data.length == _width * _height);
		this.data = data;
		this._width = width;
		this._height = height;
		this._pixelFormat = pixelFormat;
		this._bitDepth = bitDepth;
	}
	///CTOR with no preexisting image data
	public this(uint width, uint height, uint pixelFormat, ubyte bitDepth) @safe pure {
		//assert(data.length == _width * _height);
		this.data.length = width * height;
		this._width = width;
		this._height = height;
		this._pixelFormat = pixelFormat;
		this._bitDepth = bitDepth;
	}
	///Returns the width of the image.
	public @property uint width() @nogc @safe pure nothrow const {
		return _width;
	}
	///Returns the height of the image.
	public @property uint height() @nogc @safe pure nothrow const {
		return _height;
	}
	///Returns the bitdepth of the image.
	public @property ubyte bitDepth() @nogc @safe pure nothrow const {
		static if(is(T == ubyte)) return 8;
		else return 16;
	}
	///Returns the number of bitplanes per image.
	///Default should be 1.
	public @property ubyte bitplanes() @nogc @safe pure nothrow const {
		return 1;
	}
	///Returns the color format of the image.
	public @property uint pixelFormat() @nogc @safe pure nothrow const {
		static if(is(T == ubyte)) return PixelFormat.Grayscale8Bit;
		else return PixelFormat.Grayscale16Bit;
	}
	///Converts the imagedata to the given format if supported
	public IImageData convTo(uint format) @safe {
		IImageData result;
		void converter(OutputType)() @safe {
			OutputType[] array;
			array.length = data.length;
			for(int i ; i < data.length ; i++)
				array[i] = OutputType(data[i] * fYStepping);
			result = new ImageData!OutputType(array, _width, _height, format, getBitDepth(format));
		}
		switch (format & ~(PixelFormat.BigEndian | PixelFormat.ValidAlpha)) {
			case PixelFormat.Grayscale16Bit:
				ushort[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ushort mid = new MonochromeImageData!ushort(datastream, _width, _height, format, 16);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const RGBA_f32 pixel = readF(x,y);
						mid[x,y] = cast(ushort)((pixel.fR * 0.2125 + pixel.fG * 0.7154 + pixel.fB * 0.0721) / MonochromeImageData!ushort.fYStepping);
					}
				}
				result = mid;
				break;
			case PixelFormat.Grayscale8Bit:
				ubyte[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ubyte mid = new MonochromeImageData!ubyte(datastream, _width, _height, format, 8);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const RGBA_f32 pixel = readF(x,y);
						mid[x,y] = cast(ubyte)((pixel.fR * 0.2125 + pixel.fG * 0.7154 + pixel.fB * 0.0721) / MonochromeImageData!ubyte.fYStepping);
					}
				}
				result = mid;
				break;
			case PixelFormat.YX88:
				if(format & PixelFormat.BigEndian)
					converter!(YA88BE);
				else
					converter!(YA88);
				break;
			case PixelFormat.RGB888:
				if(format & PixelFormat.BigEndian)
					converter!(RGB888BE);
				else
					converter!(RGB888);
				break;
			case PixelFormat.RGBX8888:
				if(format & PixelFormat.BigEndian)
					converter!(RGBA8888BE);
				else
					converter!(RGBA8888);
				break;
			case PixelFormat.XRGB8888:
				if(format & PixelFormat.BigEndian)
					converter!(ARGB8888BE);
				else
					converter!(ARGB8888);
				break;
			case PixelFormat.RGB565:
				converter!(RGB565);
				break;
			case PixelFormat.RGBX5551:
				converter!(RGBA5551);
				break;
			default:
				throw new ImageFormatException("Format not supported");
		}
		return result;
	}
	///Reads the image at the given point in ARGB32 format.
	public ARGB8888 read(uint x, uint y) @safe pure {
		static if (is(T == ubyte)) {
			if(x < _width && y < _height) return ARGB8888(data[x + (y * _width)]);
			else throw new ImageBoundsException("Image is being read out of bounds!");
		} else static if (is(T == ushort)) {
			if(x < _width && y < _height) return ARGB8888(cast(ubyte)(cast(uint)data[x + (y * _width)]>>>8));
			else throw new ImageBoundsException("Image is being read out of bounds!");
		}
	}
	///Reads the image at the given point in RGBA_f32 format.
	public RGBA_f32 readF(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return RGBA_f32(data[x + (y * _width)] * fYStepping);
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public ref T opIndex(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return data[x + (y * _width)];
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	///Flips the image horizontally
	public void flipHorizontal() @safe pure {
		for (uint y ; y < _height ; y++) {
			for (uint x ; x < _width / 2 ; x++) {
				const T tmp = opIndex(x, y);
				opIndex(x, y) = opIndex(_width - x, y);
				opIndex(_width - x, y) = tmp;
			}
		}
	}
	///Flips the image vertically
	public void flipVertical() @safe pure {
		import std.algorithm.mutation : swapRanges;
		for (uint y ; y < _height / 2 ; y++) {
			const uint y0 = _height - y - 1;
			T[] a = data[(y * _width)..((y + 1) * _width)];
			T[] b = data[(y0 * _width)..((y0 + 1) * _width)];
			swapRanges(a, b);
		}
	}
	///Returns the raw data cast to ubyte
	public ubyte[] raw() @safe pure {
		return reinterpretCast!ubyte(data);
	}
}
/**
 * 4 Bit indexed image data.
 */
public class MonochromeImageData4Bit : IImageData {
	public static immutable double fYStepping = 1.0 / 15;
	protected ubyte[]		data;
	protected NibbleArray	accessor;
	protected uint			_width, _height, _pitch;
	///CTOR
	public this(ubyte[] data,  uint width, uint height) @safe pure {
		this.data = data;
		this._width = width;
		this._height = height;
		_pitch = _width + (_width % 2);
		accessor = NibbleArray(data, _pitch * _height);
	}
	///CTOR with no preexisting image data
	public this(uint width, uint height) @safe pure {
		//assert(data.length == _width * _height);
		this._width = width;
		this._height = height;
		_pitch = _width + (_width % 2);
		this.data.length = _pitch * _height;
		accessor = NibbleArray(data, _pitch * _height);
	}
	///Returns the raw data
	public @property NibbleArray getData() @nogc @safe pure nothrow {
		return accessor;
	}
	///Returns the raw data cast to ubyte
	public ubyte[] raw() @safe pure {
		return data;
	}
	///Returns the width of the image.
	public @property uint width() @nogc @safe pure nothrow const {
		return _width;
	}
	///Returns the height of the image.
	public @property uint height() @nogc @safe pure nothrow const {
		return _height;
	}

	public @property ubyte bitDepth() @nogc @safe pure nothrow const {
		return 4;
	}

	public @property ubyte bitplanes() @nogc @safe pure nothrow const {
		return 1;
	}

	public @property uint pixelFormat() @nogc @safe pure nothrow const {
		return PixelFormat.Grayscale4Bit;
	}

	public IImageData convTo(uint format) @safe {
		IImageData result;
		void converter(OutputType)() @safe {
			OutputType[] array;
			array.reserve(_width * _height);
			for (uint y ; y < _height ; y++) {
				for (uint x ; x < _width ; x++) {
					array ~= OutputType(readF(x, y));
				}
			}
			result = new ImageData!OutputType(array, _width, _height, format, getBitDepth(format));
		}
		
		switch (format & ~(PixelFormat.BigEndian | PixelFormat.ValidAlpha)) {
			
			case PixelFormat.Grayscale16Bit:
				ushort[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ushort mid = new MonochromeImageData!ushort(datastream, _width, _height, format, 16);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const ubyte val = opIndex(x, y);
						mid[x,y] = cast(ushort)(val * 0x1111);
					}
				}
				result = mid;
				break;
			case PixelFormat.Grayscale8Bit:
				ubyte[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ubyte mid = new MonochromeImageData!ubyte(datastream, _width, _height, format, 8);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const ubyte val = opIndex(x, y);
						mid[x,y] = cast(ubyte)(val<<4 | val);
					}
				}
				result = mid;
				break;
			case PixelFormat.YX88:
				if(format & PixelFormat.BigEndian)
					converter!(YA88BE);
				else
					converter!(YA88);
				break;
			case PixelFormat.RGB888:
				if(format & PixelFormat.BigEndian)
					converter!(RGB888BE);
				else
					converter!(RGB888);
				break;
			case PixelFormat.RGBX8888:
				if(format & PixelFormat.BigEndian)
					converter!(RGBA8888BE);
				else
					converter!(RGBA8888);
				break;
			case PixelFormat.XRGB8888:
				if(format & PixelFormat.BigEndian)
					converter!(ARGB8888BE);
				else
					converter!(ARGB8888);
				break;
			case PixelFormat.RGB565:
				converter!(RGB565);
				break;
			case PixelFormat.RGBX5551:
				converter!(RGBA5551);
				break;
			default:
				throw new ImageFormatException("Format not supported");
		}
		return result;
	}
	public ARGB8888 read(uint x, uint y) @safe pure {
		const ubyte val = opIndex(x,y);
		return ARGB8888(val<<4 | val);
	}
	public RGBA_f32 readF(uint x, uint y) @safe pure {
		const ubyte val = opIndex(x,y);
		return RGBA_f32(val * fYStepping);
	}
	public ubyte opIndex(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return accessor[x + (y * _pitch)];
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public ubyte opIndexAssign(ubyte val, uint x, uint y) @safe pure {
		if(x < _width && y < _height) return accessor[x + (y * _pitch)] = val;
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	///Flips the image horizontally
	public void flipHorizontal() @safe pure {
		for (uint y ; y < _height ; y++) {
			for (uint x ; x < _width>>>1 ; x++) {
				const ubyte tmp = opIndex(x, y);
				opIndexAssign(opIndex(_width - x, y), x, y);
				opIndexAssign(tmp, _width - x, y);
			}
		}
	}
	///Flips the image vertically
	public void flipVertical() @safe pure {
		import std.algorithm.mutation : swapRanges;
		for (uint y ; y < _height / 2 ; y++) {
			const uint y0 = _height - y - 1;
			ubyte[] a = data[(y * _pitch/2)..((y + 1) * _pitch/2)];
			ubyte[] b = data[(y0 * _pitch/2)..((y0 + 1) * _pitch/2)];
			swapRanges(a, b);
		}
	}
}
/**
 * 2 Bit grayscale image data.
 */
public class MonochromeImageData2Bit : IImageData {
	public static immutable double fYStepping = 1.0 / 3;
	protected ubyte[]		data;
	protected QuadArray		accessor;
	protected uint			_width, _height, _pitch;
	///CTOR
	public this(ubyte[] data, uint width, uint height) @safe pure {
		this.data = data;
		this._width = width;
		this._height = height;
		_pitch = width;
		_pitch += width % 4 ? 4 - width % 4 : 0;
		accessor = QuadArray(data, _pitch * _height);
	}
	///CTOR without preexisting data
	public this(uint width, uint height) @safe pure {
		this._width = width;
		this._height = height;
		_pitch = _width;
		_pitch += _width % 4 ? 4 - _width % 4 : 0;
		data.length = _pitch * _height;
		accessor = QuadArray(data, _pitch * _height);
	}
	///Returns the raw data
	public @property QuadArray getData() @nogc @safe pure nothrow {
		return accessor;
	}
	///Returns the raw data cast to ubyte
	public ubyte[] raw() @safe pure {
		return data;
	}
	///Returns the width of the image.
	public @property uint width() @nogc @safe pure nothrow const {
		return _width;
	}
	///Returns the height of the image.
	public @property uint height() @nogc @safe pure nothrow const {
		return _height;
	}

	public @property ubyte bitDepth() @nogc @safe pure nothrow const {
		return 2;
	}

	public @property ubyte bitplanes() @nogc @safe pure nothrow const {
		return 1;
	}

	public @property uint pixelFormat() @nogc @safe pure nothrow const {
		return PixelFormat.Grayscale2Bit;
	}

	public IImageData convTo(uint format) @safe {
		IImageData result;
		void converter(OutputType)() @safe {
			OutputType[] array;
			array.reserve(_width * _height);
			for (uint y ; y < _height ; y++) {
				for (uint x ; x < _width ; x++) {
					array ~= OutputType(readF(x, y));
				}
			}
			result = new ImageData!OutputType(array, _width, _height, format, getBitDepth(format));
		}
		switch (format & ~(PixelFormat.BigEndian | PixelFormat.ValidAlpha)) {
			case PixelFormat.Grayscale16Bit:
				ushort[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ushort mid = new MonochromeImageData!ushort(datastream, _width, _height, format, 16);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const ubyte val = opIndex(x, y);
						mid[x,y] = cast(ushort)(val * 0b0101_0101_0101_0101);
					}
				}
				result = mid;
				break;
			case PixelFormat.Grayscale8Bit:
				ubyte[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ubyte mid = new MonochromeImageData!ubyte(datastream, _width, _height, format, 8);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const ubyte val = opIndex(x, y);
						mid[x,y] = cast(ubyte)(val * 0b0101_0101);
					}
				}
				result = mid;
				break;
			case PixelFormat.YX88:
				if(format & PixelFormat.BigEndian)
					converter!(YA88BE);
				else
					converter!(YA88);
				break;
			case PixelFormat.RGB888:
				if(format & PixelFormat.BigEndian)
					converter!(RGB888BE);
				else
					converter!(RGB888);
				break;
			case PixelFormat.RGBX8888:
				if(format & PixelFormat.BigEndian)
					converter!(RGBA8888BE);
				else
					converter!(RGBA8888);
				break;
			case PixelFormat.XRGB8888:
				if(format & PixelFormat.BigEndian)
					converter!(ARGB8888BE);
				else
					converter!(ARGB8888);
				break;
			case PixelFormat.RGB565:
				converter!(RGB565);
				break;
			case PixelFormat.RGBX5551:
				converter!(RGBA5551);
				break;
			default:
				throw new ImageFormatException("Format not supported");
		}
		return result;
	}
	public ARGB8888 read(uint x, uint y) @safe pure {
		const ubyte val = opIndex(x,y);
		return ARGB8888(val<<6 | val<<4 | val<<2 | val);
	}
	public RGBA_f32 readF(uint x, uint y) @safe pure {
		const ubyte val = opIndex(x,y);
		return RGBA_f32(val * fYStepping);
	}
	public ubyte opIndex(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return accessor[x + (y * _pitch)];
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public ubyte opIndexAssign(ubyte val, uint x, uint y) @safe pure {
		if(x < _width && y < _height) return accessor[x + (y * _pitch)] = val;
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	///Flips the image horizontally
	public void flipHorizontal() @safe pure {
		for (uint y ; y < _height ; y++) {
			for (uint x ; x < _width>>>1 ; x++) {
				const ubyte tmp = opIndex(x, y);
				opIndexAssign(opIndex(_width - x, y), x, y);
				opIndexAssign(tmp, _width - x, y);
			}
		}
	}
	///Flips the image vertically
	public void flipVertical() @safe pure {
		import std.algorithm.mutation : swapRanges;
		for (uint y ; y < _height / 2 ; y++) {
			const uint y0 = _height - y - 1;
			ubyte[] a = data[(y * _pitch/4)..((y + 1) * _pitch/4)];
			ubyte[] b = data[(y0 * _pitch/4)..((y0 + 1) * _pitch/4)];
			swapRanges(a, b);
		}
	}
}
/**
 * Monochrome 1 bit access
 */
public class MonochromeImageData1Bit : IImageData {
	protected ubyte[]		data;
	protected BitArray		accessor;
	protected uint			_width, _height, _pitch;
	///CTOR
	public this(ubyte[] data, uint _width, uint _height) @trusted pure {
		this.data = data;
		this._width = _width;
		this._height = _height;
		_pitch = _width;
		_pitch += width % 8 ? 8 - width % 8 : 0;
		accessor = BitArray(data, _pitch * _height);
	}
	///Returns the raw data
	public @property BitArray getData() @nogc @safe pure nothrow {
		return accessor;
	}
	///Returns the raw data cast to ubyte
	public ubyte[] raw() @safe pure {
		return data;
	}
	///Returns the width of the image.
	public @property uint width() @nogc @safe pure nothrow const {
		return _width;
	}
	///Returns the height of the image.
	public @property uint height() @nogc @safe pure nothrow const {
		return _height;
	}

	public @property ubyte bitDepth() @nogc @safe pure nothrow const {
		return 1;
	}

	public @property ubyte bitplanes() @nogc @safe pure nothrow const {
		return 1;
	}

	public @property uint pixelFormat() @nogc @safe pure nothrow const {
		return PixelFormat.Grayscale1Bit;
	}

	public IImageData convTo(uint format) @safe {
		IImageData result;
		void converter(OutputType)() @safe {
			OutputType[] array;
			array.reserve(_width * _height);
			for (uint y ; y < _height ; y++) {
				for (uint x ; x < _width ; x++) {
					array ~= OutputType(readF(x, y));
				}
			}
			result = new ImageData!OutputType(array, _width, _height, format, getBitDepth(format));
		}
		
		switch (format & ~(PixelFormat.BigEndian | PixelFormat.ValidAlpha)) {
			case PixelFormat.Grayscale16Bit:
				ushort[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ushort mid = new MonochromeImageData!ushort(datastream, _width, _height, format, 16);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const RGBA_f32 pixel = readF(x,y);
						mid[x,y] = cast(ushort)((pixel.fR * 0.2125 + pixel.fG * 0.7154 + pixel.fB * 0.0721) / MonochromeImageData!ushort.fYStepping);
					}
				}
				result = mid;
				break;
			case PixelFormat.Grayscale8Bit:
				ubyte[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ubyte mid = new MonochromeImageData!ubyte(datastream, _width, _height, format, 8);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const RGBA_f32 pixel = readF(x,y);
						mid[x,y] = cast(ubyte)((pixel.fR * 0.2125 + pixel.fG * 0.7154 + pixel.fB * 0.0721) / MonochromeImageData!ubyte.fYStepping);
					}
				}
				result = mid;
				break;
			case PixelFormat.YX88:
				if(format & PixelFormat.BigEndian)
					converter!(YA88BE);
				else
					converter!(YA88);
				break;
			case PixelFormat.RGB888:
				if(format & PixelFormat.BigEndian)
					converter!(RGB888BE);
				else
					converter!(RGB888);
				break;
			case PixelFormat.RGBX8888:
				if(format & PixelFormat.BigEndian)
					converter!(RGBA8888BE);
				else
					converter!(RGBA8888);
				break;
			case PixelFormat.XRGB8888:
				if(format & PixelFormat.BigEndian)
					converter!(ARGB8888BE);
				else
					converter!(ARGB8888);
				break;
			case PixelFormat.RGB565:
				converter!(RGB565);
				break;
			case PixelFormat.RGBX5551:
				converter!(RGBA5551);
				break;
			default:
				throw new ImageFormatException("Format not supported");
		}
		return result;
	}

	public ARGB8888 read(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return opIndex(x, y) ? ARGB8888(255) : ARGB8888(0);
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public RGBA_f32 readF(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return opIndex(x, y) ? RGBA_f32(1.0) : RGBA_f32(0.0);
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public bool opIndex(uint x, uint y) @trusted pure {
		if(x < _width && y < _height) return accessor[x + (y * _pitch)];
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public ubyte opIndexAssign(bool val, uint x, uint y) @trusted pure {
		if(x < _width && y < _height) return accessor[x + (y * _pitch)] = val;
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	///Flips the image horizontally
	public void flipHorizontal() @safe pure {
		for (uint y ; y < _height ; y++) {
			for (uint x ; x < _width>>>1 ; x++) {
				const bool tmp = opIndex(x, y);
				opIndexAssign(opIndex(_width - x, y), x, y);
				opIndexAssign(tmp, _width - x, y);
			}
		}
	}
	///Flips the image vertically
	public void flipVertical() @safe pure {
		import std.algorithm.mutation : swapRanges;
		for (uint y ; y < _height / 2 ; y++) {
			const uint y0 = _height - y - 1;
			ubyte[] a = data[(y * _pitch/8)..((y + 1) * _pitch/8)];
			ubyte[] b = data[(y0 * _pitch/8)..((y0 + 1) * _pitch/8)];
			swapRanges(a, b);
		}
	}
}
/**
 * Indexed imagedata container for ubyte and ushort based formats
 */
public class IndexedImageData (T) : IImageData {
	protected T[]			data;
	public IPalette			palette;
	protected uint			_width, _height;
	///CTOR
	public this(T[] data, IPalette palette, uint width, uint height) @safe pure {
		this.data = data;
		this.palette = palette;
		this._width = width;
		this._height = height;
	}
	///CTOR with no preexisting image data
	public this(IPalette palette, uint width, uint height) @safe pure {
		//assert(data.length == _width * _height);
		this.data.length = width * height;
		this.palette = palette;
		this._width = width;
		this._height = height;
	}
	///Returns the raw data
	public @property T[] getData() @nogc @safe pure nothrow {
		return data;
	}
	///Returns the raw data cast to ubyte
	public ubyte[] raw() @safe pure {
		return reinterpretCast!ubyte(data);
	}
	///Returns the width of the image.
	public @property uint width() @nogc @safe pure nothrow const {
		return _width;
	}
	///Returns the height of the image.
	public @property uint height() @nogc @safe pure nothrow const {
		return _height;
	}

	public @property ubyte bitDepth() @nogc @safe pure nothrow const {
		static if(is(T == ubyte)) return 8;
		else return 16;
	}

	public @property ubyte bitplanes() @nogc @safe pure nothrow const {
		return 1;
	}

	public @property uint pixelFormat() @nogc @safe pure nothrow const {
		static if(is(T == ubyte)) return PixelFormat.Indexed8Bit;
		else return PixelFormat.Indexed16Bit;
	}

	public IImageData convTo(uint format) @safe {
		IImageData result;
		void converter(OutputType)() @safe {
			OutputType[] array;
			array.length = data.length;
			for(int i ; i < data.length ; i++)
				array[i] = OutputType(palette.read(data[i]));
			result = new ImageData!OutputType(array, _width, _height, format, getBitDepth(format));
		}
		void upconv(OutputType)() @safe {
			OutputType[] array;
			array.length = data.length;
			for(int i ; i < data.length ; i++)
				array[i] = data[i];
			result = new IndexedImageData!OutputType(array, palette, _width, _height);
		}
		switch (format & ~(PixelFormat.BigEndian | PixelFormat.ValidAlpha)) {
			case PixelFormat.Indexed16Bit:
				upconv!ushort;
				break;
			case PixelFormat.Grayscale16Bit:
				ushort[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ushort mid = new MonochromeImageData!ushort(datastream, _width, _height, format, 16);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const RGBA_f32 pixel = readF(x,y);
						mid[x,y] = cast(ushort)((pixel.fR * 0.2125 + pixel.fG * 0.7154 + pixel.fB * 0.0721) / MonochromeImageData!ushort.fYStepping);
					}
				}
				result = mid;
				break;
			case PixelFormat.Grayscale8Bit:
				ubyte[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ubyte mid = new MonochromeImageData!ubyte(datastream, _width, _height, format, 8);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const RGBA_f32 pixel = readF(x,y);
						mid[x,y] = cast(ubyte)((pixel.fR * 0.2125 + pixel.fG * 0.7154 + pixel.fB * 0.0721) / MonochromeImageData!ubyte.fYStepping);
					}
				}
				result = mid;
				break;
			case PixelFormat.YX88:
				if(format & PixelFormat.BigEndian)
					converter!(YA88BE);
				else
					converter!(YA88);
				break;
			case PixelFormat.RGB888:
				if(format & PixelFormat.BigEndian)
					converter!(RGB888BE);
				else
					converter!(RGB888);
				break;
			case PixelFormat.RGBX8888:
				if(format & PixelFormat.BigEndian)
					converter!(RGBA8888BE);
				else
					converter!(RGBA8888);
				break;
			case PixelFormat.XRGB8888:
				if(format & PixelFormat.BigEndian)
					converter!(ARGB8888BE);
				else
					converter!(ARGB8888);
				break;
			case PixelFormat.RGB565:
				converter!(RGB565);
				break;
			case PixelFormat.RGBX5551:
				converter!(RGBA5551);
				break;
			default:
				throw new ImageFormatException("Format not supported");
		}
		return result;
	}
	public ARGB8888 read(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return palette.read(data[x + (y * _width)]);
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public RGBA_f32 readF(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return palette.readF(data[x + (y * _width)]);
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public ref T opIndex(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return data[x + (y * _width)];
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	///Flips the image horizontally
	public void flipHorizontal() @safe pure {
		for (uint y ; y < _height ; y++) {
			for (uint x ; x < _width>>>1 ; x++) {
				const T tmp = opIndex(x, y);
				opIndex(x, y) = opIndex(_width - x, y);
				opIndex(_width - x, y) = tmp;
			}
		}
	}
	///Flips the image vertically
	public void flipVertical() @safe pure {
		import std.algorithm.mutation : swapRanges;
		for (uint y ; y < _height / 2 ; y++) {
			const uint y0 = _height - y - 1;
			T[] a = data[(y * _width)..((y + 1) * _width)];
			T[] b = data[(y0 * _width)..((y0 + 1) * _width)];
			swapRanges(a, b);
		}
	}
}
/**
 * 4 Bit indexed image data.
 */
public class IndexedImageData4Bit : IImageData {
	protected ubyte[]		data;
	protected NibbleArray	accessor;
	public IPalette			palette;
	protected uint			_width, _height, _pitch;
	///CTOR
	public this(ubyte[] data, IPalette palette, uint width, uint height) @safe pure {
		this.data = data;
		this.palette = palette;
		this._width = width;
		this._height = height;
		_pitch = _width + (_width % 2);
		accessor = NibbleArray(data, _pitch * _height);
	}
	///CTOR with no preexisting image data
	public this(IPalette palette, uint width, uint height) @safe pure {
		//assert(data.length == _width * _height);
		this._width = width;
		this._height = height;
		_pitch = _width + (_width % 2);
		this.data.length = _pitch * _height;
		accessor = NibbleArray(data, _pitch * _height);
		this.palette = palette;
	}
	///Returns the raw data
	public @property NibbleArray getData() @nogc @safe pure nothrow {
		return accessor;
	}
	///Returns the raw data cast to ubyte
	public ubyte[] raw() @safe pure {
		return data;
	}
	///Returns the width of the image.
	public @property uint width() @nogc @safe pure nothrow const {
		return _width;
	}
	///Returns the height of the image.
	public @property uint height() @nogc @safe pure nothrow const {
		return _height;
	}

	public @property ubyte bitDepth() @nogc @safe pure nothrow const {
		return 4;
	}

	public @property ubyte bitplanes() @nogc @safe pure nothrow const {
		return 1;
	}

	public @property uint pixelFormat() @nogc @safe pure nothrow const {
		return PixelFormat.Indexed4Bit;
	}

	public IImageData convTo(uint format) @safe {
		IImageData result;
		void converter(OutputType)() @safe {
			OutputType[] array;
			array.length = data.length;
			for(int i ; i < data.length ; i++)
				array[i] = OutputType(palette.read(data[i]));
			result = new ImageData!OutputType(array, _width, _height, format, getBitDepth(format));
		}
		void upconv(OutputType)() @safe {
			IndexedImageData!OutputType iid = new IndexedImageData!OutputType(palette, _width, _height);
			for(int y ; y < _height ; y++)
				for(int x ; x < _width ; x++)
					iid[x, y] = opIndex(x, y);
			result = iid;
		}
		switch (format & ~(PixelFormat.BigEndian | PixelFormat.ValidAlpha)) {
			case PixelFormat.Indexed16Bit:
				upconv!ushort;
				break;
			case PixelFormat.Indexed8Bit:
				upconv!ubyte;
				break;
			case PixelFormat.Grayscale16Bit:
				ushort[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ushort mid = new MonochromeImageData!ushort(datastream, _width, _height, format, 16);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const RGBA_f32 pixel = readF(x,y);
						mid[x,y] = cast(ushort)((pixel.fR * 0.2125 + pixel.fG * 0.7154 + pixel.fB * 0.0721) / MonochromeImageData!ushort.fYStepping);
					}
				}
				result = mid;
				break;
			case PixelFormat.Grayscale8Bit:
				ubyte[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ubyte mid = new MonochromeImageData!ubyte(datastream, _width, _height, format, 8);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const RGBA_f32 pixel = readF(x,y);
						mid[x,y] = cast(ubyte)((pixel.fR * 0.2125 + pixel.fG * 0.7154 + pixel.fB * 0.0721) / MonochromeImageData!ubyte.fYStepping);
					}
				}
				result = mid;
				break;
			case PixelFormat.YX88:
				if(format & PixelFormat.BigEndian)
					converter!(YA88BE);
				else
					converter!(YA88);
				break;
			case PixelFormat.RGB888:
				if(format & PixelFormat.BigEndian)
					converter!(RGB888BE);
				else
					converter!(RGB888);
				break;
			case PixelFormat.RGBX8888:
				if(format & PixelFormat.BigEndian)
					converter!(RGBA8888BE);
				else
					converter!(RGBA8888);
				break;
			case PixelFormat.XRGB8888:
				if(format & PixelFormat.BigEndian)
					converter!(ARGB8888BE);
				else
					converter!(ARGB8888);
				break;
			case PixelFormat.RGB565:
				converter!(RGB565);
				break;
			case PixelFormat.RGBX5551:
				converter!(RGBA5551);
				break;
			default:
				throw new ImageFormatException("Format not supported");
		}
		return result;
	}
	public ARGB8888 read(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return palette.read(accessor[x + (y * _pitch)]);
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public RGBA_f32 readF(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return palette.readF(accessor[x + (y * _pitch)]);
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public ubyte opIndex(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return accessor[x + (y * _pitch)];
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public ubyte opIndexAssign(ubyte val, uint x, uint y) @safe pure {
		if(x < _width && y < _height) return accessor[x + (y * _pitch)] = val;
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	///Flips the image horizontally
	public void flipHorizontal() @safe pure {
		for (uint y ; y < _height ; y++) {
			for (uint x ; x < _width>>>1 ; x++) {
				const ubyte tmp = opIndex(x, y);
				opIndexAssign(opIndex(_width - x, y), x, y);
				opIndexAssign(tmp, _width - x, y);
			}
		}
	}
	///Flips the image vertically
	public void flipVertical() @safe pure {
		import std.algorithm.mutation : swapRanges;
		for (uint y ; y < _height / 2 ; y++) {
			const uint y0 = _height - y - 1;
			ubyte[] a = data[(y * _pitch/2)..((y + 1) * _pitch/2)];
			ubyte[] b = data[(y0 * _pitch/2)..((y0 + 1) * _pitch/2)];
			swapRanges(a, b);
		}
	}
}
/**
 * 2 Bit indexed image data.
 */
public class IndexedImageData2Bit : IImageData {
	protected ubyte[]		data;
	protected QuadArray		accessor;
	public IPalette			palette;
	protected uint			_width, _height, _pitch;
	///CTOR
	public this(ubyte[] data, IPalette palette, uint width, uint height) @safe pure {
		this.data = data;
		this.palette = palette;
		this._width = width;
		this._height = height;
		_pitch = width;
		_pitch += width % 4 ? 4 - width % 4 : 0;
		accessor = QuadArray(data, _pitch * _height);
	}
	///CTOR without preexisting data
	public this(IPalette palette, uint width, uint height) @safe pure {
		this.palette = palette;
		this._width = width;
		this._height = height;
		_pitch = _width;
		_pitch += _width % 4 ? 4 - _width % 4 : 0;
		data.length = _pitch * _height;
		accessor = QuadArray(data, _pitch * _height);
	}
	///Returns the raw data
	public @property QuadArray getData() @nogc @safe pure nothrow {
		return accessor;
	}
	///Returns the raw data cast to ubyte
	public ubyte[] raw() @safe pure {
		return data;
	}
	///Returns the width of the image.
	public @property uint width() @nogc @safe pure nothrow const {
		return _width;
	}
	///Returns the height of the image.
	public @property uint height() @nogc @safe pure nothrow const {
		return _height;
	}

	public @property ubyte bitDepth() @nogc @safe pure nothrow const {
		return 2;
	}

	public @property ubyte bitplanes() @nogc @safe pure nothrow const {
		return 1;
	}

	public @property uint pixelFormat() @nogc @safe pure nothrow const {
		return PixelFormat.Indexed2Bit;
	}

	public IImageData convTo(uint format) @safe {
		IImageData result;
		void converter(OutputType)() @safe {
			OutputType[] array;
			array.length = data.length;
			for(int i ; i < data.length ; i++)
				array[i] = OutputType(palette.read(data[i]));
			result = new ImageData!OutputType(array, _width, _height, format, getBitDepth(format));
		}
		void upconv(OutputType)() @safe {
			IndexedImageData!OutputType iid = new IndexedImageData!OutputType(palette, _width, _height);
			for(int y ; y < _height ; y++)
				for(int x ; x < _width ; x++)
					iid[x, y] = opIndex(x, y);
			result = iid;
		}
		switch (format & ~(PixelFormat.BigEndian | PixelFormat.ValidAlpha)) {
			case PixelFormat.Indexed16Bit:
				upconv!ushort;
				break;
			case PixelFormat.Indexed8Bit:
				upconv!ubyte;
				break;
			case PixelFormat.Indexed4Bit:
				IndexedImageData4Bit iid = new IndexedImageData4Bit(palette, _width, _height);
				for(int y ; y < _height ; y++)
					for(int x ; x < _width ; x++)
						iid[x, y] = opIndex(x, y);
				result = iid;
				break;
			case PixelFormat.Grayscale16Bit:
				ushort[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ushort mid = new MonochromeImageData!ushort(datastream, _width, _height, format, 16);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const RGBA_f32 pixel = readF(x,y);
						mid[x,y] = cast(ushort)((pixel.fR * 0.2125 + pixel.fG * 0.7154 + pixel.fB * 0.0721) / MonochromeImageData!ushort.fYStepping);
					}
				}
				result = mid;
				break;
			case PixelFormat.Grayscale8Bit:
				ubyte[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ubyte mid = new MonochromeImageData!ubyte(datastream, _width, _height, format, 8);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const RGBA_f32 pixel = readF(x,y);
						mid[x,y] = cast(ubyte)((pixel.fR * 0.2125 + pixel.fG * 0.7154 + pixel.fB * 0.0721) / MonochromeImageData!ubyte.fYStepping);
					}
				}
				result = mid;
				break;
			case PixelFormat.YX88:
				if(format & PixelFormat.BigEndian)
					converter!(YA88BE);
				else
					converter!(YA88);
				break;
			case PixelFormat.RGB888:
				if(format & PixelFormat.BigEndian)
					converter!(RGB888BE);
				else
					converter!(RGB888);
				break;
			case PixelFormat.RGBX8888:
				if(format & PixelFormat.BigEndian)
					converter!(RGBA8888BE);
				else
					converter!(RGBA8888);
				break;
			case PixelFormat.XRGB8888:
				if(format & PixelFormat.BigEndian)
					converter!(ARGB8888BE);
				else
					converter!(ARGB8888);
				break;
			case PixelFormat.RGB565:
				converter!(RGB565);
				break;
			case PixelFormat.RGBX5551:
				converter!(RGBA5551);
				break;
			default:
				throw new ImageFormatException("Format not supported");
		}
		return result;
	}
	public ARGB8888 read(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return palette.read(accessor[x + (y * _pitch)]);
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public RGBA_f32 readF(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return palette.readF(accessor[x + (y * _pitch)]);
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public ubyte opIndex(uint x, uint y) @safe pure {
		if(x < _width && y < _height) return accessor[x + (y * _pitch)];
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public ubyte opIndexAssign(ubyte val, uint x, uint y) @safe pure {
		if(x < _width && y < _height) return accessor[x + (y * _pitch)] = val;
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	///Flips the image horizontally
	public void flipHorizontal() @safe pure {
		for (uint y ; y < _height ; y++) {
			for (uint x ; x < _width>>>1 ; x++) {
				const ubyte tmp = opIndex(x, y);
				opIndexAssign(opIndex(_width - x, y),x, y);
				opIndexAssign(tmp, _width - x, y);
			}
		}
	}
	///Flips the image vertically
	public void flipVertical() @safe pure {
		import std.algorithm.mutation : swapRanges;
		for (uint y ; y < _height / 2 ; y++) {
			const uint y0 = _height - y - 1;
			ubyte[] a = data[(y * _pitch/4)..((y + 1) * _pitch/4)];
			ubyte[] b = data[(y0 * _pitch/4)..((y0 + 1) * _pitch/4)];
			swapRanges(a, b);
		}
	}
}
/**
 * Monochrome 1 bit access
 */
public class IndexedImageData1Bit : IImageData {
	protected ubyte[]		data;
	protected BitArray		accessor;
	public IPalette			palette;
	protected uint			_width, _height, _pitch;
	///CTOR
	public this(ubyte[] data, IPalette palette, uint _width, uint _height) @trusted pure {
		this.data = data;
		this.palette = palette;
		this._width = _width;
		this._height = _height;
		_pitch = _width;
		_pitch += width % 8 ? 8 - width % 8 : 0;
		accessor = BitArray(data, _pitch * _height);
	}
	///Returns the raw data
	public @property BitArray getData() @nogc @safe pure nothrow {
		return accessor;
	}
	///Returns the raw data cast to ubyte
	public ubyte[] raw() @safe pure {
		return data;
	}
	///Returns the width of the image.
	public @property uint width() @nogc @safe pure nothrow const {
		return _width;
	}
	///Returns the height of the image.
	public @property uint height() @nogc @safe pure nothrow const {
		return _height;
	}

	public @property ubyte bitDepth() @nogc @safe pure nothrow const {
		return 1;
	}

	public @property ubyte bitplanes() @nogc @safe pure nothrow const {
		return 1;
	}

	public @property uint pixelFormat() @nogc @safe pure nothrow const {
		return PixelFormat.Indexed1Bit;
	}

	public IImageData convTo(uint format) @safe {
		IImageData result;
		void converter(OutputType)() @safe {
			OutputType[] array;
			array.length = data.length;
			for(int i ; i < data.length ; i++)
				array[i] = OutputType(palette.read(data[i]));
			result = new ImageData!OutputType(array, _width, _height, format, getBitDepth(format));
		}
		void upconv(OutputType)() @safe {
			IndexedImageData!OutputType iid = new IndexedImageData!OutputType(palette, _width, _height);
			for(int y ; y < _height ; y++)
				for(int x ; x < _width ; x++)
					iid[x, y] = opIndex(x, y);
			result = iid;
		}
		switch (format & ~(PixelFormat.BigEndian | PixelFormat.ValidAlpha)) {
			case PixelFormat.Indexed16Bit:
				upconv!ushort;
				break;
			case PixelFormat.Indexed8Bit:
				upconv!ubyte;
				break;
			case PixelFormat.Indexed4Bit:
				IndexedImageData4Bit iid = new IndexedImageData4Bit(palette, _width, _height);
				for(int y ; y < _height ; y++)
					for(int x ; x < _width ; x++)
						iid[x, y] = opIndex(x, y) ? 0x01 : 0x00;
				result = iid;
				break;
			case PixelFormat.Indexed2Bit:
				IndexedImageData2Bit iid = new IndexedImageData2Bit(palette, _width, _height);
				for(int y ; y < _height ; y++)
					for(int x ; x < _width ; x++)
						iid[x, y] = opIndex(x, y) ? 0x01 : 0x00;
				result = iid;
				break;
			case PixelFormat.Grayscale16Bit:
				ushort[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ushort mid = new MonochromeImageData!ushort(datastream, _width, _height, format, 16);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const RGBA_f32 pixel = readF(x,y);
						mid[x,y] = cast(ushort)((pixel.fR * 0.2125 + pixel.fG * 0.7154 + pixel.fB * 0.0721) / MonochromeImageData!ushort.fYStepping);
					}
				}
				result = mid;
				break;
			case PixelFormat.Grayscale8Bit:
				ubyte[] datastream;
				datastream.length = _width * _height;
				MonochromeImageData!ubyte mid = new MonochromeImageData!ubyte(datastream, _width, _height, format, 8);
				for (int y ; y < _height ; y++) {
					for (int x ; x < _width ; x++) {
						const RGBA_f32 pixel = readF(x,y);
						mid[x,y] = cast(ubyte)((pixel.fR * 0.2125 + pixel.fG * 0.7154 + pixel.fB * 0.0721) / MonochromeImageData!ubyte.fYStepping);
					}
				}
				result = mid;
				break;
			case PixelFormat.YX88:
				if(format & PixelFormat.BigEndian)
					converter!(YA88BE);
				else
					converter!(YA88);
				break;
			case PixelFormat.RGB888:
				if(format & PixelFormat.BigEndian)
					converter!(RGB888BE);
				else
					converter!(RGB888);
				break;
			case PixelFormat.RGBX8888:
				if(format & PixelFormat.BigEndian)
					converter!(RGBA8888BE);
				else
					converter!(RGBA8888);
				break;
			case PixelFormat.XRGB8888:
				if(format & PixelFormat.BigEndian)
					converter!(ARGB8888BE);
				else
					converter!(ARGB8888);
				break;
			case PixelFormat.RGB565:
				converter!(RGB565);
				break;
			case PixelFormat.RGBX5551:
				converter!(RGBA5551);
				break;
			default:
				throw new ImageFormatException("Format not supported");
		}
		return result;
	}

	public ARGB8888 read(uint x, uint y) @safe pure {
		return palette.read(opIndex(x, y));
	}
	public RGBA_f32 readF(uint x, uint y) @safe pure {
		return palette.readF(opIndex(x, y));
	}
	public bool opIndex(uint x, uint y) @trusted pure {
		if(x < _width && y < _height) return accessor[x + (y * _pitch)];
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	public ubyte opIndexAssign(bool val, uint x, uint y) @trusted pure {
		if(x < _width && y < _height) return accessor[x + (y * _pitch)] = val;
		else throw new ImageBoundsException("Image is being read out of bounds!");
	}
	///Flips the image horizontally
	public void flipHorizontal() @safe pure {
		for (uint y ; y < _height ; y++) {
			for (uint x ; x < _width>>>1 ; x++) {
				const bool tmp = opIndex(x, y);
				opIndexAssign(opIndex(_width - x, y), x, y);
				opIndexAssign(tmp, _width - x, y);
			}
		}
	}
	///Flips the image vertically
	public void flipVertical() @safe pure {
		import std.algorithm.mutation : swapRanges;
		for (uint y ; y < _height / 2 ; y++) {
			const uint y0 = _height - y - 1;
			ubyte[] a = data[(y * _pitch/8)..((y + 1) * _pitch/8)];
			ubyte[] b = data[(y0 * _pitch/8)..((y0 + 1) * _pitch/8)];
			swapRanges(a, b);
		}
	}
}
/**
 * All image classes should be derived from this base.
 * Implements some basic functionality, such as reading and writing pixels, basic data storage, and basic information.
 * Pixeldata should be stored decompressed, but indexing should be preserved on loading with the opinion of upconverting
 * to truecolor.
 */
abstract class Image{
	/**
	 * Contains palette data and information
	 */
	protected IPalette _palette;
	/**
	 * Contains image data and information.
	 */
	protected IImageData _imageData;
	protected ubyte mod;	///used for fast access of indexes DEPRECATED!
	protected ubyte shift;	///used for fast access of indexes DEPRECATED!

	/+protected @safe pure ubyte delegate(uint x, uint y) indexReader8Bit;		///Used for bypassing typechecking when reading pixels
	protected @safe pure ushort delegate(uint x, uint y) indexReader16bit;	///Used for bypassing typechecking when reading pixels
	protected @safe pure ubyte delegate(uint x, uint y, ubyte val) indexWriter8Bit;	///Used for bypassing typechecking when writing pixels
	protected @safe pure ushort delegate(uint x, uint y, ushort val) indexWriter16bit;	///Used for bypassing typechecking when writing pixels
	protected @safe pure ARGB8888 delegate(uint x, uint y) pixelReader;		//Used for bypassing typechecking
	protected @safe pure ARGB8888 delegate(ushort i) paletteReader;			//Used for bypassing typechecking
	+/
	
	/+protected uint	pitch;	///Contains the precalculated scanline size with the occassional padding for 8bit values.+/
	///Returns the width of the image in pixels.
	@property uint width() @nogc @safe pure nothrow const {
		return _imageData.width;
	}
	///Returns the height of the image in pixels.
	@property uint height() @nogc @safe pure nothrow const {
		return _imageData.height;
	}
	///Returns true if the image is indexed.
	@property bool isIndexed() @nogc @safe pure nothrow const {
		return _palette !is null;
	}
	///Returns the number of bits used per sample.
	@property ubyte getBitdepth() @nogc @safe pure nothrow const {
		return _imageData.bitDepth;
	}
	///Returns the number of bits used per colormap entry.
	@property ubyte getPaletteBitdepth() @nogc @safe pure nothrow const {
		if (_palette) return _palette.bitDepth;
		else return 0;
	}
	///Returns the pixelformat of the image. See enumerator `PixelFormat` for more info.
	@property uint getPixelFormat() @nogc @safe pure nothrow const {
		return _imageData.pixelFormat;
	}
	///Returns the pixelformat of the palette. See enumerator `PixelFormat` for more info.
	@property uint getPalettePixelFormat() @nogc @safe pure nothrow const {
		if (_palette) return _palette.paletteFormat;
		else return PixelFormat.Undefined;
	}
	///Returns the background color index if there's any. Returns -1 if there's no background color, -2 if background color is not indexed.
	@property int backgroundColorIndex() @nogc @safe pure nothrow const {
		return -1;
	}
	///Returns the background color if there's any, or a default value otherwise.
	@property ARGB8888 backgroundColor() @nogc @safe pure nothrow const {
		return ARGB8888.init;
	}
	/**
	 * Returns the number of planes the image have.
	 * Default is one.
	 */
	public ubyte getBitplanes() @safe pure {
		return _imageData.bitplanes;
	}
	/**
	 * Returns a palette range, which can be used to read the palette.
	 */
	public IPalette palette() @safe @property pure {
		return _palette;
	}
	/**
	 * Returns the image data.
	 */
	public IImageData imageData() @safe @property pure {
		return _imageData;
	}
	/**
	 * Reads a single 32bit pixel. If the image is indexed, a color lookup will be done.
	 */
	public ARGB8888 readPixel(uint x, uint y) @safe pure {
		return _imageData.read(x, y);
	}
	/**
	 * Looks up the index on the palette, then returns the color value as a 32 bit value.
	 */
	public ARGB8888 readPalette(size_t index) @safe pure {
		return _palette.read(index);
	}
	/**
	 * Flips the image on the vertical axis. Useful to set images to the correct top-left screen origin point.
	 */
	public void flipVertical() @safe pure {
		_imageData.flipVertical;
	}
	/**
	 * Flips the image on the vertical axis. Useful to set images to the correct top-left screen origin point.
	 */
	public void flipHorizontal() @safe pure {
		_imageData.flipVertical;
	}
	///Returns true if the image originates from the top
	public bool topOrigin() @property @nogc @safe pure const {
		return false;
	}
	///Returns true if the image originates from the right
	public bool rightSideOrigin() @property @nogc @safe pure const {
		return false;
	}
}