/*
 * dimage - tga.d
 * by Laszlo Szeremi
 *
 * Copyright under Boost Software License.
 */

module dimage.tga;

import std.bitmanip;
static import std.stdio;

public import dimage.base;
import dimage.util;

//import core.stdc.string;
import std.conv : to;

/**
 * Implements the Truevision Graphics bitmap file format (*.tga) with some extra capabilities at the cost
 * of making them unusable in applications not implementing these features:
 * <ul>
 * <li>Capability of storing 1, 2, and 4 bit indexed images.</li>
 * <li>External color map support.</li>
 * <li>More coming soon such as more advanced compression methods.</li>
 * </ul>
 * Accessing developer area is fully implemented, accessing extension area is partly implemented.
 */
public class TGA : Image, ImageMetadata{
	/**
	 * Implements Truevision Graphics bitmap header.
	 */
	public struct Header {
	align(1) :
		/**
		 * Defines the type of the color map.
		 */
		public enum ColorMapType{
			NoColorMapPresent		=	0,
			ColorMapPresent			=	1,
			/**
			 * In this case, the palette is stored in a *.pal file, colorMapLength specifies the lenght of the filename, and the usual colorMap field instead stores the filename.
			 */
			ExtColorMap				=	128,	
		}
		/**
		 * Defines the type of the image.
		 */
		enum ImageType : ubyte {
			NoData					=	0,
			UncompressedMapped		=	1,
			UncompressedTrueColor	=	2,
			UncompressedGrayscale	=	3,
			RLEMapped				=	9,	/// RLE in 8 bit chunks
			RLETrueColor			=	10,
			RLEGrayscale			=	11,
			/**
			 * RLE optimized for 4 bit bitmaps. Added by me. Also works with 2 and 1 bit bitmaps
			 * Packet layout:
			 * bits 0 - 3: index needs to written
			 * bits 4 - 7: repeated occurence of indexes + 1 (1-16)
			 */
			RLE4BitMapped			=	12,
			/**
			 * RLE optimized for 1 bit bitmaps. Added by me.
			 * Packet layout:
			 * Every odd numbered byte: n of zeros (0-255)
			 * Every even numbered byte: n of ones (0-255)
			 */
			RLE1BitMapped			=	13,
			/**
			 * Mapped image with Huffman-Delta-RLE compression.
			 * I can't find any info on how this works, so I currently just leaving it as a placeholder
			 */
			HDRLEMapped				=	32,
			/**
			 * Mapped image with Huffman-Delta-RLE compression with 4-pass quadtree-type process.
			 * I can't find any info on how this works, so I currently just leaving it as a placeholder
			 */
			HDRLEMappedQT			=	33
		}
		ubyte			idLength;           /// length in bytes
		ubyte			colorMapType;		/// See ColorMapType enumerator
		ubyte			imageType;			/// See ImageType enumerator
		ushort			colorMapOffset;     /// index of first actual map entry
		ushort			colorMapLength;     /// number of total entries (incl. skipped)
		ubyte			colorMapDepth;      /// bits per pixel (entry)
		ushort			xOrigin;			/// X origin of the image on the screen
		ushort			yOrigin;			/// Y origin of the image on the screen
		ushort			width;				/// Image width
		ushort			height;				/// Image height
		ubyte			pixelDepth;         /// bits per pixel
		//imageDescriptor:
		mixin(bitfields!(
			ubyte, "alphaChannelBits", 4, 
			bool , "rightSideOrigin", 1, 
			bool , "topOrigin", 1, 
			ubyte, "interleaving", 2, 
		));
		public string toString(){
			import std.conv : to;
			return 
			"idLength:" ~ to!string(idLength) ~ "\n" ~
			"colorMapType:" ~ to!string(colorMapType) ~ "\n" ~
			"imageType:" ~ to!string(imageType) ~ "\n" ~
			"colorMapOffset:" ~ to!string(colorMapOffset) ~ "\n" ~
			"colorMapLength:" ~ to!string(colorMapLength) ~ "\n" ~
			"colorMapDepth:" ~ to!string(colorMapDepth) ~ "\n" ~
			"xOrigin:" ~ to!string(xOrigin) ~ "\n" ~
			"yOrigin:" ~ to!string(yOrigin) ~ "\n" ~
			"width:" ~ to!string(width) ~ "\n" ~
			"height:" ~ to!string(height) ~ "\n" ~
			"pixelDepth:" ~ to!string(pixelDepth);
		}
	}
	/**
	 * Implements Truevision Graphics bitmap footer, which is used to indicate the locations of extra fields.
	 */
	struct Footer {
	align(1) :
		uint			extensionAreaOffset;				/// offset of the extensionArea, zero if doesn't exist
		uint			developerAreaOffset;				/// offset of the developerArea, zero if doesn't exist
		char[16]		signature = "TRUEVISION-XFILE";		/// if equals with "TRUEVISION-XFILE", it's the new format
		char			reserved = '.';						/// should be always a dot
		ubyte			terminator;							/// terminates the file, always null
		///Returns true if it's a valid TGA footer
		@property bool isValid(){
			return signature == "TRUEVISION-XFILE" && reserved == '.' && terminator == 0;
		}
	}
	/**
	 * Contains extended data, mostly metadata.
	 */
	struct ExtArea{
		/**
		 * Stores attributes about the alpha channel.
		 */
	    enum Attributes : ubyte{
	        NoAlpha                         =   0,
	        UndefinedAlphaCanBeIgnored      =   1,
	        UndefinedAlphaMustBePreserved   =   2,
	        UsefulAlpha                     =   4,
	        PreMultipliedAlpha              =   5
	    }
	align(1) :
	    ushort      size = cast(ushort)ExtArea.sizeof;	///size of this field (should be ExtArea.sizeof)
	    char[41]    authorName;				///Name of the author
	    char[324]   authorComments;			///Stores author comments
		/**
		 * Stores the datetime in the following format
		 * 0: Year
		 * 1: Month
		 * 2: Day
		 * 3: Hour
		 * 4: Minute
		 * 5: Second
		 */
	    ushort[6]   dateTimeStamp;			
	    char[41]    jobName;				///Name of the job
		/**
		 * Time of the job in the following format:
		 * 0: Hours
		 * 1: Minutes
		 * 2: Seconds
		 */
	    ushort[3]   jobTime;
	    char[41]    softwareID;				///Stores the name of the software
	    ushort      softwareVersNum;		///Stores the version of the software in a decimal system in the following format: 000.0.0
	    char        softwareVersChar;		///Stores the version of the software
	    ubyte[4]    keyColor;				///Key color, mostly used for greenscreening and similar thing
	    ushort      pixelWidth;				///Pixel width ratio
	    ushort      pixelHeight;			///Pixel height ratio
	    ushort      gammaNumerator;			///Gamma correction
	    ushort      gammaDenominator;		///Gamma correction
	    uint        colorCorrectionOffset;	///Color correction field. The library cannot process this information.
	    uint        postageStampOffset;		///Thumbnail image offset
	    uint        scanlineOffset;			///Fast access to scanline offsets. The library can create it and load it, but doesn't use it since it decompresses RLE images upon load
	    ubyte       attributes;				///Information on the alpha channel
	}
	/**
	 * Identifies the embedded data.
	 */
	struct DevAreaTag{
	    ushort          reserved;       /// number of tags in the beginning
	    /**
	     * Identifier tag of the developer area field.
	     * Supposedly the range of 32768 - 65535 is reserved by Truevision, however there are no information on whenever it was
	     * used by them or not.
	     */
	    ushort          tag;            
	    uint            offset;         /// offset into file
	    uint            fieldSize;      /// field size in bytes
	}
	/**
	 * Represents embedded data within the developer area
	 */
	struct DevArea{
	    ubyte[] data;

