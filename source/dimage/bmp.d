/*
 * dimage - bmp.d
 * by Laszlo Szeremi
 *
 * Copyright under Boost Software License.
 */

module dimage.bmp;

import dimage.base;
import dimage.util;

/**
 * Implements *.BMP file handling.
 */
public class BMP : Image {
	static enum ushort WIN1XTYPE = 0;			///Defines Windows 1.x files
	static enum ushort BMPTYPE = 0x4D42;		///Defines later versions of the file
	/**
	 * Mostly used during construction of new instances and version changing.
	 */
	public enum BMPVersion {
		Win1X,		///256 color max
		Win2X,		///256 color max
		Win3X,		///24M color, no alpha channel
		WinNT,		///24M color, no alpha channel
		Win4X,		///Alpha channel enabled
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
	protected ushort fileVersionIndicator;
	/**
	 * Windows 1.x header
	 */
	public struct Win1XHeader {
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
		Win1XHeader		oldType;
		WinBMPHeader	newType;
	}
	protected uint bitmapHeaderLength;
	/**
	 * Bitmap header for Win 2.x
	 */
	public struct Win2XBitmapHeader {
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
		Win2XBitmapHeader	oldType;
		Win3xBitmapHeader	newType;
	}
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
	/**
	 * Creates a blank for loading.
	 */
	protected this(){

	}
	/**
	 * Creates a new bitmap from supplied data.
	 */
	public this(int width, int height, ubyte bitDepth, PixelFormat format, ){
		
	}
}