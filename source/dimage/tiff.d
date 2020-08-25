/*
 * dimage - png.d
 * by Laszlo Szeremi
 *
 * Copyright under Boost Software License.
 */

module dimage.tiff;

import dimage.base;
import bitleveld.datatypes;
import dimage.util;
import std.bitmanip;

static import std.stdio;

/**
 * Implements *.TIFF file handling.
 * LZW compression support requires linking abainst ncompress42.
 * JPEG support requires a codec of some sort.
 */
public class TIFF : Image, MultiImage, ImageMetadata {
	/**
	 * Byte order identification for header.
	 * LE means little, BE means big endianness
	 */
	public enum ByteOrderIdentifier : ushort {
		LE		=	0x4949,
		BE		=	0x4D4D,
	}
	/**
	 * Standard TIFF header. Loaded as a bytestream at once.
	 */
	public struct Header {
	align(1):
		ushort		identifier;		///Byte order identifier.
		ushort		vers = 0x2A;	///Version number.
		uint		offset;			///Offset of first image file directory.
		/**
		 * Switches endianness if needed.
		 * Also changes identifier to the host machine's native endianness to avoid problems from conversion.
		 */
		void switchEndian() {
			version (LittleEndian) {
				if (identifier == ByteOrderIdentifier.BE) {
					identifier = ByteOrderIdentifier.LE;
					vers = swapEndian(vers);
					offset = swapEndian(offset);
				}
			} else {
				if (identifier == ByteOrderIdentifier.LE) {
					identifier = ByteOrderIdentifier.BE;
					vers = swapEndian(vers);
					offset = swapEndian(offset);
				}
			}
		}
	}
	/**
	 * TIFF Image File Directory. Loaded manually due to the nature of this field.
	 */
	public struct IFD {
		/**
		 * TIFF data types.
		 */
		public enum DataType : ushort {
			NULL		=	0,
			BYTE		=	1,	///unsigned byte
			ASCII		=	2,	///null terminated string, ASCII
			SHORT		=	3,	///unsigned short
			LONG		=	4,	///unsigned int
			RATIONAL	=	5,	///two unsigned ints

			SBYTE		=	6,	///signed byte
			UNDEFINED	=	7,	///byte
			SSHORT		=	8,	///signed short
			SLONG		=	9,	///signed int
			SRATIONAL	=	10,	///two signed ints
			FLOAT		=	11,	///IEEE single-precision floating-point
			DOUBLE		=	12,	///IEEE double-precision floating-point
		}
		/**
		 * Common TIFF entry identifiers.
		 */
		public enum DataEntryID : ushort {
			Artist			=	315,
			BadFaxLines		=	326,
			BitsPerSample	=	258,
			CellLength		=	265,
			CellWidth		=	264,
			CleanFaxData	=	327,
			ColorMap		=	320,
			ColorResponseCurve	=	301,
			ColorResponseUnit	=	300,
			Compression		=	259,
			ConsecuitiveBadFaxLines	=	328,
			Copyright		=	33_432,
			DateTime		=	306,
			DocumentName	=	269,
			DotRange		=	336,
			ExtraSamples	=	338,
			FillOrder		=	266,
			FreeByteCounts	=	289,
			FreeOffsets		=	288,
			GrayResponseCurve	=	291,
			GrayResponseUnit	=	290,
			HalftoneHints	=	321,
			HostComputer	=	316,
			ImageDescription=	270,
			ImageHeight		=	257,
			ImageWidth		=	256,
			InkNames		=	333,
			InkSet			=	332,
			JPEGACTTables	=	521,
			JPEGDCTTables	=	520,
			JPEGInterchangeFormat	=	513,
			JPEGInterchangeFormatLength	=	514,
			JPEGLosslessPredictors	=	517,
			JPEGPointTransforms	=	518,
			JPEGProc		=	512,
			JPEGRestartInterval	=	515,
			JPEGQTables		=	519,
			Make			=	271,
			MaxSampleValue	=	281,
			MinSampleValue	=	280,
			Model			=	272,
			NewSubFileType	=	254,
			NumberOfInks	=	334,
			Orientation		=	274,
			PageName		=	285,
			PageNumber		=	297,
			PhotometricInterpretation	=	262,
			WhiteIsZero		=	0,
			BlackIsZero		=	1,
			RGB				=	2,
			RGBPalette		=	3,
			TransparencyMask=	4,
			CMYK			=	5,
			YCbCr			=	6,
			CIELab			=	8,
			PlanarConfiguration	=	284,
			Predictor		=	317,
			PrimaryChromaticities	=	319,
			ReferenceBlackWhite	=	532,
			ResolutionUnit	=	296,
			RowsPerStrip	=	278,
			SampleFormat	=	339,
			SamplesPerPixel	=	277,
			SMaxSampleValue	=	341,
			SMinSampleValue	=	340,
			Software		=	305,
			StripByteCounts	=	279,
			StripOffsets	=	273,
			SubFileType		=	255,
			T4Options		=	292,
			T6Options		=	293,
			TargetPrinter	=	337,
			Thresholding	=	263,
			TileByteCounts	=	325,
			TileLength		=	323,
			TileOffsets		=	324,
			TileWidth		=	322,
			TransferFunction=	301,
			TransferRange	=	342,
			XPosition		=	286,
			XResolution		=	282,
			YCbCrCoefficients	=	529,
			YCbCrPositioning=	531,
			YCbCrSubSampling=	530,
			YPosition		=	287,
			YResolution		=	283,
			WhitePoint		=	318,
		}
		/**
		 * TIFF tag. Loaded as bytestream at once.
		 */
		public struct Tag {
		align(1):
			ushort		tagID;			///Tag identifier.
			ushort		dataType;		///Type of the data items.
			uint		dataCount;		///The amount of data stored within this tag.
			uint		dataOffset;		///The offset of data in bytes.	

