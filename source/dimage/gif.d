/*
 * dimage - png.d
 * by Laszlo Szeremi
 *
 * Copyright under Boost Software License.
 */

module dimage.gif;

import std.bitmanip;
import std.exception;
import bitleveld.datatypes;
import dimage.base;
import dimage.util;
import core.stdc.stdlib;
import core.stdc.string;

static import std.stdio;
import ncompress42;
/**
 * Implements reader/writer for *.GIF-files.
 * Animation is accessed from a sliding window of setting the required frame.
 * Requires linking against the ncompress library for LZW support.
 */



public class GIF : Image, MultiImage {
	static enum ubyte	terminatorByte = 0x3B;
	/**
	 * Header for both 87a and 89a versions.
	 */
	align(1) public struct Header {
		char[3]		signature = "GIF";	///Header signature (always GIF)
		char[3]		_version;			///GIF format version ("87a" or "89a")
		ushort		width;				///Image width
		ushort		height;				///Image height
		union {
			ubyte		packed;			///Screen and color map information
			mixin(bitfields!(
				ubyte,	"sOfGlobalColorTable",	3,
				bool,	"colorTableSort",		1,
				ubyte,	"colorResolution",		3,
				bool,	"globalColorTable",		1,
			));
		}
		ubyte		backgroundColor;	///Background color index
		ubyte		aspectRatio;		///Pixel aspect ratio
	}
	/**
	 * Local image descriptor.
	 */
	align(1) public struct ImageDescriptor {
		//ubyte		separator = 0x2c;
		static enum ubyte	id 	=	0x2c;///Image descriptor identifier
		ushort		left;				///X position of image on display
		ushort		top;				///Y position of image on display
		ushort		width;				///Width of the image in pixels
		ushort		height;				///Height of the image in pixels
		union {
			ubyte		packed;			///Image and color table data information
			mixin(bitfields!(
				bool,	"localColorTable",		1,
				bool,	"interlace",			1,
				bool,	"sort",					1,
				ubyte,	"reserved",				2,
				ubyte,	"sOfLocalColorTable",	3,
			));
		}
	}
	static enum ubyte		extensionIntroducer	=	0x21;	///Extension identifier
	/**
	 * Extension found in GIF89a versions
	 */
	align(1) public struct GraphicsControlExtension {
		static enum ubyte	id	=	0xF9;	///Graphics control identifier
		union {
			ubyte		packed;			///Method of graphics disposal flag
			mixin(bitfields!(
				bool,	"transparentColorFlag",	1,
				bool,	"userInputFlag",		1,
				ubyte,	"disposalMethod",		3,
				ubyte,	"reserved",				3,
			));
			ushort		delayTime;		///Hundredth of seconds to wait
			ubyte		colorIndex;		///Transparent color index
			ubyte		terminator;		///Always zero
		}
	}
	/**
	 * Plain text extension of GIF89a
	 */
	public class PlainTextExtension {
		static enum ubyte	id	=	0x01;	///Plain text extension identifier
		///Header of this extension
		align(1) public struct Header {
			ushort	textGridLeft;	///X position of text grid in pixels
			ushort	textGridTop;	///Y position of text grid in pixels
			ushort	textGridWidth;	///Width of the text grid in pixels
			ushort	textGridHeight;	///Height of the text grid in pixels
			ubyte	cellWidth;		///Width of a grid cell in pixels
			ubyte	cellHeight;		///Height of a grid cell in pixels
			ubyte	textFgColorIndex;	///Text foreground color index value
			ubyte	textBgColorIndex;	///Text background color index value
		}
		Header		header;			///The header of this block
		string[]	plainTextData;	///Contains all individual text blocks that were found in the file
	}
	/**
	 * Application extension block
	 */
	public class ApplicationExtension {
		static enum ubyte	id	=	0xFF;	///Application extension label
		///Header of this extension
		align(1) public struct Header {
			char[8]		identifier;			///Application identifier
			ubyte[3]	authenticationCode;	///Authentication code
		}
		Header		header;		///The header of this block
		ubyte[]		data;		///The data contained in this block
	}
	protected Header header;
	protected ImageDescriptor[] imageDescriptors;
	//protected ubyte[] frames;
	protected IImageData[] frameImageData;
	protected IPalette[] localPalettes;
	protected IPalette globalColorTable;
	/**
	 * Empty constructor used by the loader
	 */
	protected this() {

	}
	/**
	 * Loads a *.gif file from a file
	 */
	public static load(F = std.stdio.File)(F file) {
		ubyte[] buffer, secBuf, currImg;
		GIF result = new GIF();
		buffer.length = Header.sizeof;
		secBuf.length = 1;
		buffer = file.rawRead(buffer);
		size_t readAm;
		if (buffer.length == Header.sizeof) {
			result.header = reinterpretGet!Header(buffer);
			enforce!ImageFileException(result.header.signature == "GIF", "File is not a GIF file or corrupted!");
		} else {
			throw new ImageFileException("File is not a GIF file or corrupted!");
		}
		if (result.header.globalColorTable) {
			const size_t gctSize = (1<<(result.header.sOfGlobalColorTable)) * 3;
			buffer.length = gctSize;
			buffer = file.rawRead(buffer);
			enforce!ImageFileException(buffer.length == gctSize, "File is corrupted and/or prematurely ended!");
			globalColorTable = new Palette!(RGB888)(reinterpretCast!RGB888(buffer), PixelFormat.RGB888, 24);
		}
		//Initialize LZW decompression
		int lzwStreamReader(ubyte* bytes, size_t numBytes, void* rwCtxt) {
			ubyte currReadAm;
			for (size_t i ; i < numBytes ; i += currReadAm) {
				if (!readAm) {
					currReadAm = 0;
					file.rawRead(&currReadAm[0..1]);
					if (!currReadAm) return -1;
					buffer.length = currReadAm;
					buffer = file.rawRead(buffer);
					if (buffer.length != currReadAm) return -1;
					if (numBytes - i > currReadAm) {
						memcpy(bytes+i, buffer.ptr, currReadAm);
					} else {
						readAm = currReadAm - (numBytes - i);
						memcpy(bytes+i, buffer.ptr, (numBytes - i));
					}
				} else {
					memcpy(bytes+i, buffer.ptr, readAm);
					readAm = 0;
				}
			}
			return cast(int)numBytes;
		}
		int lzwStreamWriter(const ubyte* bytes, size_t numBytes, void* rwCtxt) {
			currImg ~= bytes[0..numBytes];
			return cast(int)numBytes;
		}
		secBuf = file.rawRead(secBuf);
		do {

			// enforce!ImageFileException(secBuf.length == 1, "File is corrupted and/or prematurely ended.");
			switch (secBuf[0]) {
			case ImageDescriptor.id:
				buffer.length = ImageDescriptor.sizeof;
				buffer = file.rawRead(buffer);
				enforce!ImageFileException(buffer.length == ImageDescriptor.sizeof, "File is corrupted and/or prematurely ended!");
				result.imageDescriptors ~= reinterpretGet!ImageDescriptor(buffer);
				if (result.imageDescriptors[$ - 1].localColorTable) {
					const size_t lctSize = (1<<imageDescriptors[$ - 1].sOfLocalColorTable) * 3;
					buffer.length = lctSize;
					buffer = file.rawRead(buffer);
					enforce!ImageFileException(buffer.length == lctSize, "File is corrupted and/or prematurely ended!");
				} else {
					result.localPalettes ~= result.globalColorTable;
				}
				NCompressCtxt context;
				context.reader = &lzwStreamReader;
				context.writer = &lzwStreamWriter;
				nInitDecompress(&context);
				nDecompress(&context);
				break;
			case terminatorByte:
				secBuf.length = 0;
				break;
			default: throw new ImageFileException("Unrecognized identifier found in GIF file!");
			}
			secBuf = file.rawRead(secBuf);
		} while(secBuf.length == 1);

		return result;
	}
	private ubyte[] deinterlacer(ref ubyte[] data, int pitch, int lines) {
		static immutable byte[9] swapTableA = [1,2,3 ,5,6 ,7 ,9 ,11,13];
		static immutable byte[9] swapTableB = [8,4,12,6,10,14,12,13,14];
		scope ubyte[] workpad = new ubyte[pitch];
		for (int i ; i < lines ; i+=16) {
			for (int j ; j < 9 ; j++) {
				workpad[] = data[(pitch*(i + swapTableB[j]))..(pitch*(i + swapTableB[j] + 1))];
				data[(pitch*(i + swapTableB[j]))..(pitch*(i + swapTableB[j] + 1))] =
						data[(pitch*(i + swapTableA[j]))..(pitch*(swapTableA[j] + 1))];
				data[(pitch*(i + swapTableA[j]))..(pitch*(i + swapTableA[j] + 1))] = workpad;
			}
		}
		return data;
	}
	///Returns which image is being set to be worked on.
	public uint getCurrentImage() @safe pure {
		return 0;
	}
	///Sets which image is being set to be worked on.
	public uint setCurrentImage(uint frame) @safe pure {
		return 0;
	}
	///Sets the current image to the static if available
	public void setStaticImage() @safe pure {
		_imageData = frameImageData[0];
	}
	///Number of images in a given multi-image.
	public uint nOfImages() @property @safe @nogc pure const {
		return cast(uint)frameImageData.length;
	}
	///Returns the frame duration in hmsec if animation for the given frame.
	///Returns 0 if not an animation.
	public uint frameTime() @property @safe @nogc pure const {
		return 0;
	}
	///Returns true if the multi-image is animated
	public bool isAnimation() @property @safe @nogc pure const {
		return true;
	}
}
