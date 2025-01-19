/*
 * dimage - png.d
 * by Laszlo Szeremi
 *
 * Copyright under Boost Software License.
 */

module dimage.png;

import dimage.base;

import zlib = etc.c.zlib;
import std.digest.crc;
import std.bitmanip;
import std.algorithm.mutation : reverse;
static import std.stdio;
static import std.string;
import std.string : fromStringz;
import core.stdc.stdint;
import bitleveld.datatypes;
import dimage.util;
import std.conv : to;
/**
 * Implements the Portable Network Graphics file format as a class.
 *
 * Supports APNG extenstions.
 */
public class PNG : Image, MultiImage, CustomImageMetadata {
	///Chunk initializer IDs.
	static enum ChunkInitializers : char[4] {
		Header				=	"IHDR",		///Standard, for header, before image data
		Palette				=	"PLTE",		///Standard, for palette, after header and before image data
		Data				=	"IDAT",		///Standard, for image data
		End					=	"IEND",		///Standard, file end marker
		//Ancillary chunks:
		Background			=	"bKGD",		///Background color
		Chromaticies		=	"cHRM",		///Primary chromaticities and white point
		Gamma				=	"gAMA",		///Image gamma
		Histogram			=	"hIST",		///Image histogram
		PixDim				=	"pHYs",		///Physical pixel dimensions
		SignifBits			=	"sBIT",		///Significant bits
		TextData			=	"tEXt",		///Textual data
		Time				=	"tIME",		///Last modification date
		Transparency		=	"tRNS",		///Transparency
		CompTextData		=	"zTXt",		///Compressed textual data
		IntTextData			=	"iTXt",		///International textual data
		//Chunks for APNG:
		AnimationControl	=	"acTL",		///Animation control chunk
		FrameControl		=	"fcTL",		///Frame control chunk
		FrameData			=	"fDAT",		///Frame data
	}
	/**
	 * Defines standard PNG filter types.
	 */
	static enum FilterType : ubyte {
		None,
		Sub,
		Up,
		Average,
		Paeth,
	}
	/**
	 * Defines the flags in the flag field.
	 */
	static enum Flags : uint {
		HasTransparency		=	0x01,
		HasAPNGext			=	0x02,
	}
	//static enum HEADER_INIT = "IHDR";		///Initializes header in the file
	//static enum PALETTE_INIT = "PLTE";		///Initializes palette in the file
	//static enum DATA_INIT = "IDAT";			///Initializes image data in the file
	//static enum END_INIT = "IEND";			///Initializes the end of the file
	static enum ubyte[8] PNG_SIGNATURE = [0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A];	///Used for checking PNG files
	static enum ubyte[4] PNG_CLOSER = [0xAE, 0x42, 0x60, 0x82];		///Final checksum of IEND
	/// Used for static function load. Selects checksum checking policy.
	static enum ChecksumPolicy : ubyte{
		DisableAll,
		DisableAncillary,
		Enable
	}
	/**
	 * Stores ancillary data embedded into PNG files. Handling these are not vital for opening PNG files, but available for various purposes.
	 * Please be aware that certain readers might have issues with nonstandard chunks
	 */
	public class EmbeddedData{
		/**
		 * Describes where this data stream should go within the file.
		 * This describe the exact location, and configured when loading from PNG files. WithinIDAT will result in dumping all of them before the last theoretical IDAT chunk.
		 */
		public enum DataPosition{
			BeforePLTE,
			BeforeIDAT,
			WithinIDAT,
			AfterIDAT
		}
		DataPosition	pos;	/// Describes the exact location of 
		char[4]		identifier;	/// Identifies the data of this chunk
		ubyte[]		data;		/// Contains the data of this chunk
		/**
		 * Creates an instance of this class.
		 */
		public this(DataPosition pos, char[4] identifier, ubyte[] data){
			this.pos = pos;
			this.identifier = identifier;
			this.data = data;
		}
	}
	/**
	 * PNG Chunk identifier
	 */
	struct Chunk{
		uint		dataLength;	///Length of chunk
		char[4] 	identifier;	///Identifies the data of this chunk
		/**
		 * Converts the struct to little endian on systems that need them.
		 */
		public void bigEndianToNative() {
			version(LittleEndian)
				dataLength = swapEndian(dataLength);
		}
		/**
		 * Returns a copy of the struct that is in big endian.
		 */
		public Chunk nativeToBigEndian() {
			version(LittleEndian)
				return Chunk(swapEndian(dataLength), identifier);
			else
				return this;
		}
	}
	/**
	 * Represents the possible types for PNG
	 * While bitmasking could be used, not every combination are valid
	 */
	enum ColorType : ubyte {
		Greyscale			=	0,
		TrueColor			=	2,
		Indexed				=	3,
		GreyscaleWithAlpha	=	4,
		TrueColorWithAlpha	=	6,
	}
	/**
	 * Contains most data related to PNG files.
	 */
	align(1) struct Header{
	align(1):
		uint		width;			/// Width of image in pixels 
    	uint		height;			/// Height of image in pixels 
    	ubyte		bitDepth;		/// Bits per pixel or per sample
    	ColorType	colorType;		/// Color interpretation indicator
    	ubyte		compression;	/// Compression type indicator
    	ubyte		filter;			/// Filter type indicator
    	ubyte		interlace;		/// Type of interlacing scheme used
		/**
		 * Converts the struct to little endian on systems that need them.
		 */
		public void bigEndianToNative() @safe @nogc pure nothrow {
			version(LittleEndian){
				width = swapEndian(width);
				height = swapEndian(height);
			}
		}
		/**
		 * Returns a copy of the struct that is in big endian.
		 */
		public Header nativeToBigEndian() @safe pure nothrow {
			version(LittleEndian)
				return Header(swapEndian(width), swapEndian(height), bitDepth, colorType, compression, filter, interlace);
			else
				return this;
		}
		/**
		 * For debugging purposes.
		 */
		public string toString() const {
			import std.conv : to;
			return "width: " ~ to!string(width) ~ "\n" ~
				"height: " ~ to!string(height) ~ "\n" ~
				"bitDepth: " ~ to!string(bitDepth) ~ "\n" ~
				"colorType: " ~ to!string(colorType) ~ "\n" ~
 				"compression: " ~ to!string(compression) ~ "\n" ~
 				"filter: " ~ to!string(filter) ~ "\n" ~
 				"interlace: " ~ to!string(interlace) ~ "\n"; 
		}
	}
	/**
	 * Contains textual metadata embedded into the file.
	 */
	struct Text {
		string		keyword;			///The keyword, which the textual metadata is associated with. (Max 79 characters)
		string		text;				///The text itself.
		string		lang;				///Language in case of international textual data.
		string		ikeyword;			///Translated keyword if any.
		ubyte		compression;		///Compression method flag. (should be zero)
		ubyte		isCompressed;		///1 if field is compressed, 0 otherwise.
	}
	/**
	 * Animation control chunk.
	 * If found in a PNG file, it means it has the APNG extensions.
	 */
	struct AnimationControl {
		uint		numFrames;			///Number of animation frames.
		uint		numPlays;			///Number of repeats (0 means infinite loop).
		/**
		 * Converts the struct to little endian on systems that need them.
		 */
		public void bigEndianToNative() @safe @nogc pure nothrow {
			version(LittleEndian){
				numFrames = swapEndian(numFrames);
				numPlays = swapEndian(numPlays);
			}
		}
		/**
		 * Converts the struct to big endian for storage.
		 */
		public void nativeToBigEndian() @safe @nogc pure nothrow {
			version(LittleEndian){
				numFrames = swapEndian(numFrames);
				numPlays = swapEndian(numPlays);
			}
		}
	}
	/**
	 * Frame disposal operator.
	 */
	enum FrameDisposalOperator : ubyte {
		None,				///no disposal is done on this frame before rendering the next; the contents of the output buffer are left as is.
		Background,			///the frame's region of the output buffer is to be cleared to fully transparent black before rendering the next frame.
		Previous,			///the frame's region of the output buffer is to be reverted to the previous contents before rendering the next frame.
	}
	/**
	 * Frame blend operator.
	 */
	enum FrameBlendOperator : ubyte {
		Source,				///all color components of the frame, including alpha, overwrite the current contents of the frame's output buffer region
		Over,				///the frame should be composited onto the output buffer based on its alpha, using a simple OVER operation as described in the "Alpha Channel Processing" section of the PNG specification
	}
	/**
	 * Frame control chunk.
	 */
	struct FrameControl {
		uint		seqNum;
		uint		width;
		uint		height;
		uint		xOffset;
		uint		yOffset;
		ushort		delayNum;
		ushort		delayDen;
		FrameDisposalOperator	disposeOp;
		FrameBlendOperator		blendOp;
		/**
		 * Converts the struct to little endian on systems that need them.
		 */
		public void bigEndianToNative() @safe @nogc pure nothrow {
			version(LittleEndian){
				seqNum = swapEndian(seqNum);
				width = swapEndian(width);
				height = swapEndian(height);
				xOffset = swapEndian(xOffset);
				yOffset = swapEndian(yOffset);
				delayNum = swapEndian(delayNum);
				delayDen = swapEndian(delayDen);
			}
		}
		/**
		 * Converts the struct to big endian for storage.
		 */
		public void nativeToBigEndian() @safe @nogc pure nothrow {
			version(LittleEndian){
				seqNum = swapEndian(seqNum);
				width = swapEndian(width);
				height = swapEndian(height);
				xOffset = swapEndian(xOffset);
				yOffset = swapEndian(yOffset);
				delayNum = swapEndian(delayNum);
				delayDen = swapEndian(delayDen);
			}
		}
	}
	protected Header		header;
	protected IImageData	baseImage;				///Base image if APNG chunks present.
	protected IImageData[]	frames;					///Extra frames for the APNG extension
	public EmbeddedData[]	ancillaryChunks;		///Stores ancilliary chunks that are not essential for image processing
	public ubyte[]			filterBytes;			///Filterbytes for each scanline
	public ubyte[][]		frameFilterBytes;		///Filterbytes for each frame (might be jagged)
	public Text[]			textData;				///Textual metadata
	protected int			bkgIndex = -1;			///Background index
	protected uint			flags;					///Stores property flags
	protected RGB16_16_16BE	bkgColor;				///Background color
	protected RGB16_16_16BE	trns;					///Transparency
	protected size_t		pitch;
	/**
	 * Creates an empty PNG file in memory
	 */
	public this(IImageData imgDat, IPalette pal = null) @safe pure {
		//header = Header(width, height, bitDepth, colorType, compression, 0, 0);
		_imageData = imgDat;
		_palette = pal;
		header.bitDepth = imgDat.bitDepth;
		header.width = imgDat.width;
		header.height = imgDat.height;
		filterBytes.length = imgDat.height;
		pitch = (header.width * imgDat.bitDepth) / 8;
		switch (imgDat.pixelFormat) {
			case PixelFormat.Indexed1Bit: .. case PixelFormat.Indexed8Bit:
				header.colorType = ColorType.Indexed;
				header.bitDepth = imgDat.bitDepth;
				break;
			case PixelFormat.Grayscale1Bit: .. case PixelFormat.Grayscale8Bit: case PixelFormat.Grayscale16Bit:
				header.colorType = ColorType.Greyscale;
				header.bitDepth = imgDat.bitDepth;
				break;
			case PixelFormat.YA88 | PixelFormat.BigEndian:
				header.colorType = ColorType.GreyscaleWithAlpha;
				header.bitDepth = imgDat.bitDepth / 2;
				break;
			case PixelFormat.RGB888 | PixelFormat.BigEndian, PixelFormat.RGBX5551 | PixelFormat.BigEndian, 
					PixelFormat.RGB16_16_16 | PixelFormat.BigEndian:
				header.colorType = ColorType.TrueColor;
				header.bitDepth = imgDat.bitDepth / 3;
				break;
			case PixelFormat.RGBA8888 | PixelFormat.BigEndian, PixelFormat.RGBA16_16_16_16 | PixelFormat.BigEndian:
				header.colorType = ColorType.TrueColorWithAlpha;
				header.bitDepth = imgDat.bitDepth / 4;
				break;
			default: throw new ImageFormatException("Image format currently not supported!");
		}
		switch (header.bitDepth) {
			case 1:
				if (header.width & 7) pitch++;
				break;
			case 2:
				if (header.width & 3) pitch++;
				break;
			case 4:
				if (header.width & 1) pitch++;
				break;
			default:
				break;
		}		
	}
	protected this(){

	}
	/**
	 * Loads a PNG file.
	 * Currently interlaced mode is unsupported.
	 */
	static PNG load(F = std.stdio.File, ChecksumPolicy chksmTest = ChecksumPolicy.DisableAncillary)(ref F file){
		class PNGImgDecoder {
			zlib.z_stream strm;
			ubyte[] output;
			ubyte[]	filterBytes;
			~this() {
				zlib.inflateEnd(&strm);
			}
		}
		//import std.zlib : UnCompress;
		RGB16_16_16BE beToNative(RGB16_16_16BE val) {
			version(LittleEndian) {
				val.r = swapEndian(val.r);
				val.g = swapEndian(val.g);
				val.b = swapEndian(val.b);
			}
			return val;
		}
		///Decompresses a text chunk.
		///`extstrm` is used in case of an error during decompression. It'll fold it, to avoid memory leakage issues.
		string decompressText(ubyte[] src, zlib.z_streamp extstrm) {
			import std.math : nextPow2;
			ubyte[] output, workpad;
			zlib.z_stream strm;
			strm.zalloc = null;
			strm.zfree = null;
			strm.opaque = null;
			int ret = zlib.inflateInit(&strm);
			strm.next_in = src.ptr;
			strm.avail_in = cast(uint)src.length;
			output.length = nextPow2(src.length);
			strm.next_out = output.ptr;
			strm.avail_out = cast(uint)output.length;
			while (strm.avail_in) {
				ret = zlib.inflate(&strm, zlib.Z_FULL_FLUSH);
				if(!(ret == zlib.Z_OK || ret == zlib.Z_STREAM_END)){
					zlib.inflateEnd(&strm);
					zlib.inflateEnd(extstrm);
					throw new ImageFileException("Text data decompression error");
				}
				if (!strm.avail_out) {//decompress more data
					strm.next_out = output.ptr;
					strm.avail_out = cast(uint)output.length;
					workpad ~= output;
				}
			}
			workpad ~= output;
			workpad.length = cast(size_t)strm.total_out;
			zlib.inflateEnd(&strm);
			return reinterpretCast!char(workpad).idup;
		}
		/+ubyte[] decompressAnimChunk(ubyte[] src, AnimChunk context) {
			
		}+/
		PNG result = new PNG();
		bool iend;
		EmbeddedData.DataPosition pos = EmbeddedData.DataPosition.BeforePLTE;
		version (unittest) uint scanlineCounter;
		//initialize decompressor
		int ret;
    	//uint have;
    	zlib.z_stream strm;
		strm.zalloc = null;
		strm.zfree = null;
		strm.opaque = null;
		ret = zlib.inflateInit(&strm);
		if(ret != zlib.Z_OK)
			throw new Exception("Decompressor initialization error");

		ubyte[] readBuffer, imageBuffer, imageTemp, paletteTemp, paletteTemp0;
		readBuffer.length = 8;
		file.rawRead(readBuffer);
		for(int i ; i < 8 ; i++)
			if(readBuffer[i] != PNG_SIGNATURE[i])
				throw new ImageFileException("Invalid PNG file signature");
		do{
			ubyte[4] crc;
			file.rawRead(readBuffer);
			Chunk curChunk = (cast(Chunk[])(cast(void[])readBuffer))[0];
			curChunk.bigEndianToNative();
			readBuffer.length = curChunk.dataLength;
			if(curChunk.dataLength)
				file.rawRead(readBuffer);
			switch(curChunk.identifier){
				case ChunkInitializers.Header:
					result.header = reinterpretGet!Header(readBuffer);
					result.header.bigEndianToNative;
					result.pitch = (result.header.width * result.getBitdepth) / 8;
					imageBuffer.length = result.pitch + 1;
					strm.next_out = imageBuffer.ptr;
					strm.avail_out = cast(uint)imageBuffer.length;
					break;
				case ChunkInitializers.Palette:
					paletteTemp = readBuffer.dup;
					pos = EmbeddedData.DataPosition.BeforeIDAT;
					break;
				case ChunkInitializers.Transparency:
					
					switch (result.header.colorType){
						case ColorType.Indexed:
							if(readBuffer.length == paletteTemp.length) paletteTemp0 = readBuffer.dup;
							else if (readBuffer.length == RGB16_16_16BE.sizeof) goto case ColorType.TrueColor;
							break;
						case ColorType.TrueColor:
							result.flags = 1;
							result.trns = reinterpretGet!RGB16_16_16BE(readBuffer);
							result.trns = beToNative(result.trns);
							break;
						case ColorType.Greyscale:
							result.flags = 1;
							const ushort value = reinterpretGet!ushort(readBuffer);
							result.trns = RGB16_16_16BE(value, value, value);
							result.trns = beToNative(result.trns);
							break;
						default:
							break;
					}
					break;
				case ChunkInitializers.Data:
					//if(result.header.compression)
					//imageBuffer ~= cast(ubyte[])decompressor.uncompress(cast(void[])readBuffer);
					//else
					//	imageBuffer ~= readBuffer.dup;
					pos = EmbeddedData.DataPosition.WithinIDAT;
					strm.next_in = readBuffer.ptr;
					strm.avail_in = cast(uint)readBuffer.length;
					while (strm.avail_in) {
						ret = zlib.inflate(&strm, zlib.Z_FULL_FLUSH);
						if(!(ret == zlib.Z_OK || ret == zlib.Z_STREAM_END)){
							zlib.inflateEnd(&strm);
							throw new ImageFileException("Decompression error");
						}else if(imageBuffer.length == strm.total_out){
							pos = EmbeddedData.DataPosition.AfterIDAT;
						}
						if (!strm.avail_out) {//flush scanline into imagedata
							version (unittest) scanlineCounter++;
							version (unittest) assert (scanlineCounter <= result.header.height, "Scanline overflow!");
							imageTemp ~= imageBuffer[1..$];
							result.filterBytes ~= imageBuffer[0];
							strm.next_out = imageBuffer.ptr;
							strm.avail_out = cast(uint)imageBuffer.length;
						}
					}
					
					break;
				case ChunkInitializers.Background:
					switch (result.header.colorType) {
						case ColorType.Indexed:
							result.bkgIndex = readBuffer[0];
							break;
						case ColorType.Greyscale, ColorType.GreyscaleWithAlpha:
							result.bkgIndex = -2;
							const ushort value = reinterpretGet!ushort(readBuffer);
							result.bkgColor = RGB16_16_16BE(value, value, value);
							result.bkgColor = beToNative(result.bkgColor);
							break;
						case ColorType.TrueColor, ColorType.TrueColorWithAlpha:
							result.bkgIndex = -2;
							result.bkgColor = reinterpretGet!RGB16_16_16BE(readBuffer);
							result.bkgColor = beToNative(result.bkgColor);
							break;
						default:
							break;
					}
					break;
				case ChunkInitializers.TextData:
					ubyte[] arr = readBuffer.dup;
					string keyword = getFirstString(arr);
					Text t = Text(keyword, reinterpretCast!char(arr).idup, null, null, 0, 0);
					result.textData ~= t;
					break;
				case ChunkInitializers.CompTextData:
					ubyte[] arr = readBuffer.dup;
					string keyword = getFirstString(arr);
					Text t = Text(keyword, decompressText(arr[1..$], &strm), null, null, 0, 1);
					result.textData ~= t;
					break;
				case ChunkInitializers.IntTextData:
					ubyte[] arr = readBuffer.dup;
					string keyword = getFirstString(arr);
					const ubyte cmprflag = arr[0];
					arr = arr[2..$];

					string lngTag;
					if (arr[0] != '\n') lngTag = getFirstString(arr);
					else arr = arr[1..$];

					string intrntKeyword;
					if (arr[0] != '\n') intrntKeyword = getFirstString(arr);
					else arr = arr[1..$];

					if (cmprflag) {
						result.textData ~= Text(keyword, decompressText(arr, &strm), lngTag, intrntKeyword, 0, 1);
					} else {
						result.textData ~= Text(keyword, reinterpretCast!char(arr).idup, lngTag, intrntKeyword, 0, 0);
					}
					break;
				case ChunkInitializers.End:
					version (unittest) assert(result.header.height == scanlineCounter, "Scanline count mismatch");
					if(imageTemp.length + result.filterBytes.length > strm.total_out){
						zlib.inflateEnd(&strm);
						
						throw new ImageFileCompressionException("Decompression error! Image ended at: " ~ to!string(strm.total_out) ~ 
						"; Required length: " ~ to!string(imageTemp.length));
					}
					imageTemp.reserve(result.height * result.pitch);
					result.filterBytes.reserve(result.height);
					iend = true;
					break;
				default:
					//Process any unknown chunk as embedded data
					//EmbeddedData chnk = new EmbeddedData(pos, curChunk.identifier, readBuffer.dup);
					result.addAncilliaryChunk(pos, curChunk.identifier, readBuffer.dup);
					
					break;
				
			}
			if (paletteTemp.length) {
				if(paletteTemp0.length) result._palette = new PaletteWithSepA!RGB888BE(reinterpretCast!RGB888BE(paletteTemp), 
						paletteTemp0, PixelFormat.RGB888 | PixelFormat.ValidAlpha | PixelFormat.BigEndian, 24);
				else result._palette = new Palette!RGB888BE(reinterpretCast!RGB888BE(paletteTemp), PixelFormat.RGB888 | 
						PixelFormat.BigEndian, 24);
			}
			//calculate crc
			//if(curChunk.dataLength){
			crc = crc32Of((cast(ubyte[])curChunk.identifier) ~ readBuffer);
			readBuffer.length = 4;
			file.rawRead(readBuffer);
			readBuffer.reverse;
			static if(chksmTest == ChecksumPolicy.Enable){
				if(readBuffer != crc)
					throw new ChecksumMismatchException("Checksum error");
			}else static if(chksmTest == ChecksumPolicy.DisableAncillary) {
				if(readBuffer != crc && (curChunk.identifier == ChunkInitializers.Header || curChunk.identifier == 
						ChunkInitializers.Palette || curChunk.identifier == ChunkInitializers.Data || curChunk.identifier == 
						ChunkInitializers.End))
					throw new ChecksumMismatchException("Checksum error");
			}
			//}
			readBuffer.length = 8;
		} while(!iend);
		zlib.inflateEnd(&strm);//should have no data remaining
		assert(imageTemp.length == result.pitch * result.header.height, "Image size mismatch. Expected size: " ~ 
				to!string(result.pitch * result.header.height) ~ "; Actual size: " ~ to!string(imageTemp.length) ~ 
				"; Pitch length: " ~ to!string(result.pitch) ~ "; N of scanlines: " ~ to!string(result.header.height));
		//reconstruct image from filtering
		ubyte[] scanline, prevScanline;
		int wordlength = result.getBitdepth > 8 ? result.getBitdepth / 8 : 1;
		for (uint y ; y < result.filterBytes.length ; y++) {
			scanline = imageTemp[(y * result.pitch)..((y + 1) * result.pitch)];
			switch (result.filterBytes[y]) {
				case FilterType.Sub:
					reconstructScanlineSub(scanline, wordlength);
					break;
				case FilterType.Up:
					reconstructScanlineUp(scanline, prevScanline);
					break;
				case FilterType.Average:
					reconstructScanlineAverage(scanline, prevScanline, wordlength);
					break;
				case FilterType.Paeth:
					reconstructScanlinePaeth(scanline, prevScanline, wordlength);
					break;
				default:
					
					break;
			}
			prevScanline = scanline;
		}
		//setup imagedata
		if (result.header.bitDepth == 16) {
			ushort[] arr = nativeStreamToBigEndian!ushort(reinterpretCast!ushort(imageTemp));
			imageTemp = reinterpretCast!ubyte(arr);
		}
		switch (result.getPixelFormat & ~PixelFormat.BigEndian) {
			case PixelFormat.Indexed1Bit: 
				result._imageData = new IndexedImageData1Bit(imageTemp, result._palette, result.width, result.height);
				break;
			case PixelFormat.Indexed2Bit:
				result._imageData = new IndexedImageData2Bit(imageTemp, result._palette, result.width, result.height);
				break;
			case PixelFormat.Indexed4Bit:
				result._imageData = new IndexedImageData4Bit(imageTemp, result._palette, result.width, result.height);
				break;
			case PixelFormat.Indexed8Bit:
				result._imageData = new IndexedImageData!ubyte(imageTemp, result._palette, result.width, result.height);
				break;
			case PixelFormat.YA88:
				result._imageData = new ImageData!YA88BE(reinterpretCast!YA88BE(imageTemp), result.width, result.height, 
						result.getPixelFormat, result.getBitdepth);
				break;
			case PixelFormat.YA16_16:
				//imageTemp = bigEndianStreamToNative(imageTemp);
				result._imageData = new ImageData!YA16_16BE(reinterpretCast!YA16_16BE(imageTemp), result.width, result.height, 
						result.getPixelFormat, result.getBitdepth);
				break;
			case PixelFormat.RGB888:
				result._imageData = new ImageData!RGB888BE(reinterpretCast!RGB888BE(imageTemp), result.width, result.height, 
						result.getPixelFormat, result.getBitdepth);
				break;
			case PixelFormat.RGB16_16_16:
				//imageTemp = bigEndianStreamToNative(imageTemp);
				result._imageData = new ImageData!RGB16_16_16BE(reinterpretCast!RGB16_16_16BE(imageTemp), result.width, 
						result.height, result.getPixelFormat, result.getBitdepth);
				break;
			case PixelFormat.RGBX5551:
				result._imageData = new ImageData!RGBA5551(reinterpretCast!RGBA5551(imageTemp), result.width, result.height, 
						result.getPixelFormat, result.getBitdepth);
				break;
			case PixelFormat.RGBA8888:
				result._imageData = new ImageData!RGBA8888BE(reinterpretCast!RGBA8888BE(imageTemp), result.width, result.height, 
						result.getPixelFormat, result.getBitdepth);
				break;
			case PixelFormat.RGBA16_16_16_16:
				//imageTemp = bigEndianStreamToNative(imageTemp);
				result._imageData = new ImageData!RGBA16_16_16_16BE(reinterpretCast!RGBA16_16_16_16BE(imageTemp), result.width, 
						result.height, result.getPixelFormat, result.getBitdepth);
				break;
			case PixelFormat.Grayscale1Bit:
				result._imageData = new MonochromeImageData1Bit(imageTemp, result.width, result.height);
				break;
			case PixelFormat.Grayscale2Bit:
				result._imageData = new MonochromeImageData2Bit(imageTemp, result.width, result.height);
				break;
			case PixelFormat.Grayscale4Bit:
				result._imageData = new MonochromeImageData4Bit(imageTemp, result.width, result.height);
				break;
			case PixelFormat.Grayscale8Bit:
				result._imageData = new MonochromeImageData!ubyte(reinterpretCast!ubyte(imageTemp), result.width, result.height, 
						result.getPixelFormat, result.getBitdepth);
				break;
			case PixelFormat.Grayscale16Bit:
				//imageTemp = bigEndianStreamToNative(imageTemp);
				result._imageData = new MonochromeImageData!ushort(reinterpretCast!ushort(imageTemp), result.width, result.height, 
						result.getPixelFormat, result.getBitdepth);
				break;
			default: throw new ImageFileException("Unsupported image format!");
		}
		return result;
	}
	/**
	 * Decompresses a block of graphics data.
	 */
	/**
	 * Reconstructs a scanline from `Sub` filtering.
	 */
	protected static ubyte[] reconstructScanlineSub(ubyte[] target, int bytedepth) @safe nothrow {
		for (size_t i ; i < target.length ; i++) {
			const ubyte a = i >= bytedepth ? target[i - bytedepth] : 0;
			target[i] += a;
		}
		return target;
	}
	/**
	 * Reconstructs a scanline from `Up` filtering.
	 */
	protected static ubyte[] reconstructScanlineUp(ubyte[] target, ubyte[] prevScanline) @safe nothrow {
		assert(target.length == prevScanline.length);
		for (size_t i ; i < target.length ; i++) {
			target[i] += prevScanline[i];
		}
		return target;
	}
	/**
	 * Reconstructs a scanline from `Average` filtering
	 */
	protected static ubyte[] reconstructScanlineAverage(ubyte[] target, ubyte[] prevScanline, int bytedepth) 
			@safe nothrow {
		assert(target.length == prevScanline.length);
		for (size_t i ; i < target.length ; i++) {
			const uint a = i >= bytedepth ? target[i - bytedepth] : 0;
			target[i] += cast(ubyte)((a + prevScanline[i])>>>1);
			
		}
		return target;
	}
	/**
	 * Paeth function for filtering and reconstruction.
	 */
	protected static ubyte paethFunc(const ubyte a, const ubyte b, const ubyte c) @safe nothrow {
		import std.math : abs;

		const int p = a + b - c;
		const int pa = abs(p - a);
		const int pb = abs(p - b);
		const int pc = abs(p - c);

		if (pa <= pb && pa <= pc) return a;
		else if (pb <= pc) return b;
		else return c;
	}
	/**
	 * Reconstructs a scanline from `Paeth` filtering.
	 */
	protected static ubyte[] reconstructScanlinePaeth(ubyte[] target, ubyte[] prevScanline, int bytedepth) @safe nothrow {
		assert(target.length == prevScanline.length);
		for (size_t i ; i < target.length ; i++) {
			const ubyte a = i >= bytedepth ? target[i - bytedepth] : 0, b = prevScanline[i], 
					c = i >= bytedepth ? prevScanline[i - bytedepth] : 0;
			target[i] += paethFunc(a, b, c);
			
		}
		return target;
	}
	/**
	 * Saves the file to the disk.
	 * Currently interlaced mode is unsupported.
	 */
	public void save(F = std.stdio.File)(ref F file, int compLevel = 6) {
		RGB16_16_16BE fromNativeToBE(RGB16_16_16BE val) @nogc {
			version(LittleEndian) {
				val.r = swapEndian(val.r);
				val.g = swapEndian(val.g);
				val.b = swapEndian(val.b);
			}
			return val;
		}
		ubyte[] crc;
		ubyte[] imageTemp0 = _imageData.raw, imageTemp;
		ubyte[] scanline, prevScanline;
		prevScanline.length = pitch;	//First filter should be either none or sub, but not all writers are obeying the standard
		int wordlength = getBitdepth > 8 ? getBitdepth / 8 : 1;
		for (uint y ; y < height ; y++) {
			scanline = imageTemp0[(y * pitch)..((y + 1) * pitch)];
			switch(filterBytes[y]) {
				case FilterType.Sub:
					imageTemp ~= filterScanlineSub(scanline, wordlength);
					break;
				case FilterType.Up:
					imageTemp ~= filterScanlineUp(scanline, prevScanline);
					break;
				case FilterType.Average:
					imageTemp ~= filterScanlineAverage(scanline, prevScanline, wordlength);
					break;
				case FilterType.Paeth:
					imageTemp ~= filterScanlinePaeth(scanline, prevScanline, wordlength);
					break;
				default:
					imageTemp ~= scanline;
					break;
			}
			prevScanline = scanline;
		}
		assert(imageTemp0.length == imageTemp.length, "Image processing buffer error!");
		if (header.bitDepth == 16) {
			ushort[] arr = nativeStreamToBigEndian!ushort(reinterpretCast!ushort(imageTemp));
			imageTemp = reinterpretCast!ubyte(arr);
		}
		//write PNG signature into file
		file.rawWrite(PNG_SIGNATURE);
		//write Header into file
		void[] writeBuffer;
		//writeBuffer.length = 8;
		writeBuffer = cast(void[])[Chunk(header.sizeof, ChunkInitializers.Header).nativeToBigEndian];
		file.rawWrite(writeBuffer);
		//writeBuffer.length = 0;
		writeBuffer = cast(void[])[header.nativeToBigEndian];
		file.rawWrite(writeBuffer);
		crc = crc32Of((cast(ubyte[])ChunkInitializers.Header) ~ writeBuffer).dup.reverse;
		file.rawWrite(crc);
		//write any ancilliary chunks into the file that needs to stand before the palette
		foreach (curChunk; ancillaryChunks){
			if (curChunk.pos == EmbeddedData.DataPosition.BeforePLTE){
				writeBuffer = cast(void[])[Chunk(cast(uint)curChunk.data.length, curChunk.identifier).nativeToBigEndian];
				file.rawWrite(writeBuffer);
				file.rawWrite(curChunk.data);
				crc = crc32Of((cast(ubyte[])curChunk.identifier) ~ curChunk.data).dup.reverse;
				file.rawWrite(crc);
			}
		}
		//write palette into file if exists
		if (_palette) {
			ubyte[] paletteData, transparencyData;
			if (_palette.paletteFormat & PixelFormat.SeparateAlphaField) {
				paletteData = _palette.raw[0.._palette.length * 3];
				transparencyData = _palette.raw[_palette.length * 3..$];
			} else {
				paletteData = _palette.raw;
			}
			writeBuffer = cast(void[])[Chunk(cast(uint)paletteData.length, ChunkInitializers.Palette).nativeToBigEndian];
			file.rawWrite(writeBuffer);
			file.rawWrite(paletteData);
			crc = crc32Of((cast(ubyte[])ChunkInitializers.Palette) ~ paletteData).dup.reverse;
			file.rawWrite(crc);
			if (transparencyData.length) {
				writeBuffer = cast(void[])
						[Chunk(cast(uint)transparencyData.length, ChunkInitializers.Transparency).nativeToBigEndian];
				file.rawWrite(writeBuffer);
				file.rawWrite(transparencyData);
				crc = crc32Of((cast(ubyte[])ChunkInitializers.Transparency) ~ transparencyData).dup.reverse;
				file.rawWrite(crc);
			}
		}
		if (flags & 1) {
			ubyte[] transparencyData;
			RGB16_16_16BE nativeTrns = fromNativeToBE(trns);
			if(header.colorType == ColorType.Greyscale) {
				transparencyData = reinterpretAsArray!ubyte(nativeTrns.r);
			} else {
				transparencyData = reinterpretAsArray!ubyte(nativeTrns);
			}
			writeBuffer = cast(void[])[Chunk(cast(uint)transparencyData.length, 
					ChunkInitializers.Transparency).nativeToBigEndian];
			file.rawWrite(writeBuffer);
			file.rawWrite(transparencyData);
			crc = crc32Of((cast(ubyte[])ChunkInitializers.Transparency) ~ transparencyData).dup.reverse;
			file.rawWrite(crc);
		}
		if (bkgIndex != -1) {
			if (bkgIndex == -2) {
				ubyte[] transparencyData;
				RGB16_16_16BE nativeTrns = fromNativeToBE(trns);
				if(header.colorType == ColorType.Greyscale) {
					transparencyData = reinterpretAsArray!ubyte(nativeTrns.r);
				} else {
					transparencyData = reinterpretAsArray!ubyte(nativeTrns);
				}
				writeBuffer = cast(void[])[Chunk(cast(uint)transparencyData.length, 
						ChunkInitializers.Background).nativeToBigEndian];
				file.rawWrite(writeBuffer);
				file.rawWrite(transparencyData);
				crc = crc32Of((cast(ubyte[])ChunkInitializers.Transparency) ~ transparencyData).dup.reverse;
				file.rawWrite(crc);
			} else {
				writeBuffer = cast(void[])[Chunk(cast(uint)ubyte.sizeof, ChunkInitializers.Background).nativeToBigEndian];
				file.rawWrite(writeBuffer);
				writeBuffer = reinterpretAsArray!void(cast(ubyte)bkgIndex);
				file.rawWrite(writeBuffer);
				crc = crc32Of((cast(ubyte[])ChunkInitializers.Background) ~ cast(ubyte[])writeBuffer).dup.reverse;
				file.rawWrite(crc);
			}
		}
		//write any ancilliary chunks into the file that needs to stand before the imagedata
		foreach (curChunk; ancillaryChunks){
			if (curChunk.pos == EmbeddedData.DataPosition.BeforeIDAT){
				writeBuffer = cast(void[])[Chunk(cast(uint)curChunk.data.length, curChunk.identifier).nativeToBigEndian];
				file.rawWrite(writeBuffer);
				file.rawWrite(curChunk.data);
				crc = crc32Of((cast(ubyte[])curChunk.identifier) ~ curChunk.data).dup.reverse;
				file.rawWrite(crc);
			}
		}
		//compress imagedata if needed, then write it into the file
		{	
			int ret;
			ubyte[] input, output;
			input.reserve(imageTemp.length + filterBytes.length);
			for (int line ; line < height ; line++){
				const size_t offset = line * pitch;
				input ~= filterBytes[line];
				input ~= imageTemp[offset..offset+pitch];
			}
    		
    		zlib.z_stream strm;
			ret = zlib.deflateInit(&strm, compLevel);
			if (ret != zlib.Z_OK)
				throw new Exception("Compressor initialization error");	
			output.length = 32 * 1024;//cast(uint)imageTemp.length;
			strm.next_in = input.ptr;
			strm.avail_in = cast(uint)input.length;
			strm.next_out = output.ptr;
			strm.avail_out = cast(uint)output.length;
			do {
				if (!strm.avail_out) {
					writeBuffer = cast(void[])[Chunk(cast(uint)output.length, ChunkInitializers.Data).nativeToBigEndian];
					file.rawWrite(writeBuffer);
					file.rawWrite(output);
					crc = crc32Of((cast(ubyte[])ChunkInitializers.Data) ~ output).dup.reverse;
					file.rawWrite(crc);
					strm.next_out = output.ptr;
					strm.avail_out = cast(uint)output.length;
				}
				ret = zlib.deflate(&strm, zlib.Z_FINISH);
				if(ret < 0){
					zlib.deflateEnd(&strm);
					throw new Exception("Compressor output error: " ~ cast(string)std.string.fromStringz(strm.msg));
				}
			} while (ret != zlib.Z_STREAM_END);
			//write any ancilliary chunks into the file that needs to stand within the imagedata
			foreach (curChunk; ancillaryChunks){
				if (curChunk.pos == EmbeddedData.DataPosition.WithinIDAT){
					writeBuffer = cast(void[])[Chunk(cast(uint)curChunk.data.length, curChunk.identifier).nativeToBigEndian];
					file.rawWrite(writeBuffer);
					file.rawWrite(curChunk.data);
					crc = crc32Of((cast(ubyte[])curChunk.identifier) ~ curChunk.data).dup.reverse;
					file.rawWrite(crc);
				}
			}
			if (strm.avail_out != output.length) {
				writeBuffer = cast(void[])
						[Chunk(cast(uint)(output.length - strm.avail_out), ChunkInitializers.Data).nativeToBigEndian];
				file.rawWrite(writeBuffer);
				file.rawWrite(output[0..$-strm.avail_out]);
				crc = crc32Of((cast(ubyte[])ChunkInitializers.Data) ~ output[0..$-strm.avail_out]).dup.reverse;
				file.rawWrite(crc);
			}
			zlib.deflateEnd(&strm);
		}
		//write any ancilliary chunks into the file that needs to stand after the imagedata
		foreach (curChunk; ancillaryChunks){
			if (curChunk.pos == EmbeddedData.DataPosition.AfterIDAT){
				writeBuffer = cast(void[])[Chunk(cast(uint)curChunk.data.length, curChunk.identifier).nativeToBigEndian];
				file.rawWrite(writeBuffer);
				file.rawWrite(curChunk.data);
				crc = crc32Of((cast(ubyte[])curChunk.identifier) ~ curChunk.data).dup.reverse;
				file.rawWrite(crc);
			}
		}
		//write IEND chunk
		//writeBuffer.length = 0;
		writeBuffer = cast(void[])[Chunk(0, ChunkInitializers.End).nativeToBigEndian];
		file.rawWrite(writeBuffer);
		file.rawWrite(PNG_CLOSER);
	}
	/**
	 * Encodes a scanline using `Sub` filter.
	 */
	protected static ubyte[] filterScanlineSub(ubyte[] target, int bytedepth) @safe nothrow {
		ubyte[] result;
		result.length = target.length;
		for (size_t i ; i < target.length ; i++) {
			const ubyte a = i >= bytedepth ? target[i - bytedepth] : 0;
			result[i] = cast(ubyte)(target[i] - a);
		}
		return result;
	}
	/**
	 * Encodes a scanline using `Up` filter.
	 */
	protected static ubyte[] filterScanlineUp(ubyte[] target, ubyte[] prevScanline) @safe nothrow {
		ubyte[] result;
		result.length = target.length;
		for (size_t i ; i < target.length ; i++) {
			result[i] = cast(ubyte)(target[i] - prevScanline[i]);
		}
		return result;
	}
	/**
	 * Encodes a scanline using `Average` filter.
	 */
	protected static ubyte[] filterScanlineAverage(ubyte[] target, ubyte[] prevScanline, int bytedepth) @safe nothrow {
		ubyte[] result;
		result.length = target.length;
		for (size_t i ; i < target.length ; i++) {
			const uint a = i >= bytedepth ? target[i - bytedepth] : 0;
			result[i] = cast(ubyte)(target[i] - ((a + prevScanline[i])>>>1));
		}
		return result;
	}
	/**
	 * Encodes a scanline using `Paeth` filter.
	 */
	protected static ubyte[] filterScanlinePaeth(ubyte[] target, ubyte[] prevScanline, int bytedepth) @safe nothrow {
		ubyte[] result;
		result.length = target.length;
		for (size_t i ; i < target.length ; i++) {
			const ubyte a = i >= bytedepth ? target[i - bytedepth] : 0, b = prevScanline[i], 
					c = i >= bytedepth ? prevScanline[i - bytedepth] : 0;
			result[i] = cast(ubyte)(target[i] - paethFunc(a, b, c));
			
		}
		return result;
	}
	/**
	 * Adds an ancillary chunk to the PNG file
	 */
	public void addAncilliaryChunk(EmbeddedData.DataPosition pos, char[4] identifier, ubyte[] data){
		ancillaryChunks ~= new EmbeddedData(pos, identifier, data);
	}
	override uint width() @nogc @safe @property const pure{
		return header.width;
	}
	override uint height() @nogc @safe @property const pure{
		return header.height;
	}
	override bool isIndexed() @nogc @safe @property const pure{
		return header.colorType == ColorType.Indexed;
	}
	override ubyte getBitdepth() @nogc @safe @property const pure{
		switch(header.colorType){
			case ColorType.GreyscaleWithAlpha:
				return cast(ubyte)(header.bitDepth * 2);
			case ColorType.TrueColor:
				return cast(ubyte)(header.bitDepth * 3);
			case ColorType.TrueColorWithAlpha:
				return cast(ubyte)(header.bitDepth * 4);
			default:
				return header.bitDepth;
		}
	}
	override ubyte getPaletteBitdepth() @nogc @safe @property const pure{
		if (_palette) return _palette.bitDepth;
		else return 0;
	}
	override uint getPixelFormat() @nogc @safe @property const pure{
		switch (header.colorType){
			case ColorType.Indexed:
				switch (header.bitDepth) {
					case 1: return PixelFormat.Indexed1Bit;
					case 2: return PixelFormat.Indexed2Bit;
					case 4: return PixelFormat.Indexed4Bit;
					case 8: return PixelFormat.Indexed8Bit;
					default: return PixelFormat.Undefined;
				}
			case ColorType.GreyscaleWithAlpha: 
				if (header.bitDepth) return PixelFormat.YA88 | PixelFormat.BigEndian;
				else return PixelFormat.YA16_16 | PixelFormat.BigEndian;
			case ColorType.Greyscale: 
				switch (header.bitDepth) {
					case 1: return PixelFormat.Grayscale1Bit;
					case 2: return PixelFormat.Grayscale2Bit;
					case 4: return PixelFormat.Grayscale4Bit;
					case 8: return PixelFormat.Grayscale8Bit;
					case 16: return PixelFormat.Grayscale16Bit;
					default: return PixelFormat.Undefined;
				}
			case ColorType.TrueColor:
				switch (header.bitDepth) {
					case 8: return PixelFormat.RGB888 | PixelFormat.BigEndian;
					case 16: return PixelFormat.RGB16_16_16 | PixelFormat.BigEndian;
					default: return PixelFormat.RGBX5551;
				}
			case ColorType.TrueColorWithAlpha:
				switch (header.bitDepth) {
					case 8: return PixelFormat.RGBA8888 | PixelFormat.BigEndian | PixelFormat.ValidAlpha;
					case 16: return PixelFormat.RGBA16_16_16_16 | PixelFormat.BigEndian | PixelFormat.ValidAlpha;
					default: return PixelFormat.Undefined;
				}
			default: return PixelFormat.Undefined;
		}
	}
	override uint getPalettePixelFormat() @nogc @safe @property const pure{
		if (_palette) return _palette.paletteFormat;
		else return PixelFormat.Undefined;
	}
	/**
	 * Returns the header.
	 */
	public ref Header getHeader() @nogc @safe pure{
		return header;
	}
	
