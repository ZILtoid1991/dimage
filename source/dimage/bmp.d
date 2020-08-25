/*
 * dimage - bmp.d
 * by Laszlo Szeremi
 *
 * Copyright under Boost Software License.
 */

module dimage.bmp;

import dimage.base;
import dimage.util;
static import std.stdio;
import bitleveld.datatypes;
import std.bitmanip;

/**
 * Implements *.BMP file handling.
 */
public class BMP : Image {
	static enum ushort WIN1XTYPE = 0;			///Defines Windows 1.x files
	static enum ushort BMPTYPE = 0x4D42;		///Defines later versions of the file
	/**
	 * Mostly used during construction of new instances and version changing.
	 */
	public enum BMPVersion : uint {
		Win1X	=	0,		///256 color max
		Win2X	=	4 + Win2xBitmapHeader.sizeof,		///256 color max
		Win3X	=	4 + Win3xBitmapHeader.sizeof,		///24M color, no alpha channel
		WinNT	=	4 + Win3xBitmapHeader.sizeof + WinNTBitmapHeaderExt.sizeof,		///24M color, no alpha channel
		Win4X	=	4 + Win3xBitmapHeader.sizeof + Win4xBitmapHeaderExt.sizeof,		///Alpha channel enabled
	}
	/**
	 * Stores compression type identificator.
	 */
	public enum CompressionType {
		None		=	0,
		RLE8Bit		=	1,
		RLE4Bit		=	2,
		Bitfields	=	3,
	}
	protected ushort fileVersionIndicator;	///Null if Win1x
	/**
	 * Windows 1.x header
	 */
	public struct Win1xHeader {
		ushort		width;		///Width of the bitmap
		ushort		height;		///Height of the bitmap
		ushort		byteWidth;	///Width of the bitmap in bytes
		ubyte		planes;		///Number of color planes
		ubyte		bitsPerPixel;	///Number of bits per pixel
	}
	/**
	 * Header used in later versions
	 */
	public struct WinBMPHeader {
		uint		fileSize;	///Size of the file in bytes
		ushort		reserved1;	///Always 0
		ushort		reserved2;	///Always 0
		uint		bitmapOffset;	///Starting position of bitmap in file in bytes
	}
	protected union Header{
		Win1xHeader		oldType;
		WinBMPHeader	newType;
	}
	protected Header header;
	protected uint bitmapHeaderLength;
	/**
	 * Bitmap header for Win 2.x
	 */
	public struct Win2xBitmapHeader {
		//uint		size = Win2XBitmapHeader.sizeof;	///Size of this header in bytes
		short		width; 		///Width of the bitmap
		short		height;		///Height of the bitmap
		ushort		planes;		///Number of color planes
		ushort		bitsPerPixel;	///Number of bits per pixel
	}
	/**
	 * Bitmap header for Win 3.x and 4.x
	 */
	public struct Win3xBitmapHeader {
		int			width; 		///Width of the bitmap
		int			height;		///Height of the bitmap
		ushort		planes;		///Number of color planes
		ushort		bitsPerPixel;	///Number of bits per pixel