			void switchEndian() @nogc @safe pure nothrow {
				tagID = swapEndian(tagID);
				dataType = swapEndian(dataType);
				dataCount = swapEndian(dataCount);
				dataOffset = swapEndian(dataOffset);
			}
			ubyte[] switchEndianOfData(ubyte[] data) @safe pure {
				switch(dataType){
					case DataType.SHORT, DataType.SSHORT:
						ushort[] workPad = reinterpretCast!ushort(data);
						for (size_t i ; i < workPad.length ; i++)
							workPad[i] = swapEndian(workPad[i]);
						return reinterpretCast!ubyte(workPad);
					case DataType.LONG, DataType.SLONG, DataType.FLOAT, DataType.RATIONAL, DataType.SRATIONAL:
						uint[] workPad = reinterpretCast!uint(data);
						for (size_t i ; i < workPad.length ; i++)
							workPad[i] = swapEndian(workPad[i]);
						return reinterpretCast!ubyte(workPad);
					case DataType.DOUBLE:
						ulong[] workPad = reinterpretCast!ulong(data);
						for (size_t i ; i < workPad.length ; i++)
							workPad[i] = swapEndian(workPad[i]);
						return reinterpretCast!ubyte(workPad);
					default: return [];
				}
			}
			@property size_t dataSize() @nogc @safe pure nothrow const {
				switch(dataType){
					case DataType.SHORT, DataType.SSHORT:
						return dataCount * 2;
					case DataType.LONG, DataType.SLONG, DataType.FLOAT:
						return dataCount * 4;
					case DataType.RATIONAL, DataType.SRATIONAL, DataType.DOUBLE:
						return dataCount * 8;
					default:
						return dataCount;
				}
			}
		}
	align(1):
		ushort			numDirEntries;	///Number of entries.
		Tag[]			tagList;		///List of tags in this field.
		ubyte[][]		tagData;		///Stores each datafields.
		uint			nextOffset;		///Offset of next IFD

		/**
		 * Returns the first instance of a given tag if exists, or returns uint.max if not.
		 */
		uint getTagNum(ushort tagID) @nogc @safe nothrow pure const {
			foreach (size_t key, Tag elem; tagList) {
				if (elem.tagID == tagID) return cast(uint)key;
			}
			return uint.max;
		}
	}
	protected Header	header;				///TIFF file header.
	protected IFD[]		directoryEntries;	///Image data.
	protected uint		currentImg;			///Current image selected with the MultiImage interface's functions.
	protected uint		_width, _height;	///Sizes of the current image
	protected ubyte		_bitdepth, _palbitdepth;	///Bitdepths of the current image
	protected uint		_pixelFormat, _palettePixelFormat;	///Pixelformat of the current image
	///CTOR for loader
	protected this() @nogc @safe pure nothrow {}
	