	public uint getCurrentImage() @safe pure {
		return uint.init; // TODO: implement
	}
	
	public uint setCurrentImage(uint frame) @safe pure {
		return uint.init; // TODO: implement
	}
	///Sets the current image to the static if available
	public void setStaticImage() @safe pure {

	}
	public uint nOfImages() @property @safe @nogc pure const {
		return cast(uint)(frames.length + 1);
	}
	
	public uint frameTime() @property @safe @nogc pure const {
		return uint.init; // TODO: implement
	}
	
	public bool isAnimation() @property @safe @nogc pure const {
		return frames.length ? true : false;
	}
	
	public string getMetadata(string id) @safe pure {
		foreach (Text key; textData) {
			if (key.keyword == id)
				return key.text;
		}
		return null;
	}
	
	public string setMetadata(string id, string val) @safe pure {
		foreach (ref Text key; textData) {
			if (key.keyword == id)
				return key.text = val;
		}
		textData ~= Text (id, val, null, null, 0, 0);
		return val;
	}
	
	public string getID() @safe pure {
		return getMetadata("Title");
	}
	
	public string getAuthor() @safe pure {
		return getMetadata("Author");
	}
	
	public string getComment() @safe pure {
		return getMetadata("Comment");
	}
	
	public string getJobName() @safe pure {
		return getMetadata("Job Name");
	}
	