	    /**
	     * Returns the data as a certain type (preferrably struct) if available
	     */
	    T get(T)(){
	        if(T.sizeof == data.length){
	            return cast(T)(cast(void[])data);
	        }
	    }
	}
	protected Header		header;
	protected Footer		footer;
	protected char[]		imageID;
	protected ExtArea[]		extensionArea;
	protected DevAreaTag[]	developerAreaTags;
	protected DevArea[]		developerArea;
	public uint[]			scanlineTable;				///stores offset to scanlines
    public ubyte[]			postageStampImage;			///byte 0 is width, byte 1 is height
    public ushort[]			colorCorrectionTable;		///color correction table
	/**
	 * Creates a TGA object without a footer.
	 */
	public this(Header header, ubyte[] imageData, ubyte[] paletteData = null, char[] imageID = null){
		this.header = header;
		this.imageData = imageData;
		this.paletteData = paletteData;
		this.imageID = imageID;
	}
	/**
	 * Creates a TGA object with a footer.
	 */
	public this(Header header, Footer footer, ubyte[] imageData, ubyte[] paletteData = null, char[] imageID = null){
		this.header = header;
		this.footer = footer;
		this.imageData = imageData;
		this.paletteData = paletteData;
		this.imageID = imageID;
	}
	/**
	 * Loads a Truevision TARGA file and creates a TGA object.
	 * FILE can be either std.stdio's file, my own implementation of a virtual file (see ziltoid1991/vfile), or any compatible solution.
	 */
	public static TGA load(FILE = std.stdio.File, bool loadDevArea = true, bool loadExtArea = true)(ref FILE file){
		import std.stdio;
		ubyte[] loadRLEImageData(const ref Header header){
			size_t target = header.width * header.height;
			const size_t bytedepth = header.pixelDepth >= 8 ? (header.pixelDepth / 8) : 1;
			target >>= header.pixelDepth < 8 ? 1 : 0;
			target >>= header.pixelDepth < 4 ? 1 : 0;
			target >>= header.pixelDepth < 2 ? 1 : 0;
			ubyte[] result, dataBuffer;
			result.reserve(header.pixelDepth >= 8 ? target * bytedepth : target);
			switch(header.pixelDepth){
				case 15, 16:
					dataBuffer.length = 3;
					break;
				case 24:
					dataBuffer.length = 4;
					break;
				case 32:
					dataBuffer.length = 5;
					break;
				default:		//all indexed type having less than 8bits of depth use the same method of RLE as 8bit ones
					dataBuffer.length = 2;
					break;
			}
			while(result.length < target * bytedepth){
				file.rawRead(dataBuffer);
				if(dataBuffer[0] & 0b1000_0000){//RLE block
					dataBuffer[0] &= 0b0111_1111;
					dataBuffer[0]++;
					while(dataBuffer[0]){
						result ~= dataBuffer[1..$];
						dataBuffer[0]--;
						//target--;
					}
					//result ~= rleBlock;
				}else{//literal block
					dataBuffer[0] &= 0b0111_1111;
					//dataBuffer[0]--;
					ubyte[] literalBlock;
					literalBlock.length = (dataBuffer[0] * bytedepth);
					if(literalBlock.length)file.rawRead(literalBlock);
					result ~= dataBuffer[1..$] ~ literalBlock;
				}
			}
			//std.stdio.writeln(result.length, ";", (header.width * header.height * bytedepth));
			assert(result.length == (header.width * header.height * bytedepth), "RLE length mismatch error!");
			return result;
		}
		Header headerLoad;
		ubyte[] readBuffer;
		readBuffer.length = Header.sizeof;
		file.rawRead(readBuffer);
		headerLoad = reinterpretCast!Header(readBuffer)[0];
		char[] imageIDLoad;
		imageIDLoad.length = headerLoad.idLength;
		if(imageIDLoad.length) file.rawRead(imageIDLoad);
		//version(unittest) std.stdio.writeln(imageIDLoad);
		ubyte[] palette;
		palette.length = headerLoad.colorMapLength * (headerLoad.colorMapDepth / 8);
		if(palette.length) file.rawRead(palette);
		ubyte[] image;
		if(headerLoad.imageType >= Header.ImageType.RLEMapped && headerLoad.imageType <= Header.ImageType.RLEGrayscale){
			image = loadRLEImageData(headerLoad);
		}else{
			image.length = (headerLoad.width * headerLoad.height * headerLoad.pixelDepth) / 8;
			//version(unittest) std.stdio.writeln(headerLoad.toString);
			if(image.length) file.rawRead(image);
		}
		static if(loadExtArea || loadDevArea){
			Footer footerLoad;
			readBuffer.length = Footer.sizeof;
			file.seek(Footer.sizeof * -1, SEEK_END);
			file.rawRead(readBuffer);
			footerLoad = reinterpretCast!Footer(readBuffer)[0];
			TGA result = new TGA(headerLoad, footerLoad, image, palette, imageIDLoad);
			if(footerLoad.isValid){
				static if(loadDevArea){
					if(footerLoad.developerAreaOffset){
						file.seek(footerLoad.developerAreaOffset);
						result.developerAreaTags.length = 1;
						file.rawRead(result.developerAreaTags);
						result.developerAreaTags.length = result.developerAreaTags[0].reserved;
						file.rawRead(result.developerAreaTags[1..$]);
						result.developerArea.reserve = result.developerAreaTags[0].reserved;
						ubyte[] dataBuffer;
						foreach(tag; result.developerAreaTags){
							file.seek(tag.offset);
							dataBuffer.length = tag.fieldSize;
							file.rawRead(dataBuffer);
							result.developerArea ~= DevArea(dataBuffer.dup);
						}
					}
				}
				static if(loadExtArea){
					if(footerLoad.extensionAreaOffset){
						file.seek(footerLoad.extensionAreaOffset);
						result.extensionArea.length = 1;
						file.rawRead(result.extensionArea);
						if(result.extensionArea[0].postageStampOffset){
							file.seek(result.extensionArea[0].postageStampOffset);
							result.postageStampImage.length = 2;
							file.rawRead(result.postageStampImage);
							result.postageStampImage.length = 2 + result.postageStampImage[0] * result.postageStampImage[1];
							file.rawRead(result.postageStampImage[2..$]);
						}
						if(result.extensionArea[0].colorCorrectionOffset){
							result.colorCorrectionTable.length = 1024;
							file.seek(result.extensionArea[0].colorCorrectionOffset);
							file.rawRead(result.colorCorrectionTable);
						}
						if(result.extensionArea[0].scanlineOffset){
							result.scanlineTable.length = headerLoad.height;
							file.seek(result.extensionArea[0].scanlineOffset);
							file.rawRead(result.scanlineTable);
						}
					}
				}
			}
			switch(headerLoad.pixelDepth){
				case 1:
					result.mod = 7;
					result.shift = 3;
					break;
				case 2:
					result.mod = 3;
					result.shift = 2;
					break;
				case 4:
					result.mod = 1;
					result.shift = 1;
					break;
				default:
					break;
			}
			return result;
		}else{
			return new TGA(headerLoad, image, palette, imageIDLoad);
		}
	}
	/**
	 * Saves the current TGA object into a Truevision TARGA file.
	 * If ignoreScanlineBounds is true, then the compression methods will ignore the scanline bounds, this disables per-line accessing, but enhances compression
	 * rates by a margin in exchange. If false, then it'll generate a scanline table.
	 */
	public void save(FILE = std.stdio.File, bool saveDevArea = false, bool saveExtArea = false, 
			bool ignoreScanlineBounds = false)(ref FILE file){
		import std.stdio;
		void compressRLE(){
			static if(!ignoreScanlineBounds){
				const uint maxScanlineLength = header.width;
				scanlineTable.length = 0;
				scanlineTable.reserve(height);
			}
			version(unittest) uint pixelCount;
			ubyte[] writeBuff;
			static if(!ignoreScanlineBounds)
				uint currScanlineLength;
			switch(header.pixelDepth){
				case 16:
					ushort* src = cast(ushort*)(cast(void*)imageData.ptr);
					const ushort* dest = src + (imageData.length / 2);
					writeBuff.length = 257;
					ushort* writeBuff0 = cast(ushort*)(cast(void*)writeBuff.ptr + 1);
					while(src < dest){
						ushort* currBlockBegin = src, currBlockEnd = src;
						if(currBlockBegin[0] == currBlockBegin[1]){	//RLE block
							ubyte blockLength;
							//while(src < dest && currBlockEnd[0] == currBlockEnd[1]){
							do{
								src++;
								currBlockEnd++;
								blockLength++;
								static if(!ignoreScanlineBounds){
									currScanlineLength++;
									if(currScanlineLength == maxScanlineLength){
										currScanlineLength = 0;
										scanlineTable ~= cast(uint)file.tell;
										break;
									}
								}
								if(blockLength == 128)
									break;
							}while(src < dest && currBlockBegin[0] == currBlockEnd[0]);
							version(unittest){
								import std.conv : to;
								pixelCount += blockLength;
								assert(pixelCount <= header.width * header.height, "Required size: " ~ to!string(header.width * header.height) 
										~ " Current size:" ~ to!string(pixelCount));
							}
							blockLength--;
							blockLength |= 0b1000_0000;
							writeBuff[0] = blockLength;
							writeBuff0[0] = currBlockBegin[0];
							file.rawWrite(writeBuff[0..3]);
						}else{		//literal block
							ubyte blockLength;
							
							//while(src < dest && currBlockEnd[0] != currBlockEnd[1]){
							do{
								writeBuff0[blockLength] = currBlockEnd[0];
								src++;
								currBlockEnd++;
								blockLength++;
								static if(!ignoreScanlineBounds){
									currScanlineLength++;
									if(currScanlineLength == maxScanlineLength){
										currScanlineLength = 0;
										break;
									}
								}
								if(blockLength == 128)
									break;
								//blockLength++;
							}while(src < dest && currBlockBegin[0] == currBlockEnd[0]);
							//writeBuff[1] = currBlockEnd[0];
							version(unittest){
								import std.conv : to;
								pixelCount += blockLength;
								//std.stdio.writeln(pixelCount);
								assert(pixelCount <= header.width * header.height, "Required size: " ~ to!string(header.width * header.height) 
										~ " Current size:" ~ to!string(pixelCount));
							}
							blockLength--;
							writeBuff[0] = blockLength;
							file.rawWrite(writeBuff[0..((blockLength * 2) + 3)]);
						}
					}
					break;
				case 24:
					Pixel24Bit* src = cast(Pixel24Bit*)(cast(void*)imageData.ptr);
					const Pixel24Bit* dest = src + (imageData.length / 3);
					writeBuff.length = 1;
					Pixel24Bit[] writeBuff0;
					writeBuff0.length = 128;
					while(src < dest){
						Pixel24Bit* currBlockBegin = src, currBlockEnd = src;
						if(currBlockBegin[0] == currBlockBegin[1]){	//RLE block
							ubyte blockLength;
							//while(src < dest && currBlockEnd[0] == currBlockEnd[1]){
							do{
								src++;
								currBlockEnd++;
								blockLength++;
								static if(!ignoreScanlineBounds){
									currScanlineLength++;
									if(currScanlineLength == maxScanlineLength){
										currScanlineLength = 0;
										scanlineTable ~= cast(uint)file.tell;
										break;
									}
								}
								if(blockLength == 128)
									break;
							}while(src < dest && currBlockBegin[0] == currBlockEnd[0]);
							version(unittest){
								import std.conv : to;
								pixelCount += blockLength;
								assert(pixelCount <= header.width * header.height, "Required size: " ~ to!string(header.width * header.height) 
										~ " Current size:" ~ to!string(pixelCount));
							}
							blockLength--;
							blockLength |= 0b1000_0000;
							writeBuff[0] = blockLength;
							writeBuff0[0] = currBlockBegin[0];
							file.rawWrite(writeBuff[0..1]);
							file.rawWrite(writeBuff0[0..1]);
						}else{		//literal block
							ubyte blockLength;
							
							//while(src < dest && currBlockEnd[0] != currBlockEnd[1]){
							do{
								writeBuff0[blockLength] = currBlockEnd[0];
								src++;
								currBlockEnd++;
								blockLength++;
								static if(!ignoreScanlineBounds){
									currScanlineLength++;
									if(currScanlineLength == maxScanlineLength){
										currScanlineLength = 0;
										break;
									}
								}
								if(blockLength == 128)
									break;
								//blockLength++;
							}while(src < dest && currBlockBegin[0] == currBlockEnd[0]);
							//writeBuff[1] = currBlockEnd[0];
							version(unittest){
								import std.conv : to;
								pixelCount += blockLength;
								assert(pixelCount <= header.width * header.height, "Required size: " ~ to!string(header.width * header.height) 
										~ " Current size:" ~ to!string(pixelCount));
							}
							blockLength--;
							writeBuff[0] = blockLength;
							file.rawWrite(writeBuff[0..1]);
							file.rawWrite(writeBuff0[0..(blockLength + 1)]);
						}
					}
					break;
				case 32:
					uint* src = cast(uint*)(cast(void*)imageData.ptr);
					const uint* dest = src + (imageData.length / 4);
					writeBuff.length = 1;
					uint[] writeBuff0;
					writeBuff0.length = 128;
					while(src < dest){
						uint* currBlockBegin = src, currBlockEnd = src;
						if(currBlockBegin[0] == currBlockBegin[1]){	//RLE block
							ubyte blockLength;
							//while(src < dest && currBlockEnd[0] == currBlockEnd[1]){
							do{
								src++;
								currBlockEnd++;
								blockLength++;
								static if(!ignoreScanlineBounds){
									currScanlineLength++;
									if(currScanlineLength == maxScanlineLength){
										currScanlineLength = 0;
										scanlineTable ~= cast(uint)file.tell;
										break;
									}
								}
								if(blockLength == 128)
									break;
							}while(src < dest && currBlockBegin[0] == currBlockEnd[0]);
							version(unittest){
								import std.conv : to;
								pixelCount += blockLength;
								assert(pixelCount <= header.width * header.height, "Required size: " ~ to!string(header.width * header.height) 
										~ " Current size:" ~ to!string(pixelCount));
							}
							blockLength--;
							blockLength |= 0b1000_0000;
							writeBuff[0] = blockLength;
							writeBuff0[0] = currBlockBegin[0];
							file.rawWrite(writeBuff[0..1]);
							file.rawWrite(writeBuff0[0..1]);
						}else{		//literal block
							ubyte blockLength;
							
							//while(src < dest && currBlockEnd[0] != currBlockEnd[1]){
							do{
								writeBuff0[blockLength] = currBlockEnd[0];
								src++;
								currBlockEnd++;
								blockLength++;
								static if(!ignoreScanlineBounds){
									currScanlineLength++;
									if(currScanlineLength == maxScanlineLength){
										currScanlineLength = 0;
										break;
									}
								}
								if(blockLength == 128)
									break;
								//blockLength++;
							}while(src < dest && currBlockBegin[0] == currBlockEnd[0]);
							//writeBuff[1] = currBlockEnd[0];
							version(unittest){
								import std.conv : to;
								pixelCount += blockLength;
								assert(pixelCount <= header.width * header.height, "Required size: " ~ to!string(header.width * header.height) 
										~ " Current size:" ~ to!string(pixelCount));
							}
							blockLength--;
							writeBuff[0] = blockLength;
							file.rawWrite(writeBuff[0..1]);
							file.rawWrite(writeBuff0[0..(blockLength + 1)]);
						}
					}
					break;
				default:
					ubyte* src = imageData.ptr;
					const ubyte* dest = src + imageData.length;
					writeBuff.length = 129;
					while(src < dest){
						ubyte* currBlockBegin = src, currBlockEnd = src;
						if(currBlockBegin[0] == currBlockBegin[1]){	//RLE block
							ubyte blockLength;
							//while(src < dest && currBlockEnd[0] == currBlockEnd[1]){
							do{
								src++;
								currBlockEnd++;
								blockLength++;
								static if(!ignoreScanlineBounds){
									currScanlineLength++;
									if(currScanlineLength == maxScanlineLength){
										currScanlineLength = 0;
										scanlineTable ~= cast(uint)file.tell;
										break;
									}
								}
								if(blockLength == 128)
									break;
							}while(src < dest && currBlockBegin[0] == currBlockEnd[0]);
							version(unittest){
								import std.conv : to;
								pixelCount += blockLength;
								assert(pixelCount <= imageData.length, "Required size: " ~ to!string(imageData.length) 
										~ " Current size:" ~ to!string(pixelCount));
							}
							blockLength--;
							blockLength |= 0b1000_0000;
							writeBuff[0] = blockLength;
							writeBuff[1] = currBlockBegin[0];
							file.rawWrite(writeBuff[0..2]);
						}else{		//literal block
							ubyte blockLength;
							
							//while(src < dest && currBlockEnd[0] != currBlockEnd[1]){
							do{
								writeBuff[1 + blockLength] = currBlockEnd[0];
								src++;
								currBlockEnd++;
								blockLength++;
								static if(!ignoreScanlineBounds){
									currScanlineLength++;
									if(currScanlineLength == maxScanlineLength){
										currScanlineLength = 0;
										break;
									}
								}
								if(blockLength == 128)
									break;
								//blockLength++;
							}while(src < dest && currBlockEnd[0] != currBlockEnd[1]);
							//writeBuff[1] = currBlockEnd[0];
							version(unittest){
								import std.conv : to;
								pixelCount += blockLength;
								assert(pixelCount <= imageData.length, "Required size: " ~ to!string(imageData.length) 
										~ " Current size:" ~ to!string(pixelCount));
							}
							blockLength--;
							writeBuff[0] = blockLength;
							file.rawWrite(writeBuff[0..blockLength + 2]);
						}
					}
					break;
			}
			version(unittest){
				import std.conv : to;
				assert(pixelCount == header.width * header.height, "Required size: " ~ to!string(header.width * 
						header.height) ~ " Current size:" ~ to!string(pixelCount));
			}
		}
		//write most of the data into the file
		file.rawWrite([header]);
		file.rawWrite(imageID);
		file.rawWrite(paletteData);
		if(header.imageType >= Header.ImageType.RLEMapped && header.imageType <= Header.ImageType.RLEGrayscale){
			compressRLE();
		}else{
			file.rawWrite(imageData);
		}
		static if(saveDevArea){
			if(developerAreaTags.length){
				//make all tags valid
				uint offset = cast(uint)file.tell;
				footer.developerAreaOffset = offset;
				offset += cast(uint)(developerAreaTags.length * DevAreaTag.sizeof);
				developerAreaTags[0].reserved = cast(ushort)developerAreaTags.length;
				for(int i; i < developerAreaTags.length; i++){
					developerAreaTags[i].offset = offset;
					developerAreaTags[i].fieldSize = developerArea[i].data.length;
					offset += developerArea[i].data.length;
				}
				file.rawWrite(developerAreaTags);
				foreach(d; developerArea){
					file.rawWrite(d.data);
				}
			}
		}
		static if(saveExtArea){
			if(extensionArea.length){
				uint offset = cast(uint)file.tell;
				footer.extensionAreaOffset = offset;
				offset += cast(uint)ExtArea.sizeof;
				if(colorCorrectionTable.length){
					extensionArea[0].colorCorrectionOffset = offset;
					offset += cast(uint)(colorCorrectionTable.length * ushort.sizeof);
				}else{
					extensionArea[0].colorCorrectionOffset = 0;
				}
				if(postageStampImage.length){
					extensionArea[0].postageStampOffset = offset;
					offset += cast(uint)(postageStampImage.length * ubyte.sizeof);
				}else{
					extensionArea[0].postageStampOffset = 0;
				}
				if(scanlineTable.length){
					extensionArea[0].scanlineOffset = offset;
					//offset += cast(uint)(scanlineTable.length * uint.sizeof);
				}else{
					extensionArea[0].scanlineOffset = 0;
				}
				file.rawWrite(extensionArea);
				assert(file.tell == footer.extensionAreaOffset);
				if (colorCorrectionTable.length){ 
					file.rawWrite(colorCorrectionTable);
					assert(file.tell == extensionArea[0].colorCorrectionOffset);
				}
				if (postageStampImage.length){ 
					file.rawWrite(postageStampImage);
					assert(file.tell == extensionArea[0].postageStampImage);
				}
				if (scanlineTable.length){ 
					file.rawWrite(scanlineTable);
					assert(file.tell == extensionArea[0].scanlineTable);
				}
			}
		}
		static if(saveExtArea || saveDevArea){
			file.rawWrite([footer]);
		}
	}
	override uint width() @nogc @safe @property const pure{
		return header.width;
	}
	override uint height() @nogc @safe @property const pure{
		return header.height;
	}
	override bool isIndexed() @nogc @safe @property const pure{
		return header.colorMapType != Header.ColorMapType.NoColorMapPresent;
	}
	override ubyte getBitdepth() @nogc @safe @property const pure{
		return header.pixelDepth;
	}
	override ubyte getPaletteBitdepth() @nogc @safe @property const pure{
		return header.colorMapDepth;
	}
	override uint getPixelFormat() @nogc @safe @property const pure{
		if(!Header.ColorMapType.NoColorMapPresent){
			return PixelFormat.Undefined;
		}else{
			switch(header.pixelDepth){
				case 16:
					return PixelFormat.RGBA5551;
				case 24:
					return PixelFormat.RGB888;
				case 32:
					return PixelFormat.ARGB8888;
				default:
					return PixelFormat.Undefined;
			}
		}
	}
	override uint getPalettePixelFormat() @nogc @safe @property const pure{
		if(Header.ColorMapType.NoColorMapPresent){
			return PixelFormat.Undefined;
		}else{
			switch(header.colorMapDepth){
				case 16:
					return PixelFormat.RGBA5551;
				case 24:
					return PixelFormat.RGB888;
				case 32:
					return PixelFormat.ARGB8888;
				default:
					return PixelFormat.Undefined;
			}
		}
	}
	/**
	 * Returns the pixel order for bitdepths less than 8. Almost excusively used for indexed bitmaps.
	 * Returns null if ordering not needed.
	 */
	override public ubyte[] getPixelOrder() @safe @property const{
		switch(header.pixelDepth){
			case 1: return pixelOrder1BitLE.dup;
			case 2: return pixelOrder2BitLE.dup;
			case 4: return pixelOrder4BitLE.dup;
			default: return [];
		}
	}
	/**
	 * Returns which pixel how much needs to be shifted right after a byteread.
	 */
	override public ubyte[] getPixelOrderBitshift() @safe @property const{
		switch(header.pixelDepth){
			case 1: return pixelShift1BitLE.dup;
			case 2: return pixelShift2BitLE.dup;
			case 4: return pixelShift4BitLE.dup;
			default: return [];
		}
	}
	public string getID() @safe{
		return to!string(imageID);
	}
	public string getAuthor() @safe{
		if(extensionArea.length)
			return extensionArea[0].authorName;
		return null;
	}
	public string getComment() @safe{
		if(extensionArea.length)
			return extensionArea[0].authorComments;
		return null;
	}
	public string getJobName() @safe{
		if(extensionArea.length)
			return extensionArea[0].jobName;
		return null;
	}
	public string getSoftwareInfo() @safe{
		if(extensionArea.length)
			return extensionArea[0].softwareID;
		return null;
	}
	public string getSoftwareVersion() @safe{
		import std.conv : to;
		if(extensionArea.length)
			return to!string(extensionArea[0].softwareVersNum / 100) ~ "." ~ to!string((extensionArea[0].softwareVersNum % 100) 
					/ 10) ~ "." ~ to!string(extensionArea[0].softwareVersNum % 10) ~ extensionArea[0].softwareVersChar;
		return null;
	}
	public void setID(string val) @safe{
		if(val.length > 255)
			throw new Exception("ID is too long");
		imageID = val.dup;
		header.idLength = cast(ubyte)val.length;
	}
	public void setAuthor(string val) @safe{
		if(val.length > 41)
			throw new Exception("Author name is too long");
		if(extensionArea.length){
			stringCpy(extensionArea[0].authorName, val);
		}
	}
	public void setComment(string val) @safe{
		if(val.length > 324)
			throw new Exception("Comment is too long");
		if(extensionArea.length){
			stringCpy(extensionArea[0].authorComments, val);
		}
	}
	public void setJobName(string val) @safe{
		if(val.length > 41)
			throw new Exception("Jobname is too long");
		if(extensionArea.length){
			stringCpy(extensionArea[0].jobName, val);
		}
	}
	public void setSoftwareInfo(string val) @safe{
		if(val.length > 41)
			throw new Exception("SoftwareID is too long");
		if(extensionArea.length){
			stringCpy(extensionArea[0].softwareID, val);
		}
	}
	///Format used: 0.0.0a
	public void setSoftwareVersion(string val) @safe{
		if(extensionArea.length){
			//separate first part with dot, then parse the number
			uint prelimiter;
			for( ; prelimiter < val.length ; prelimiter++){
				if(val[prelimiter] == '.')
					break;
			}
			uint resultI = to!uint(val[0..prelimiter]);
			resultI *= 10;
			for( ; prelimiter < val.length ; prelimiter++){
				if(val[prelimiter] == '.')
					break;
			}
			resultI += to!uint([val[prelimiter-1]]);
			resultI *= 10;
			if(val.length > prelimiter+1)
				resultI += to!uint([val[prelimiter+1]]);
			extensionArea[0].softwareVersNum = cast(ushort)resultI;
			if(val.length > prelimiter+2)
				extensionArea[0].softwareVersChar = val[prelimiter+2];
		}
	}
	/**
	 * Adds extension area for the file.
	 */
	public void createExtensionArea(){
		extensionArea.length = 1;
	}
	/**
	 * Returns the developer area info for the field.
	 */
	public DevAreaTag getDevAreaInfo(size_t n){
		return developerAreaTags[n];
	}
	/**
	 * Returns the embedded field.
	 */
	public DevArea getEmbeddedData(size_t n){
		return developerArea[n];
	}
	/**
	 * Creates an embedded field within the TGA file.
	 */
	public void addEmbeddedData(ushort ID, ubyte[] data){
		developerAreaTags ~= DevAreaTag(0, ID, 0, cast(uint)data.length);
		developerArea ~= DevArea(data);
	}
	/**
	 * Returns the image type.
	 */
	public ubyte getImageType() const @nogc @property @safe nothrow{
		return header.imageType;
	}
	/**
	 * Returns the header as a reference type.
	 */
	public ref Header getHeader() @nogc @safe nothrow{
		return header;
	}
	/**
	 * Flips the image on the vertical axis. Useful to set images to the correct top-left screen origin point.
	 */
	public override void flipVertical() @safe{
		header.topOrigin = !header.topOrigin;
		super.flipVertical;
	}
	/**
	 * Flips the image on the vertical axis. Useful to set images to the correct top-left screen origin point.
	 */
	public override void flipHorizontal() @safe{
		header.rightSideOrigin = !header.rightSideOrigin;
		super.flipHorizontal;
	}
}