	/** 
	 * Loads a TIFF file from either disk or memory.
	 */
	public static TIFF load(FILE = std.stdio.File, bool keepJPEG = false)(ref FILE file) {
		TIFF result = new TIFF();
		ubyte[] buffer;
		buffer.length = Header.sizeof;
		buffer = file.rawRead(buffer);
		if(buffer.length != Header.sizeof) throw new ImageFileException("File doesn't contain TIFF header!");
		result.header = reinterpretGet!Header(buffer);
		result.header.switchEndian();
		if(!result.header.offset) throw new ImageFileException("File doesn't contain any images!");
		size_t pos = result.header.offset;
		
		//Load Image Data
		while(pos) {
			file.seek(pos, std.stdio.SEEK_CUR);
			buffer.length = ushort.sizeof;
			IFD entry;
			buffer = file.rawRead(buffer);
			if(buffer.length != ushort.sizeof) throw new ImageFileException("File access error or missing parts!");
			version (LittleEndian){
				if(result.header.identifier == ByteEndianness.BE) entry.numDirEntries = swapEndian(reinterpretGet!ushort(buffer));
			} else {
				if(result.header.identifier == ByteEndianness.LE) entry.numDirEntries = swapEndian(reinterpretGet!ushort(buffer));
			}
			IFD.tagData.length = entry.numDirEntries;
			for (ushort i ; i < entry.numDirEntries ; i++){
				buffer.length = IFD.Tag.sizeof;
				buffer = file.rawRead(buffer);
				if(buffer.length == IFD.Tag.sizeof) 
					throw new ImageFileException("File access error or missing parts!");
				IFD.Tag tag = reinterpretCast!IFD.Tag(buffer);
				version(LittleEndian) {
					if(result.header.identifier == ByteOrderIdentifier.BE) {
						tag.switchEndian();
					}
				} else {
					if(result.header.identifier == ByteOrderIdentifier.LE) {
						tag.switchEndian();
					}
				}
				if(tag.dataSize > 4) {
					file.seek(tag.dataOffset, std.stdio.SEEK_CUR);
					buffer.length = tag.dataSize;
					buffer = file.rawRead(buffer);
					if(buffer.length == tag.dataSize) 
						throw new ImageFileException("File access error or missing parts!");
					version (LittleEndian) {
						if (result.header.identifier == ByteEndianness.LE) entry.tagData[i] = buffer;
						else entry.tagData[i] = tag.switchEndianOfData(buffer);
					} else {
						if (result.header.identifier == ByteEndianness.BE) entry.tagData[i] = buffer;
						else entry.tagData[i] = tag.switchEndianOfData(buffer);
					}
					file.seek((tag.dataOffset + tag.dataSize) * -1, std.stdio.SEEK_CUR);
				} else {
					entry.tagData[i] = reinterpretAsArray!ubyte(tag.dataOffset);
					entry.tagData[i].length = tag.dataSize;
					version (LittleEndian) {
						if (result.header.identifier == ByteEndianness.BE) entry.tagData[i] = tag.switchEndianOfData(entry.tagData[i]);
					} else {
						if (result.header.identifier == ByteEndianness.LE) entry.tagData[i] = tag.switchEndianOfData(entry.tagData[i]);
					}
				}
				entry.tagList ~= tag;
			}
			//stitch image together if uncompressed, or decompress if needed.
			
			buffer.length = uint.sizeof;
			buffer = file.rawRead(buffer);
			if(buffer.length != uint.sizeof) throw new ImageFileException("File access error or missing parts!");
			//entry.nextOffset = reinterpretGet!uint(buffer);
			version (LittleEndian){
				if(result.header.identifier == ByteEndianness.LE) entry.nextOffset = reinterpretGet!uint(buffer);
				else entry.nextOffset = swapEndian(reinterpretGet!uint(buffer));
			} else {
				if(result.header.identifier == ByteEndianness.BE) entry.nextOffset = reinterpretGet!uint(buffer);
				else entry.nextOffset = swapEndian(reinterpretGet!uint(buffer));
			}
			pos = entry.nextOffset;
			result.directoryEntries ~= entry;
		}
		
		return result;
	}

	override uint width() @safe @property pure const {
		return _width;
	}

	override uint height() @safe @property pure const {
		return _height;
	}

	override bool isIndexed() @nogc @safe @property pure const {
		return _palbitdepth != 0;
	}

	override ubyte getBitdepth() @nogc @safe @property pure const {
		return _bitdepth; 
	}

	override ubyte getPaletteBitdepth() @nogc @safe @property pure const {
		if(isIndexed) return 48;
		return ubyte.init;
	}

	override uint getPixelFormat() @nogc @safe @property pure const {
		return _pixelFormat;
	}

	override uint getPalettePixelFormat() @nogc @safe @property pure const {
		if (isIndexed) return PixelFormat.RGB16_16_16;
		return uint.init; // TODO: implement
	}

	public uint getCurrentImage() @safe pure {
		return currentImg; // TODO: implement
	}

	public uint setCurrentImage(uint frame) @safe pure {
		return currentImg = frame; // TODO: implement
	}

	public uint nOfImages() @property @safe @nogc pure const {
		return cast(uint)directoryEntries.length;
	}

	public uint frameTime() @property @safe @nogc pure const {
		return uint.init;
	}

	public bool isAnimation() @property @safe @nogc pure const {
		return false;
	}
	
	public string getID() @safe pure {
		return string.init; // TODO: implement
	}
	
	public string getAuthor() @safe pure {
		return string.init; // TODO: implement
	}
	
	public string getComment() @safe pure {
		return string.init; // TODO: implement
	}
	
	public string getJobName() @safe pure {
		return string.init; // TODO: implement
	}
	
	public string getSoftwareInfo() @safe pure {
		return string.init; // TODO: implement
	}
	
	public string getSoftwareVersion() @safe pure {
		return string.init; // TODO: implement
	}
	
	public string setID(string val) @safe pure {
		return string.init; // TODO: implement
	}
	
	public string setAuthor(string val) @safe pure {
		return string.init; // TODO: implement
	}
	
	public string setComment(string val) @safe pure {
		return string.init; // TODO: implement
	}
	
	public string setJobName(string val) @safe pure {
		return string.init; // TODO: implement
	}
	
	public string setSoftwareInfo(string val) @safe pure {
		return string.init; // TODO: implement
	}
	
	public string setSoftwareVersion(string val) @safe pure {
		return string.init; // TODO: implement
	}
	

}