	public string getSoftwareInfo() @safe pure {
		return getMetadata("Software");
	}
	
	public string getSoftwareVersion() @safe pure {
		return getMetadata("Software Version");
	}
	
	public string getDescription() @safe pure {
		return getMetadata("Description");
	}
	
	public string getSource() @safe pure {
		return getMetadata("Source");
	}
	
	public string getCopyright() @safe pure {
		return getMetadata("Copyright");
	}
	
	public string getCreationTimeStr() @safe pure {
		return getMetadata("Creation Time");
	}
	
	public string setID(string val) @safe pure {
		return setMetadata("Title", val);
	}
	
	public string setAuthor(string val) @safe pure {
		return setMetadata("Author", val);
	}
	
	public string setComment(string val) @safe pure {
		return setMetadata("Comment", val);
	}
	
	public string setJobName(string val) @safe pure {
		return setMetadata("Job Name", val);
	}
	
	public string setSoftwareInfo(string val) @safe pure {
		return setMetadata("Software", val);
	}
	
	public string setSoftwareVersion(string val) @safe pure {
		return setMetadata("Software Version", val);
	}
	
	public string setDescription(string val) @safe pure {
		return setMetadata("Description", val);
	}
	
	public string setSource(string val) @safe pure {
		return setMetadata("Source", val);
	}
	
