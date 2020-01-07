module dimage.gif;

import std.bitmanip;
import bitleveld.datatypes;
import dimage.base;
import dimage.util;

static import std.stdio;

/**
 * Implements reader/writer for *.GIF-files.
 * Animation is accessed from a sliding window, and 
 */
version (lzwsupport) {
	import ncompress42;

	public class GIF : Image, Animation {
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
				mixin bitfields!(
					ubyte,	"sOfGlobalColorTable",	3,
					bool,	"colorTableSort",		1,
					ubyte,	"colorResolution",		3,
					bool,	"globalColorTable",		1,
				);
			}
			ubyte		backgroundColor;	///Background color index
			ubyte		aspectRatio;		///Pixel aspect ratio
		}
		/**
		 * Per image descriptor.
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
				mixin bitfields!(
					bool,	"localColorTable",		1,
					bool,	"interlace",			1,
					bool,	"sort",					1,
					ubyte,	"reserved",				2,
					ubyte,	"sOfLocalColorTable",	3,
				);
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
				mixin bitfields!(
					bool,	"transparentColorFlag",	1,
					bool,	"userInputFlag",		1,
					ubyte,	"disposalMethod",		3,
					ubyte,	"reserved",				3,
				);
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
		protected ubyte[] frames;
		/**
		 * Empty constructor used by the loader
		 */
		protected this() {

		}
		/**
		 * Loads a *.gif file from a file
		 */
		public static load(F = std.stdio.File)(F file) {
			ubyte[] buffer, secBuf;
			GIF result;
			buffer.length = Header.sizeof;
			secBuf.length = 1;
			buffer = file.rawRead(buffer);
			if (buffer.length == Header.sizeof) {
				result.header = reinterpretGet!Header(buffer);
			} else {
				throw new ImageFileException("File is not a GIF file or corrupted!");
			}
			//Initialize LZW decompression
			int lzwStreamReader (ubyte* bytes, size_t numBytes, void* rwCtxt) {
				file.rawRead(secBuf);
				buffer.length = secBuf[0];
				buffer = file.rawRead(buffer);
			}

			return result;
		}
	}
}