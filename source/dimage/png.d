/*
 * dimage - png.d
 * by Laszlo Szeremi
 *
 * Copyright under Boost Software License.
 */

module dimage.png;

import dimage.base;

import zlib = std.zlib;
import std.digest.crc;
import std.bitmanip;
import std.algorithm.mutation : reverse;
static import std.stdio;
import std.string : fromStringz;
import core.stdc.stdint;
/**
 * Implements the Portable Network Graphics file format as a class.
 */
public class PNG : Image{
	static enum HEADER_INIT = "IHDR";		///Initializes header in the file
	static enum PALETTE_INIT = "PLTE";		///Initializes palette in the file
	static enum DATA_INIT = "IDAT";			///Initializes image data in the file
	static enum END_INIT = "IEND";			///Initializes the end of the file
	static enum ubyte[8] PNG_SIGNATURE = [0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A];	///Used for checking PNG files
	static enum ubyte[4] PNG_CLOSER = [0xAE, 0x42, 0x60, 0x82];		///Final checksum of IEND
	/+/// *.png signature
	struct PngSignature{
		byte[8] signature;  /// Identifier (always 89504E470D0A1A0Ah) 
	}+/
	/**
	 * PNG Chunk identifier
	 */
	struct Chunk{
		uint		dataLength;
		char[4] 	identifier;
		/**
		 * Converts the struct to little endian on systems that need them.
		 */
		public void bigEndianToNative(){
			version(LittleEndian)
				dataLength = swapEndian(dataLength);
		}
		/**
		 * Returns a copy of the struct that is in big endian.
		 */
		public Chunk nativeToBigEndian(){
			version(LittleEndian)
				return Chunk(swapEndian(dataLength), identifier);
			else
				return this;
		}
	}
	/**
	 * Contains most data related to PNG files.
	 */
	struct Header{
		uint width;        /// Width of image in pixels 
    	uint height;       /// Height of image in pixels 
    	ubyte bitDepth;      /// Bits per pixel or per sample
    	ubyte colorType;     /// Color interpretation indicator
    	ubyte compression;   /// Compression type indicator
    	ubyte filter;        /// Filter type indicator
    	ubyte interlace;     /// Type of interlacing scheme used
		/**
		 * Converts the struct to little endian on systems that need them.
		 */
		public void bigEndianToNative(){
			version(LittleEndian){
				width = swapEndian(width);
				height = swapEndian(height);
			}
		}
		/**
		 * Returns a copy of the struct that is in big endian.
		 */
		public Header nativeToBigEndian(){
			version(LittleEndian)
				return Header(swapEndian(width), swapEndian(height), bitDepth, colorType, compression, filter, interlace);
			else
				return this;
		}
		/**
		 * For debugging purposes.
		 */
		public string toString(){
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
	protected Header header;
	public this(int width, int height, ubyte bitDepth, ubyte colorType, ubyte compression, ubyte[] imageData, 
			ubyte[] paletteData = []){
		header = Header(width, height, bitDepth, colorType, compression, 0, 0);
	}
	protected this(){

	}
	/**
	 * Loads a PNG file.
	 * Currently interlaced mode is unsupported.
	 */
	static PNG load(F = std.stdio.File, bool chksmTest = true)(ref F file){
		PNG result = new PNG();
		bool iend;
		ubyte[] readBuffer;
		readBuffer.length = 8;
		file.rawRead(readBuffer);
		for(int i ; i < 8 ; i++)
			if(readBuffer[i] != PNG_SIGNATURE[i])
				throw new ImageFormatException("Invalid PNG file signature");
		do{
			ubyte[4] crc;
			file.rawRead(readBuffer);
			Chunk curChunk = (cast(Chunk[])(cast(void[])readBuffer))[0];
			curChunk.bigEndianToNative();
			readBuffer.length = curChunk.dataLength;
			if(curChunk.dataLength)
				file.rawRead(readBuffer);
			switch(curChunk.identifier){
				case HEADER_INIT:
					result.header = *(cast(Header*)(cast(void*)readBuffer.ptr));
					result.header.bigEndianToNative;
					break;
				case PALETTE_INIT:
					result.paletteData = readBuffer.dup;
					break;
				case DATA_INIT:
					result.imageData ~= readBuffer.dup;
					break;
				case END_INIT:
					iend = true;
					break;
				default:
					//Leave unknown chunks alone
					break;
			}
			//calculate crc
			if(curChunk.dataLength){
				crc = crc32Of(readBuffer);
				readBuffer.length = 4;
				file.rawRead(readBuffer);
				readBuffer.reverse;
				static if(chksmTest)
					if(readBuffer != crc)
						throw new ChecksumMismatchException("Checksum error");
			}
			readBuffer.length = 8;
		}while(!iend);
		result.imageData = cast(ubyte[])zlib.uncompress(result.imageData, (result.header.width * result.header.height * 
				result.header.bitDepth)/8);
		version(unittest){
			std.stdio.writeln(result.header.toString);
			std.stdio.writeln(result.imageData.length);
		}
		assert(result.imageData.length >= (result.header.width * result.header.height * result.header.bitDepth)/8);
		result.imageData.length = (result.header.width * result.header.height * result.header.bitDepth)/8;
		return result;
	}
	/**
	 * Saves the file to the disk.
	 * Currently interlaced mode is unsupported.
	 */
	public void save(F = std.stdio.File)(ref F file, int compLevel = 9){
		ubyte[] crc;
		//write PNG signature into file
		file.rawWrite(PNG_SIGNATURE);
		//write Header into file
		void[] writeBuffer;
		//writeBuffer.length = 8;
		writeBuffer ~= cast(void[])[Chunk(header.sizeof, HEADER_INIT).nativeToBigEndian];
		file.rawWrite(writeBuffer);
		writeBuffer.length = 0;
		writeBuffer ~= cast(void[])[header.nativeToBigEndian];
		file.rawWrite(writeBuffer);
		crc = crc32Of(writeBuffer).dup.reverse;
		file.rawWrite(crc);
		//write palette into file if exists
		if(paletteData.length){
			writeBuffer.length = 0;
			writeBuffer ~= cast(void[])[Chunk(cast(uint)paletteData.length, PALETTE_INIT).nativeToBigEndian];
			file.rawWrite(writeBuffer);
			file.rawWrite(paletteData);
			crc = crc32Of(paletteData).dup.reverse;
			file.rawWrite(crc);
		}
		//compress imagedata if needed, then write it into the file
		{	
			ubyte[] secBuf = zlib.compress(cast(void[])imageData, compLevel);
			writeBuffer.length = 0;
			writeBuffer ~= cast(void[])[Chunk(cast(uint)secBuf.length, DATA_INIT).nativeToBigEndian];
			file.rawWrite(writeBuffer);
			file.rawWrite(secBuf);
			crc = crc32Of(secBuf).dup.reverse;
			file.rawWrite(crc);
		}
		//write IEND chunk
		writeBuffer.length = 0;
		writeBuffer ~= cast(void[])[Chunk(0, END_INIT).nativeToBigEndian];
		file.rawWrite(writeBuffer);
		file.rawWrite(PNG_CLOSER);
	}
	override int width() @nogc @safe @property const{
		return header.width;
	}
	override int height() @nogc @safe @property const{
		return header.height;
	}
	override bool isIndexed() @nogc @safe @property const{
		return header.colorType == 3;
	}
	override ubyte getBitdepth() @nogc @safe @property const{
		return header.bitDepth;
	}
	override ubyte getPaletteBitdepth() @nogc @safe @property const{
		return isIndexed ? 24 : 0;
	}
	override PixelFormat getPixelFormat() @nogc @safe @property const{
		return header.bitDepth == 16 ? PixelFormat.RGBX5551 : PixelFormat.Undefined;
	}
}

unittest{
	import std.conv : to;
	import vfile;
	void compareImages(Image a, Image b){
		assert(a.width == b.width);
		assert(a.height == b.height);
		//Check if the data in the two are identical
		for(ushort y; y < a.height; y++){
			for(ushort x; x < a.width; x++){
				assert(a.readPixel(x,y) == b.readPixel(x,y), "Error at position (" ~ to!string(x) ~ "," ~ to!string(y) ~ ")!");
			}
		}
	}
	{
		std.stdio.File indexedPNGFile = std.stdio.File("./test/png/MARBLE8.png");
		std.stdio.writeln("Loading ", indexedPNGFile.name);
		PNG a = PNG.load(indexedPNGFile);
		std.stdio.writeln("File `", indexedPNGFile.name, "` successfully loaded");
		std.stdio.File output = std.stdio.File("./test/png/output.png", "wb");
		a.save(output);
		/*VFile virtualIndexedPNGFile;
		a.save(virtualIndexedPNGFile);
		std.stdio.writeln("Successfully saved to virtual file ", virtualIndexedPNGFile.size);
		PNG b = PNG.load(virtualIndexedPNGFile);
		std.stdio.writeln("Image restored from virtual file");
		compareImages(a, b);
		std.stdio.writeln("The two images' output match");*/
	}
}