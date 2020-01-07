/*
 * dimage - pcx.d
 * by Laszlo Szeremi
 *
 * Copyright under Boost Software License.
 */

module dimage.pcx;

import dimage.base;
import dimage.util;
static import std.stdio;
import bitleveld.datatypes;
import std.bitmanip;

/**
 * Implements ZSoft PCX file handling.
 */
public class PCX : Image {
	/**
	 * Version information
	 */
	public enum Version : ubyte {
		ver2_5				=	0,
		ver2_8				=	2,
		ver2_8noPal			=	3,
		paintbrushForWin	=	4,
		ver3_0				=	5,
	}
	/**
	 * Implementation of the PCX header
	 */
	public struct Header {
		ubyte	identifier	=	0x0A;	///PCX ID number
		ubyte	_version;				///Version number
		ubyte	encoding;				///Encoding format
		ubyte	bitsPerPixel;			///Bits per pixel
		ushort	xStart;					///Left of image
		ushort	yStart;					///Top of image
		ushort	xEnd;					///Right of image
		ushort	yEnd;					///Bottom of image
		ushort	hRes;					///Horizontal resolution
		ushort	vRes;					///Vertical resolution
		ubyte[48]	palette;			///16-Color EGA palette
		ubyte	reserved1;				///Unused padding
		ubyte	numBitPlanes;			///N of bitplanes
		ushort	bytesPerLine;			///Size of scanlines in bytes
		ushort	paletteType;			///Palette type
		ushort	hScreenSize;			///Horizontal screen size
		ushort	vScreenSize;			///Vertical screen size
		ubyte	reserved2;				///Unused padding
	}
	protected Header	header;		///Contains common information about the image
	protected uint		pitch;
	mixin PlanarAccess3Bit;
	mixin PlanarAccess4Bit;
	mixin ChunkyAccess2Bit;
	mixin MonochromeAccess;
	/**
	 * Blank constructor for files
	 */
	protected this() @nogc @safe pure {

	}
	/**
	 * Basic constructor to create pcx objects
	 */
	public this(Header header, ubyte[] imageData, ubyte[] paletteData = []){
		//Validate header
		this.header = header;
		if (getPixelFormat == PixelFormat.Undefined) {
			throw new ImageFormatException("Unsupported pixelformat.");
		}
		//Force set version
		switch (getPixelFormat) {
			case PixelFormat.Indexed2Bit, PixelFormat.Indexed1Bit:
				this.header._version = Version.ver2_5;
				break;
			case PixelFormat.Indexed8Bit, PixelFormat.RGB888, PixelFormat.RGBA8888:
				this.header._version = Version.ver3_0;
				break;
			case PixelFormat.Planar8Color:
				this.header._version = Version.paintbrushForWin;
				break;
			default:
				if (paletteData.length) {
					this.header._version = Version.ver2_8;
				} else {
					this.header._version = Version.ver2_8noPal;
				}
				break;
		}
		if (paletteData.length <= 48) {
			for (int i ; i < paletteData.length ; i++) {
				this.header.palette[i] = paletteData[i];
			}
			this.paletteData = this.header.palette[0..$];
		} else {
			this.paletteData = paletteData;
		}
	}
	/**
	 * Loads a *.PCX file.
	 */
	public static load (F = std.stdio.File) (F file) {
		PCX result = new PCX();
		ubyte[] buffer;
		buffer.length = Header.sizeof;
		buffer = file.rawRead(buffer);
		if (buffer.length != Header.sizeof) 
			throw new ImageFormatException ("File is corrupted, cannot be read, and/or is not a *.PCX file!");
		result.header = reinterpretGet!Header(buffer);
		buffer.length = result.header.bytesPerLine;
		for (int y ; y < result.height ; y++){
			buffer = file.rawRead(buffer);
			if (buffer.length == result.header.bytesPerLine)
				result.imageData ~= buffer;
			else
				throw new ImageFormatException ("File is corrupted, cannot be read, and/or is not a *.PCX file!");
		}
		if (file.size - file.tell) {
			result.paletteData.length = 768;
			result.paletteData = file.rawRead(result.paletteData);
			if (result.paletteData.length == 768)
				throw new ImageFormatException ("File is corrupted, cannot be read, and/or is not a *.PCX file!");
		}
		return result;
	}
	protected void setupDelegates() @nogc @safe pure {
		switch (getPixelFormat) {
			case PixelFormat.Indexed1Bit:
				indexReader8Bit = &_readIndex_1bit;
				indexWriter8Bit = &_writeIndex_1bit;
				indexReader16bit = &_indexReadUpconv;
				pixelReader = &_readAndLookup;
				break;
			case PixelFormat.Indexed2Bit:
				indexReader8Bit = &_readIndex_2bit;
				indexWriter8Bit = &_writeIndex_2bit;
				indexReader16bit = &_indexReadUpconv;
				pixelReader = &_readAndLookup;
				break;
			case PixelFormat.Indexed8Bit:
				indexReader8Bit = &_readPixel_8bit;
				indexWriter8Bit = &_writePixel!(ubyte);
				indexReader16bit = &_indexReadUpconv;
				pixelReader = &_readAndLookup;
				break;
			case PixelFormat.Planar8Color:
				indexReader8Bit = &_readIndex_planar_3bit;
				indexWriter8Bit = &_writeIndex_planar_3bit;
				indexReader16bit = &_indexReadUpconv;
				pixelReader = &_readAndLookup;
				break;
			case PixelFormat.Planar16Color:
				indexReader8Bit = &_readIndex_planar_4bit;
				indexWriter8Bit = &_writeIndex_planar_4bit;
				indexReader16bit = &_indexReadUpconv;
				pixelReader = &_readAndLookup;
				break;
			case PixelFormat.RGB888:
				pixelReader = &_readPixelAndUpconv!(Pixel24Bit);
				break;
			case PixelFormat.RGBA8888:
				pixelReader = &_readPixelAndUpconv!(Pixel32BitRGBALE);
				break;
			default:
				break;
		}
	}
	override uint width() @nogc @safe @property const pure {
		return header.hRes;
	}
	override uint height() @nogc @safe @property const pure {
		return header.vRes;
	}
	override bool isIndexed() @nogc @safe @property const pure {
		return header.bitsPerPixel != 8 || header.numBitPlanes == 1;
	}
	override ubyte getBitdepth() @nogc @safe @property const pure {
		return cast(ubyte)(header.bitsPerPixel * header.numBitPlanes);
	}
	override ubyte getPaletteBitdepth() @nogc @safe @property const pure {
		return isIndexed() ? 24 : 0;
	}
	override uint getPixelFormat() @nogc @safe @property const pure {
		if (header.numBitPlanes == 1) {
			switch (header.bitsPerPixel) {
				case 1:		return PixelFormat.Indexed1Bit;
				case 2:		return PixelFormat.Indexed2Bit;
				case 8:		return PixelFormat.Indexed8Bit;
				default: 	break;
			}
		} else if (header.numBitPlanes == 3) {
			switch (header.bitsPerPixel) {
				case 1:		return PixelFormat.Planar8Color;
				case 8:		return PixelFormat.RGB888;
				default:	break;
			}
		} else if (header.numBitPlanes == 4) {
			switch (header.bitsPerPixel) {
				case 1:		return PixelFormat.Planar16Color;
				case 8:		return PixelFormat.RGBA8888;
				default:	break;
			}
		}
		return PixelFormat.Undefined;
	}
	override uint getPalettePixelFormat() @nogc @safe @property const pure {
		return isIndexed() ? PixelFormat.RGB888 : PixelFormat.Undefined;
	}
	/**
	 * Returns the number of planes the image have.
	 * If bitdepth is 1, then the image is a planar indexed image.
	 */
	override public ubyte getBitplanes() @nogc @safe @property const pure {
		return header.bitsPerPixel == 1 ? header.numBitPlanes : 1;
	}
}