		uint		compression;	///Compression methods used
		uint		sizeOfBitmap;	///Size of bitmap in bytes
		int			horizResolution;///Pixels per meter
		int			vertResolution;	///Pixels per meter
		uint		colorsUsed;		///Colors used in image
		uint		colorsimportant;///Colors important to display the image
	}
	protected union BitmapHeader {
		Win2xBitmapHeader	oldType;
		Win3xBitmapHeader	newType;
	}
	protected BitmapHeader bitmapHeader;
	/**
	 * Bitmap header extension for Win 4.x
	 */
	public struct Win4xBitmapHeaderExt {
		uint		redMask;		///Mask identifying red component
		uint		greenMask;		///Mask identifying green component
		uint		blueMask;		///Mask identifying blue component
		uint		alphaMask;		///Mask identifying alpha component
		uint		csType;			///Color space type
		int			redX;			///X coordinate of red endpoint
		int			redY;			///Y coordinate of red endpoint
		int			redZ;			///Z coordinate of red endpoint
		int			greenX;			///X coordinate of green endpoint
		int			greenY;			///Y coordinate of green endpoint
		int			greenZ;			///Z coordinate of green endpoint
		int			blueX;			///X coordinate of blue endpoint
		int			blueY;			///Y coordinate of blue endpoint
		int			blueZ;			///Z coordinate of blue endpoint
		uint		gammaRed;		///Gamma red coordinate scale
		uint		gammaGreen;		///Gamma green coordinate scale
		uint		gammaBlue;		///Gamma blue coordinate scale
	}
	/**
	 * Bitmap header extension for WinNT
	 */
	public struct WinNTBitmapHeaderExt {
		uint		redMask;		///Mask identifying red component
		uint		greenMask;		///Mask identifying green component
		uint		blueMask;		///Mask identifying blue component
	}
	protected union HeaderExt {
		Win4xBitmapHeaderExt	longext;
		WinNTBitmapHeaderExt	shortext;
	}
	protected HeaderExt headerExt;
	//protected size_t pitch;
	/**
	 * Creates a blank for loading.
	 */
	protected this () {

	}
	/**
	 * Creates a new bitmap from supplied data.
	 */
	public this (IImageData imgDat, IPalette pal = null, BMPVersion vers = BMPVersion.Win4X) @safe pure {
		if (vers == BMPVersion.Win2X) {
			if (pal) {
				if (pal.paletteFormat != PixelFormat.RGB888) throw new ImageFormatException("Unsupported palette format!");
				if (!(imgDat.pixelFormat == PixelFormat.Indexed1Bit || imgDat.pixelFormat == PixelFormat.Indexed4Bit || 
						imgDat.pixelFormat == PixelFormat.Indexed8Bit)) throw new ImageFormatException("Image format not supported by this
						version of BMP!");
				bitmapHeaderLength = vers;
				_imageData = imgDat;
				_palette = pal;
				bitmapHeader.oldType.width = cast(short)_imageData.width;
				bitmapHeader.oldType.height = cast(short)_imageData.height;
				bitmapHeader.oldType.planes = 1;
				bitmapHeader.oldType.bitsPerPixel = _imageData.bitDepth;
				header.newType.bitmapOffset = cast(uint)pal.raw.length;
			} else throw new ImageFormatException("This version of BMP must have a palette!");
		} else if (vers == BMPVersion.Win1X) {
			if (pal) throw new ImageFormatException("This version of BMP doesn't have a palette!");
			_imageData = imgDat;
			header.oldType.width = cast(ushort)_imageData.width;
			header.oldType.height = cast(ushort)_imageData.height;
			header.oldType.byteWidth = cast(ushort)(_imageData.width * 8 / _imageData.bitDepth);
			if (_imageData.bitDepth == 4 && _imageData.width & 1) header.oldType.byteWidth++;
			if (_imageData.bitDepth == 1 && _imageData.width & 7) header.oldType.byteWidth++;
			header.oldType.bitsPerPixel = _imageData.bitDepth;
			header.oldType.planes = 1;
		} else {
			if (pal) {
				if (pal.paletteFormat != PixelFormat.XRGB8888) throw new ImageFormatException("Unsupported palette format!");
				if (!(imgDat.pixelFormat == PixelFormat.Indexed1Bit || imgDat.pixelFormat == PixelFormat.Indexed4Bit || 
						imgDat.pixelFormat == PixelFormat.Indexed8Bit)) throw new ImageFormatException("Unsupported indexed image type!");
				_palette = pal;
				header.newType.bitmapOffset = cast(uint)pal.raw.length;
			} else {
				if (!(imgDat.pixelFormat == PixelFormat.RGB888 || imgDat.pixelFormat == PixelFormat.ARGB8888 || 
						imgDat.pixelFormat == PixelFormat.RGB565 || imgDat.pixelFormat == PixelFormat.RGBA5551)) throw new 
						ImageFormatException("Unsupported truecolor image type!");
			}
			_imageData = imgDat;
			bitmapHeaderLength = vers;
			bitmapHeader.newType.planes = 1;
			bitmapHeader.newType.compression = 0;
			bitmapHeader.newType.bitsPerPixel = _imageData.bitDepth;
			bitmapHeader.newType.width = _imageData.width;
			bitmapHeader.newType.height = _imageData.height;
			bitmapHeader.newType.horizResolution = 72;
			bitmapHeader.newType.vertResolution = 72;
			bitmapHeader.newType.colorsUsed = 1 << bitmapHeader.newType.bitsPerPixel;
			bitmapHeader.newType.colorsimportant = bitmapHeader.newType.colorsUsed; //ALL THE COLORS!!! :)
			if (vers == BMPVersion.Win4X || vers == BMPVersion.WinNT) {
				switch(_imageData.pixelFormat) {
					case PixelFormat.RGB565:
						headerExt.longext.redMask = 0xF8_00_00_00;
						headerExt.longext.greenMask = 0x07_E0_00_00;
						headerExt.longext.blueMask = 0x00_1F_00_00;
						break;
					case PixelFormat.RGBX5551:
						headerExt.longext.redMask = 0xF8_00_00_00;
						headerExt.longext.greenMask = 0x07_C0_00_00;
						headerExt.longext.blueMask = 0x00_3E_00_00;
						break;
					case PixelFormat.RGB888:
						headerExt.longext.redMask = 0xff_00_00_00;
						headerExt.longext.greenMask = 0x00_ff_00_00;
						headerExt.longext.blueMask = 0x00_00_ff_00;
						break;
					case PixelFormat.ARGB8888:
						headerExt.longext.alphaMask = 0xff_00_00_00;
						headerExt.longext.redMask = 0x00_ff_00_00;
						headerExt.longext.greenMask = 0x00_00_ff_00;
						headerExt.longext.blueMask = 0x00_00_00_ff;
						break;
					default: break;
				}
			}
		}
		if (vers != BMPVersion.Win1X) {
			header.newType.bitmapOffset += 2 + WinBMPHeader.sizeof + bitmapHeaderLength;
			header.newType.fileSize = header.newType.bitmapOffset + cast(uint)_imageData.raw.length;
		}
	}
	/**
	 * Loads an image from a file.
	 * Only uncompressed and 8bit RLE are supported.
	 */
	public static BMP load (F = std.stdio.file) (ref F file) {
		import std.math : abs;
		BMP result = new BMP();
		ubyte[] buffer, imageBuffer;
		void loadUncompressedImageData (int bitsPerPixel, size_t width, size_t height) {
			size_t scanlineSize = (width * bitsPerPixel) / 8;
			scanlineSize += ((width * bitsPerPixel) % 32) / 8;	//Padding
			ubyte[] localBuffer;
			localBuffer.length = scanlineSize;
			for(int i ; i < height ; i++) {
				file.rawRead(localBuffer);
				assert(localBuffer.length == scanlineSize, "Scanline mismatch");
				imageBuffer ~= localBuffer[0..(width * bitsPerPixel) / 8];
			}
			//assert(imageBuffer.length == (width * height) / 8, "Scanline mismatch");
			if (result.bitmapHeaderLength >> 16)
				assert(imageBuffer.length == result.bitmapHeader.newType.sizeOfBitmap, "Size mismatch");
		}
		void load8BitRLEImageData (size_t width, size_t height) {
			size_t remaining = width * height;
			ubyte[] localBuffer;
			ubyte[] scanlineBuffer;
			localBuffer.length = 2;
			scanlineBuffer.reserve(width);
			imageBuffer.reserve(width * height);
			while (remaining) {
				localBuffer = file.rawRead(localBuffer);
				assert(localBuffer.length == 2, "End of File error");
				if (localBuffer[0]) {	//Run length encoding
					while (localBuffer[0]) {
						localBuffer[0]--;
						scanlineBuffer ~= localBuffer[1];
					}
				} else if (localBuffer[1] == 1) {	//End of bitmap data marker
					//flush current scanline
					scanlineBuffer.length = width;
					imageBuffer ~= scanlineBuffer;
					break;
				} else if (localBuffer[1] == 2) {	//Run offset marker
					localBuffer = file.rawRead(localBuffer);
					assert(localBuffer.length == 2, "End of File error");
					remaining -= localBuffer[0] + (localBuffer[1] * width);
					//flush current scanline
					scanlineBuffer.length = width;
					imageBuffer ~= scanlineBuffer;
					while (localBuffer[1]) {
						localBuffer[1]--;
						imageBuffer ~= new ubyte[](width);
					}
					//clear current scanline
					scanlineBuffer.length = 0;
					while (localBuffer[0]) {
						localBuffer[0]--;
						scanlineBuffer ~= 0;
					}
				} else if (localBuffer[1]) {		//Raw data
					buffer.length = localBuffer[1];
					buffer = file.rawRead(buffer);
					scanlineBuffer ~= buffer;
					if (localBuffer[1] & 1)
						file.seek(1, std.stdio.SEEK_CUR);
				} else {	//End of scanline
					scanlineBuffer.length += width - (scanlineBuffer.length % width);
					//flush current scanline
					scanlineBuffer.length = width;
					imageBuffer ~= scanlineBuffer;
					//clear current scanline
					scanlineBuffer.length = 0;
				}
			}
			imageBuffer.length = width * height;
		}
		void loadImageDataWin3x () {
			switch (result.bitmapHeader.newType.compression) {
				case CompressionType.None:
					loadUncompressedImageData (result.bitmapHeader.newType.bitsPerPixel, abs(result.bitmapHeader.newType.width), 
							abs(result.bitmapHeader.newType.height));
					break;
				default:
					break;
			}
		}
		void loadHeaderWin3x () {
			buffer.length = Win3xBitmapHeader.sizeof;
			buffer = file.rawRead(buffer);
			result.bitmapHeader.newType = reinterpretGet!Win3xBitmapHeader(buffer);
		}
		void loadPalette (int bitsPerPixel, int bytesPerPaletteEntry) {
			ubyte[] paletteBuffer;
			switch (bitsPerPixel) {
				case 1:
					paletteBuffer.length = 2 * bytesPerPaletteEntry;
					break;
				case 4:
					paletteBuffer.length = 16 * bytesPerPaletteEntry;
					break;
				case 8:
					paletteBuffer.length = 256 * bytesPerPaletteEntry;
					break;
				default:
					return;
			}
			paletteBuffer = file.rawRead(paletteBuffer);
			if(bytesPerPaletteEntry == 3) {
				result._palette = new Palette!RGB888(reinterpretCast!RGB888(paletteBuffer), PixelFormat.RGB888, 24);
			} else {
				result._palette = new Palette!ARGB8888(reinterpretCast!ARGB8888(paletteBuffer), PixelFormat.XRGB8888, 32);
			}
		}
		buffer.length = 2;
		buffer = file.rawRead(buffer);
		result.fileVersionIndicator = reinterpretGet!ushort(buffer);
		//Decide file version, if first two byte is "BM" it's 2.0 or later, if not it's 1.x
		if (result.fileVersionIndicator) {
			buffer.length = WinBMPHeader.sizeof;
			buffer = file.rawRead(buffer);
			result.header.newType = reinterpretGet!WinBMPHeader(buffer);
			buffer.length = 4;
			buffer = file.rawRead(buffer);
			result.bitmapHeaderLength = reinterpretGet!uint(buffer);
			switch (result.bitmapHeaderLength) {
				case Win2xBitmapHeader.sizeof + 4:
					buffer.length = Win2xBitmapHeader.sizeof;
					buffer = file.rawRead(buffer);
					result.bitmapHeader.oldType = reinterpretGet!Win2xBitmapHeader(buffer);
					if (result.isIndexed) {
						loadPalette(result.bitmapHeader.oldType.bitsPerPixel, 3);
					}
					loadUncompressedImageData(result.bitmapHeader.oldType.bitsPerPixel, abs(result.bitmapHeader.oldType.width), 
							abs(result.bitmapHeader.oldType.height));
					break;
				case Win3xBitmapHeader.sizeof + 4:
					loadHeaderWin3x();
					if (result.isIndexed) {
						loadPalette(result.bitmapHeader.newType.bitsPerPixel, 4);
					}
					loadImageDataWin3x();
					break;
				//Check for WinNT or Win4x header extensions
				case Win3xBitmapHeader.sizeof + 4 + WinNTBitmapHeaderExt.sizeof:
					loadHeaderWin3x();
					buffer.length = WinNTBitmapHeaderExt.sizeof;
					buffer = file.rawRead(buffer);
					result.headerExt.shortext = reinterpretGet!WinNTBitmapHeaderExt(buffer);
					if (result.isIndexed) {
						loadPalette(result.bitmapHeader.newType.bitsPerPixel, 4);
					}
					loadImageDataWin3x();
					break;
				case Win3xBitmapHeader.sizeof + 4 + Win4xBitmapHeaderExt.sizeof:
					loadHeaderWin3x();
					buffer.length = Win4xBitmapHeaderExt.sizeof;
					buffer = file.rawRead(buffer);
					result.headerExt.longext = reinterpretGet!Win4xBitmapHeaderExt(buffer);
					if (result.isIndexed) {
						loadPalette(result.bitmapHeader.newType.bitsPerPixel, 4);
					}
					loadImageDataWin3x();
					break;
				default:
					throw new Exception("File error!");
			}
			
		} else {
			buffer.length = Win1xHeader.sizeof;
			buffer = file.rawRead(buffer);
			result.header.oldType = reinterpretGet!Win1xHeader(buffer);
			loadUncompressedImageData(result.header.oldType.bitsPerPixel, result.header.oldType.width, 
					result.header.oldType.height);
		}
		//Set up image data
		//std.stdio.writeln(result.getPixelFormat);
		switch (result.getPixelFormat) {
			case PixelFormat.Indexed1Bit:
				result._imageData = new IndexedImageData1Bit(imageBuffer, result._palette, result.width, result.height);
				break;
			case PixelFormat.Indexed4Bit:
				result._imageData = new IndexedImageData4Bit(imageBuffer, result._palette, result.width, result.height);
				break;
			case PixelFormat.Indexed8Bit:
				result._imageData = new IndexedImageData!ubyte(imageBuffer, result._palette, result.width, result.height);
				break;
			case PixelFormat.RGB565:
				result._imageData = new ImageData!RGB565(reinterpretCast!RGB565(imageBuffer), result.width, result.height, 
						PixelFormat.RGB565, 16);
				break;
			case PixelFormat.RGBX5551:
				result._imageData = new ImageData!RGBA5551(reinterpretCast!RGBA5551(imageBuffer), result.width, result.height, 
						PixelFormat.RGBA5551, 16);
				break;
			case PixelFormat.RGB888:
				result._imageData = new ImageData!RGB888(reinterpretCast!RGB888(imageBuffer), result.width, result.height, 
						PixelFormat.RGB888, 24);
				break;
			case PixelFormat.ARGB8888:
				result._imageData = new ImageData!ARGB8888(reinterpretCast!ARGB8888(imageBuffer), result.width, result.height, 
						PixelFormat.ARGB8888, 32);
				break;
			default: throw new ImageFileException("Unknown image format!");
		}
		return result;
	}
	///Saves the image into the given file.
	///Only uncompressed bitmaps are supported currently.
	public void save (F = std.stdio.file)(ref F file) {
		ubyte[] buffer, paletteData;
		if (_palette) paletteData = _palette.raw;
		void saveUncompressed () {
			const size_t pitch = (width * getBitdepth) / 8;
			ubyte[] imageBuffer = _imageData.raw;
			for (int i ; i < height ; i++) {
				buffer = imageBuffer[pitch * i .. pitch * (i + 1)];
				while (buffer.length & 0b0000_0011) 
					buffer ~= 0b0;
				file.rawWrite(buffer);
			}
		}
		void saveWin3xHeader () {
			buffer = reinterpretAsArray!ubyte(BMPTYPE);
				file.rawWrite(buffer);
				buffer = reinterpretAsArray!ubyte(header.newType);
				file.rawWrite(buffer);
				buffer = reinterpretAsArray!ubyte(bitmapHeaderLength);
				buffer ~= reinterpretAsArray!ubyte(bitmapHeader.newType);
				file.rawWrite(buffer);
		}
		buffer.length = 2;
		switch (bitmapHeaderLength) {
			case BMPVersion.Win2X:
				buffer = reinterpretAsArray!ubyte(BMPTYPE);
				file.rawWrite(buffer);
				buffer = reinterpretAsArray!ubyte(header.newType);
				file.rawWrite(buffer);
				buffer = reinterpretAsArray!ubyte(bitmapHeaderLength);
				buffer ~= reinterpretAsArray!ubyte(bitmapHeader.oldType);
				file.rawWrite(buffer);
				if (paletteData.length)
					file.rawWrite(paletteData);
				saveUncompressed;
				break;
			case BMPVersion.Win3X:
				saveWin3xHeader();
				if (paletteData.length)
					file.rawWrite(paletteData);
				saveUncompressed;
				break;
			case BMPVersion.Win4X:
				saveWin3xHeader();
				buffer = reinterpretAsArray!ubyte(headerExt.longext);
				file.rawWrite(buffer);
				if (paletteData.length)
					file.rawWrite(paletteData);
				saveUncompressed;
				break;
			case BMPVersion.WinNT:
				saveWin3xHeader();
				buffer = reinterpretAsArray!ubyte(headerExt.shortext);
				file.rawWrite(buffer);
				if (paletteData.length)
					file.rawWrite(paletteData);
				saveUncompressed;
				break;
			default:		//Must be Win1X
				file.rawWrite(buffer);
				buffer = reinterpretAsArray!ubyte(header.oldType);
				file.rawWrite(buffer);
				saveUncompressed;
				break;
		}
	}
	override uint width() @nogc @safe @property const pure {
		import std.math : abs;
		if (fileVersionIndicator) {
			if (bitmapHeaderLength == Win2xBitmapHeader.sizeof + 4) {
				return abs(bitmapHeader.oldType.width);
			} else {
				return abs(bitmapHeader.newType.width);
			}
		}
		return header.oldType.width;
	}
	override uint height() @nogc @safe @property const pure {
		import std.math : abs;
		if (fileVersionIndicator) {
			if (bitmapHeaderLength == Win2xBitmapHeader.sizeof + 4) {
				return abs(bitmapHeader.oldType.height);
			} else {
				return abs(bitmapHeader.newType.height);
			}
		}
		return header.oldType.height;
	}
	override bool isIndexed() @nogc @safe @property const pure {
		if (fileVersionIndicator) {
			if (bitmapHeaderLength == Win2xBitmapHeader.sizeof + 4) {
				if (bitmapHeader.oldType.bitsPerPixel != 24)
					return true;
				else
					return false;
			} else {
				if (bitmapHeader.newType.bitsPerPixel <= 8)
					return true;
				else
					return false;
			}
		}
		return true;
	}
	override ubyte getBitdepth() @nogc @safe @property const pure {
		if (fileVersionIndicator) {
			if (bitmapHeaderLength == Win2xBitmapHeader.sizeof + 4) {
				return cast(ubyte)bitmapHeader.oldType.bitsPerPixel;
			} else {
				return cast(ubyte)bitmapHeader.newType.bitsPerPixel;
			}
		}
		return header.oldType.bitsPerPixel;
	}
	override ubyte getPaletteBitdepth() @nogc @safe @property const pure {
		if (fileVersionIndicator) {
			if (bitmapHeaderLength == Win2xBitmapHeader.sizeof + 4) {
				if (isIndexed)
					return 24;
			} else {
				if (isIndexed)
					return 32;
			}
		}
		return 0;
	}
	override uint getPixelFormat() @nogc @safe @property const pure {
		switch (getBitdepth()) {
			case 1:
				return PixelFormat.Indexed1Bit;
			case 4:
				return PixelFormat.Indexed4Bit;
			case 8:
				return PixelFormat.Indexed8Bit;
			case 16:
				if (headerExt.shortext.redMask == 0xF8000000 && headerExt.shortext.greenMask == 0x07E00000 && 
						headerExt.shortext.blueMask == 0x001F0000)
					return PixelFormat.RGB565 | (bitmapHeaderLength == 4 + Win3xBitmapHeader.sizeof + WinNTBitmapHeaderExt.sizeof ? 
							PixelFormat.BigEndian : 0);
				else
					return PixelFormat.RGBX5551 | (bitmapHeaderLength == 4 + Win3xBitmapHeader.sizeof + WinNTBitmapHeaderExt.sizeof ? 
							PixelFormat.BigEndian : 0);
			case 24:
				return PixelFormat.RGB888;
			case 32:
				return PixelFormat.ARGB8888;
			default:
				return PixelFormat.Undefined;
		}
	}
	override uint getPalettePixelFormat() @nogc @safe @property const pure {
		if (fileVersionIndicator) {
			if (bitmapHeaderLength == Win2xBitmapHeader.sizeof + 4) {
				if (isIndexed)
					return PixelFormat.RGB888;
			} else {
				if (isIndexed)
					return PixelFormat.XRGB8888;
			}
		}
		return PixelFormat.Undefined;
	}
}

unittest {
	import vfile;
	{
		std.stdio.File testFile1 = std.stdio.File("./test/bmp/TRU256.BMP");
		std.stdio.File testFile2 = std.stdio.File("./test/bmp/TRU256_I.BMP");
		BMP test1 = BMP.load(testFile1);
		BMP test2 = BMP.load(testFile2);
		compareImages!true(test1, test2);
		VFile backup1, backup2;
		test1.save(backup1);
		test2.save(backup2);
		backup1.seek(0);
		backup2.seek(0);
		BMP test01 = BMP.load(backup1);
		BMP test02 = BMP.load(backup2);
		compareImages!true(test1, test01);
		compareImages!true(test2, test02);
	}
}