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
	protected size_t pitch;
	mixin ChunkyAccess4Bit;
	mixin MonochromeAccess;
	/**
	 * Creates a blank for loading.
	 */
	protected this () {

	}
	/**
	 * Creates a new bitmap from supplied data.
	 */
	public this (int width, int height, ubyte bitDepth, PixelFormat format, ) {
		
	}
	/**
	 * Loads an image from a file.
	 * Only uncompressed and 8bit RLE are supported.
	 */
	public static BMP load (F = std.stdio.file) (F file) {
		import std.math : abs;
		BMP result = new BMP();
		ubyte[] buffer;
		void loadUncompressedImageData (int bitsPerPixel, size_t width, size_t height) {
			size_t scanlineSize = (width * bitsPerPixel) / 8;
			scanlineSize += ((width * bitsPerPixel) % 32) / 8;	//Padding
			ubyte[] localBuffer;
			localBuffer.length = scanlineSize;
			for(int i ; i < height ; i++) {
				file.rawRead(localBuffer);
				assert(localBuffer.length == scanlineSize, "Scanline mismatch");
				result.imageData ~= localBuffer[0..(width * bitsPerPixel) / 8];
			}
			assert(result.imageData.length == (width * height) / 8, "Scanline mismatch");
			if (result.bitmapHeaderLength >> 16)
				assert(result.imageData.length == result.bitmapHeader.newType.sizeOfBitmap, "Size mismatch");
		}
		void load8BitRLEImageData (size_t width, size_t height) {
			size_t remaining = width * height;
			ubyte[] localBuffer;
			ubyte[] scanlineBuffer;
			localBuffer.length = 2;
			scanlineBuffer.reserve(width);
			result.imageData.reserve(width * height);
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
					result.imageData ~= scanlineBuffer;
					break;
				} else if (localBuffer[1] == 2) {	//Run offset marker
					localBuffer = file.rawRead(localBuffer);
					assert(localBuffer.length == 2, "End of File error");
					remaining -= localBuffer[0] + (localBuffer[1] * width);
					//flush current scanline
					scanlineBuffer.length = width;
					result.imageData ~= scanlineBuffer;
					while (localBuffer[1]) {
						localBuffer[1]--;
						result.imageData ~= new ubyte[](width);
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
					result.imageData ~= scanlineBuffer;
					//clear current scanline
					scanlineBuffer.length = 0;
				}
			}
			result.imageData.length = width * height;
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
			switch (bitsPerPixel) {
				case 1:
					result.paletteData.length = 2 * bytesPerPaletteEntry;
					break;
				case 4:
					result.paletteData.length = 16 * bytesPerPaletteEntry;
					break;
				case 8:
					result.paletteData.length = 256 * bytesPerPaletteEntry;
					break;
				default:
					return;
			}
			result.paletteData = file.rawRead(result.paletteData);
		}
		buffer.length = 2;
		buffer = file.rawRead(buffer);
		result.fileVersionIndicator = reinterpretGet!ushort(buffer);
		//Decide file version, if first two byte is "BM" it's 2.0 or later, if not it's 1.x
		if (!result.fileVersionIndicator) {
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
		result.setupDelegates();
		return result;
	}
	///Saves the image into the given file.
	///Only uncompressed bitmaps are supported currently.
	public void save (F = std.stdio.file)(F file) {
		ubyte[] buffer;
		void saveUncompressed () {
			const size_t pitch = (width * bitDepth) / 8;
			for (int i ; i < height ; i++) {
				buffer = imageData[pitch * i .. pitch * (i + 1)];
				while (buffer.length & 0b0000_0011) 
					buffer ~= 0b0;
				file.rawWrite(buffer);
			}
		}
		void saveWin3xHeader () {
			buffer = reinterpretCast!ubyte([BMPTYPE]);
				file.rawWrite(buffer);
				buffer = reinterpretCast!ubyte([header.newType]);
				file.rawWrite(buffer);
				buffer = reinterpretCast!ubyte([bitmapHeaderLength]);
				buffer ~= reinterpretCast!ubyte([bitmapHeader.newType]);
				file.rawWrite(buffer);
		}
		buffer.length = 2;
		switch (bitmapHeaderLength) {
			case BMPVersion.Win2X:
				buffer = reinterpretCast!ubyte([BMPTYPE]);
				file.rawWrite(buffer);
				buffer = reinterpretCast!ubyte([header.newType]);
				file.rawWrite(buffer);
				buffer = reinterpretCast!ubyte([bitmapHeaderLength]);
				buffer ~= reinterpretCast!ubyte([bitmapHeader.oldType]);
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
				buffer = reinterpretCast!ubyte([headerExt.longext]);
				file.rawWrite(buffer);
				if (paletteData.length)
					file.rawWrite(paletteData);
				saveUncompressed;
				break;
			case BMPVersion.WinNT:
				saveWin3xHeader();
				buffer = reinterpretCast!ubyte([headerExt.shortext]);
				file.rawWrite(buffer);
				if (paletteData.length)
					file.rawWrite(paletteData);
				saveUncompressed;
				break;
			default:		//Must be Win1X
				file.rawWrite(buffer);
				buffer = reinterpretCast!ubyte([header.oldType]);
				file.rawWrite(buffer);
				saveUncompressed;
				break;
		}
	}
	/**
	 * Sets up all the function pointers automatically.
	 */
	protected void setupDelegates() @safe pure {
		switch (getPixelFormat) {
			case PixelFormat.Indexed1Bit:
				indexReader8Bit = &_readIndex_1bit;
				indexWriter8Bit = &_writeIndex_1bit;
				indexReader16bit = &_indexReadUpconv;
				pixelReader = &_readAndLookup;
				pitch = width + width % 8 ? 8 - (width % 8) : 0;
				break;
			case PixelFormat.Indexed4Bit:
				indexReader8Bit = &_readIndex_4bit;
				indexWriter8Bit = &_writeIndex_4bit;
				indexReader16bit = &_indexReadUpconv;
				pixelReader = &_readAndLookup;
				pitch = width + width % 2 ? 1 : 0;
				break;
			case PixelFormat.Indexed8Bit:
				indexReader8Bit = &_readPixel_8bit;
				indexWriter8Bit = &_writePixel!(ubyte);
				indexReader16bit = &_indexReadUpconv;
				pixelReader = &_readAndLookup;
				break;
			case PixelFormat.RGBA8888, PixelFormat.RGBX8888:
				pixelReader = &_readPixelAndUpconv!(Pixel32BitRGBALE);
				break;
			case PixelFormat.RGB888:
				pixelReader = &_readPixelAndUpconv!(Pixel24Bit);
				break;
			default:
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
					return PixelFormat.RGB565 || bitmapHeaderLength == 4 + Win3xBitmapHeader.sizeof + WinNTBitmapHeaderExt.sizeof ? 
							PixelFormat.BigEndian : 0;
				else
					return PixelFormat.RGBX5551 || bitmapHeaderLength == 4 + Win3xBitmapHeader.sizeof + WinNTBitmapHeaderExt.sizeof ? 
							PixelFormat.BigEndian : 0;
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
	{
		std.stdio.File testFile1 = std.stdio.File("./test/bmp/TRU256.BMP");
		BMP test = BMP.load(testFile1);
	}
}