	public string setCopyright(string val) @safe pure {
		return setMetadata("Copyright", val);
	}
	
	public string setCreationTime(string val) @safe pure {
		return setMetadata("Creation Time", val);
	}
	
	
	
}

unittest{
	import vfile;
	import dimage.tga;
	{
		std.stdio.File indexedPNGFile = std.stdio.File("./test/png/MARBLE24.PNG");
		std.stdio.writeln("Loading ", indexedPNGFile.name);
		PNG a = PNG.load(indexedPNGFile);
		std.stdio.writeln("File `", indexedPNGFile.name, "` successfully loaded");
		assert(a.getBitdepth == 24, "Bitdepth error!");
		//std.stdio.File output = std.stdio.File("./test/png/output.png", "wb");
		//a.save(output);
		VFile virtualIndexedPNGFile;
		a.save(virtualIndexedPNGFile);
		std.stdio.writeln("Successfully saved to virtual file ", virtualIndexedPNGFile.size);
		virtualIndexedPNGFile.seek(0);
		PNG b = PNG.load(virtualIndexedPNGFile);
		std.stdio.writeln("Image restored from virtual file");
		compareImages(a, b);
		std.stdio.writeln("The two images' output match");
	}
	/+{
		std.stdio.File indexedPNGFile = std.stdio.File("./test/png/MARBLE8.png");
		std.stdio.writeln("Loading ", indexedPNGFile.name);
		PNG a = PNG.load(indexedPNGFile);
		std.stdio.writeln("File `", indexedPNGFile.name, "` successfully loaded");
		//std.stdio.writeln(a.filterBytes);
		//std.stdio.File output = std.stdio.File("./test/png/output.png", "wb");
		//a.save(output);
		VFile virtualIndexedPNGFile;
		a.save(virtualIndexedPNGFile);
		std.stdio.writeln("Successfully saved to virtual file ", virtualIndexedPNGFile.size);
		virtualIndexedPNGFile.seek(0);
		PNG b = PNG.load(virtualIndexedPNGFile);
		std.stdio.writeln("Image restored from virtual file");
		compareImages(a, b);
		std.stdio.writeln("The two images' output match");
	}+/
	//test indexed png files and their palettes
	{
		std.stdio.File indexedPNGFile = std.stdio.File("./test/png/sci-fi-tileset.png");
		std.stdio.writeln("Loading ", indexedPNGFile.name);
		PNG a = PNG.load(indexedPNGFile);
		std.stdio.writeln("File `", indexedPNGFile.name, "` successfully loaded");
		//std.stdio.File output = std.stdio.File("./test/png/output.png", "wb");
		//a.save(output);
		IPalette p = a.palette;
		assert(p.convTo(PixelFormat.ARGB8888).length == p.length);
		assert(p.convTo(PixelFormat.ARGB8888 | PixelFormat.BigEndian).length == p.length);
	}
	//test loading and saving multiple images
	const string[] filenames = ["basn0g01.png", "basn0g02.png", "basn0g04.png", "basn0g08.png", "basn0g16.png", 
			"basn2c08.png", "basn2c16.png", "basn3p01.png", "basn3p02.png", "basn3p04.png", "basn3p08.png",
			"basn4a08.png", "basn4a16.png", "basn6a08.png", "basn6a16.png"];
	foreach (fn ; filenames) {
		std.stdio.File sourceFile = std.stdio.File("./test/png/" ~ fn);
		std.stdio.writeln("Loading ", sourceFile.name);
		PNG a = PNG.load(sourceFile);
		std.stdio.writeln("File `", sourceFile.name, "` successfully loaded");
		//std.stdio.writeln(a.filterBytes);
		//std.stdio.File output = std.stdio.File("./test/png/output_" ~ fn, "wb"); 
		//a.save(output);
		VFile virtualPNGFile;
		a.save(virtualPNGFile);
		std.stdio.writeln("Successfully saved to virtual file ", virtualPNGFile.size);
		virtualPNGFile.seek(0);
		PNG b = PNG.load(virtualPNGFile);
		std.stdio.writeln("Image restored from virtual file");
		compareImages(a, b);
		std.stdio.writeln("The two images' output match");
		std.stdio.writeln("Reconstructing PNG from image data");
		PNG c = new PNG(a.imageData, a.palette);
		compareImages(a, c);
		virtualPNGFile = VFile.init;
		c.save(virtualPNGFile);
		//output.rewind();
		virtualPNGFile.seek(0);
		b = PNG.load(virtualPNGFile);
		std.stdio.writeln("Image restored from virtual file");
		compareImages(a, b);
		std.stdio.writeln("The two images' output match");
	}
	//test against TGA versions of the same images
	/* {
		std.stdio.File tgaSource = std.stdio.File("./test/tga/mapped_8.tga");
		std.stdio.File pngSource = std.stdio.File("./test/png/mapped_8.png");
		std.stdio.writeln("Loading ", tgaSource.name);
		TGA tgaImage = TGA.load(tgaSource);
		std.stdio.writeln("Loading ", pngSource.name);
		PNG pngImage = PNG.load(pngSource);
		compareImages!true(tgaImage, pngImage);
	} */
	{
		std.stdio.File tgaSource = std.stdio.File("./test/tga/truecolor_24.tga");
		std.stdio.File pngSource = std.stdio.File("./test/png/truecolor_24.png");
		std.stdio.writeln("Loading ", tgaSource.name);
		TGA tgaImage = TGA.load(tgaSource);
		std.stdio.writeln("Loading ", pngSource.name);
		PNG pngImage = PNG.load(pngSource);
		compareImages!true(tgaImage, pngImage);
	}
	{
		std.stdio.File tgaSource = std.stdio.File("./test/tga/truecolor_32.tga");
		std.stdio.File pngSource = std.stdio.File("./test/png/truecolor_32.png");
		std.stdio.writeln("Loading ", tgaSource.name);
		TGA tgaImage = TGA.load(tgaSource);
		std.stdio.writeln("Loading ", pngSource.name);
		PNG pngImage = PNG.load(pngSource);
		compareImages!true(tgaImage, pngImage);
	}
	{	//BUG #1: flipHorizontal() reads out of bounds
		std.stdio.File pngSource = std.stdio.File("./test/png/verysmol.png");
		PNG pngImage = PNG.load(pngSource);
		pngImage.flipHorizontal();
	}
}