unittest{
	import std.conv : to;
	import vfile;
	void compareImages(Image a, Image b){
		assert(a.width == b.width);
		assert(a.height == b.height);
		//Check if the data in the two are identical
		for (ushort y ; y < a.height ; y++) {
			for (ushort x ; x < a.width ; x++) {
				assert(a.readPixel(x,y) == b.readPixel(x,y), "Error at position (" ~ to!string(x) ~ "," ~ to!string(y) ~ ")!");
			}
		}
		if (a.isIndexed && b.isIndexed) {
			auto aPal = a.palette;
			auto bPal = b.palette;
			for (ushort i ; i < aPal.length ; i++) {
				assert(aPal[i] == bPal[i], "Error at position " ~ to!string(i) ~ "!");
			}
		}
	}
	assert(TGA.Header.sizeof == 18);
	//void[] tempStream;
	//test 8 bit RLE load for 8 bit greyscale and indexed
	{
		std.stdio.File greyscaleUncFile = std.stdio.File("test/tga/grey_8.tga");
		std.stdio.writeln("Loading ", greyscaleUncFile.name);
		TGA greyscaleUnc = TGA.load(greyscaleUncFile);
		std.stdio.writeln("File `", greyscaleUncFile.name, "` successfully loaded");
		std.stdio.File greyscaleRLEFile = std.stdio.File("test/tga/grey_8_rle.tga");
		std.stdio.writeln("Loading ", greyscaleRLEFile.name);
		TGA greyscaleRLE = TGA.load(greyscaleRLEFile);
		std.stdio.writeln("File `", greyscaleRLEFile.name, "` successfully loaded");
		compareImages(greyscaleUnc, greyscaleRLE);
		//store the uncompressed one as a VFile in the memory using RLE, then restore it and check if it's working.
		greyscaleUnc.getHeader.imageType = TGA.Header.ImageType.RLEGrayscale;
		VFile virtualFile;// = VFile(tempStream);
		//std.stdio.File virtualFile = std.stdio.File("test/tga/grey_8_rle_gen.tga", "wb");
		greyscaleUnc.save!(VFile, false, false, true)(virtualFile);
		std.stdio.writeln("Save to virtual file was successful");
		std.stdio.writeln(virtualFile.size);
		virtualFile.seek(0);
		greyscaleRLE = TGA.load!VFile(virtualFile);
		std.stdio.writeln("Load from virtual file was successful");
		compareImages(greyscaleUnc, greyscaleRLE);
	}
	{
		std.stdio.File greyscaleUncFile = std.stdio.File("test/tga/mapped_8.tga");
		std.stdio.writeln("Loading ", greyscaleUncFile.name);
		TGA greyscaleUnc = TGA.load(greyscaleUncFile);
		std.stdio.writeln("File `", greyscaleUncFile.name, "` successfully loaded");
		std.stdio.File greyscaleRLEFile = std.stdio.File("test/tga/mapped_8_rle.tga");
		std.stdio.writeln("Loading ", greyscaleRLEFile.name);
		TGA greyscaleRLE = TGA.load(greyscaleRLEFile);
		std.stdio.writeln("File `", greyscaleRLEFile.name, "` successfully loaded");
		compareImages(greyscaleUnc, greyscaleRLE);
		//store the uncompressed one as a VFile in the memory using RLE, then restore it and check if it's working.
		greyscaleUnc.getHeader.imageType = TGA.Header.ImageType.RLEMapped;
		VFile virtualFile;// = VFile(tempStream);
		//std.stdio.File virtualFile = std.stdio.File("test/tga/grey_8_rle_gen.tga", "wb");
		greyscaleUnc.save!(VFile, false, false, true)(virtualFile);
		std.stdio.writeln("Save to virtual file was successful");
		std.stdio.writeln(virtualFile.size);
		virtualFile.seek(0);
		greyscaleRLE = TGA.load!VFile(virtualFile);
		std.stdio.writeln("Load from virtual file was successful");
		compareImages(greyscaleUnc, greyscaleRLE);
		//std.stdio.writeln(greyscaleUnc.palette);
		/+foreach (c ; greyscaleUnc.palette) {
			std.stdio.writeln();
		}+/
	}
	{
		std.stdio.File greyscaleUncFile = std.stdio.File("test/tga/concreteGUIE3.tga");
		std.stdio.writeln("Loading ", greyscaleUncFile.name);
		TGA greyscaleUnc = TGA.load(greyscaleUncFile);
		std.stdio.writeln("File `", greyscaleUncFile.name, "` successfully loaded");
		std.stdio.File greyscaleRLEFile = std.stdio.File("test/tga/concreteGUIE3_rle.tga");
		std.stdio.writeln("Loading ", greyscaleRLEFile.name);
		TGA greyscaleRLE = TGA.load(greyscaleRLEFile);
		std.stdio.writeln("File `", greyscaleRLEFile.name, "` successfully loaded");
		compareImages(greyscaleUnc, greyscaleRLE);
		//store the uncompressed one as a VFile in the memory using RLE, then restore it and check if it's working.
		greyscaleUnc.getHeader.imageType = TGA.Header.ImageType.RLEMapped;
		VFile virtualFile;// = VFile(tempStream);
		//std.stdio.File virtualFile = std.stdio.File("test/tga/grey_8_rle_gen.tga", "wb");
		greyscaleUnc.save!(VFile, false, false, true)(virtualFile);
		std.stdio.writeln("Save to virtual file was successful");
		std.stdio.writeln(virtualFile.size);
		virtualFile.seek(0);
		greyscaleRLE = TGA.load!VFile(virtualFile);
		std.stdio.writeln("Load from virtual file was successful");
		compareImages(greyscaleUnc, greyscaleRLE);
	}
	{
		std.stdio.File greyscaleUncFile = std.stdio.File("test/tga/truecolor_16.tga");
		std.stdio.writeln("Loading ", greyscaleUncFile.name);
		TGA greyscaleUnc = TGA.load(greyscaleUncFile);
		std.stdio.writeln("File `", greyscaleUncFile.name, "` successfully loaded");
		std.stdio.File greyscaleRLEFile = std.stdio.File("test/tga/truecolor_16_rle.tga");
		std.stdio.writeln("Loading ", greyscaleRLEFile.name);
		TGA greyscaleRLE = TGA.load(greyscaleRLEFile);
		std.stdio.writeln("File `", greyscaleRLEFile.name, "` successfully loaded");
		compareImages(greyscaleUnc, greyscaleRLE);
		//store the uncompressed one as a VFile in the memory using RLE, then restore it and check if it's working.
		greyscaleUnc.getHeader.imageType = TGA.Header.ImageType.RLETrueColor;
		VFile virtualFile;// = VFile(tempStream);
		//std.stdio.File virtualFile = std.stdio.File("test/tga/grey_8_rle_gen.tga", "wb");
		greyscaleUnc.save!(VFile, false, false, true)(virtualFile);
		std.stdio.writeln("Save to virtual file was successful");
		std.stdio.writeln(virtualFile.size);
		virtualFile.seek(0);
		greyscaleRLE = TGA.load!VFile(virtualFile);
		std.stdio.writeln("Load from virtual file was successful");
		compareImages(greyscaleUnc, greyscaleRLE);
	}
	{
		std.stdio.File greyscaleUncFile = std.stdio.File("test/tga/truecolor_24.tga");
		std.stdio.writeln("Loading ", greyscaleUncFile.name);
		TGA greyscaleUnc = TGA.load(greyscaleUncFile);
		std.stdio.writeln("File `", greyscaleUncFile.name, "` successfully loaded");
		std.stdio.File greyscaleRLEFile = std.stdio.File("test/tga/truecolor_24_rle.tga");
		std.stdio.writeln("Loading ", greyscaleRLEFile.name);
		TGA greyscaleRLE = TGA.load(greyscaleRLEFile);
		std.stdio.writeln("File `", greyscaleRLEFile.name, "` successfully loaded");
		compareImages(greyscaleUnc, greyscaleRLE);
		//store the uncompressed one as a VFile in the memory using RLE, then restore it and check if it's working.
		greyscaleUnc.getHeader.imageType = TGA.Header.ImageType.RLETrueColor;
		VFile virtualFile;// = VFile(tempStream);
		//std.stdio.File virtualFile = std.stdio.File("test/tga/grey_8_rle_gen.tga", "wb");
		greyscaleUnc.save!(VFile, false, false, true)(virtualFile);
		std.stdio.writeln("Save to virtual file was successful");
		std.stdio.writeln(virtualFile.size);
		virtualFile.seek(0);
		greyscaleRLE = TGA.load!VFile(virtualFile);
		std.stdio.writeln("Load from virtual file was successful");
		compareImages(greyscaleUnc, greyscaleRLE);
	}
	{
		std.stdio.File greyscaleUncFile = std.stdio.File("test/tga/truecolor_32.tga");
		std.stdio.writeln("Loading ", greyscaleUncFile.name);
		TGA greyscaleUnc = TGA.load(greyscaleUncFile);
		std.stdio.writeln("File `", greyscaleUncFile.name, "` successfully loaded");
		std.stdio.File greyscaleRLEFile = std.stdio.File("test/tga/truecolor_32_rle.tga");
		std.stdio.writeln("Loading ", greyscaleRLEFile.name);
		TGA greyscaleRLE = TGA.load(greyscaleRLEFile);
		std.stdio.writeln("File `", greyscaleRLEFile.name, "` successfully loaded");
		compareImages(greyscaleUnc, greyscaleRLE);
		//store the uncompressed one as a VFile in the memory using RLE, then restore it and check if it's working.
		greyscaleUnc.getHeader.imageType = TGA.Header.ImageType.RLETrueColor;
		VFile virtualFile;// = VFile(tempStream);
		//std.stdio.File virtualFile = std.stdio.File("test/tga/grey_8_rle_gen.tga", "wb");
		greyscaleUnc.save!(VFile, false, false, true)(virtualFile);
		std.stdio.writeln("Save to virtual file was successful");
		std.stdio.writeln(virtualFile.size);
		virtualFile.seek(0);
		greyscaleRLE = TGA.load!VFile(virtualFile);
		std.stdio.writeln("Load from virtual file was successful");
		compareImages(greyscaleUnc, greyscaleRLE);
	}
}