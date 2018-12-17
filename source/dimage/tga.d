module dimage.tga;

import std.bitmanip;
static import std.stdio;

public import dimage.base;

import core.stdc.string;

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
	protected TGAHeader		header;
	protected TGAFooter		footer;
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
	public this(TGAHeader header, ubyte[] imageData, ubyte[] paletteData = null, char[] imageID = null){
		this.header = header;
		this.imageData = imageData;
		this.paletteData = paletteData;
		this.imageID = imageID;
	}
	/**
	 * Creates a TGA object with a footer.
	 */
	public this(TGAHeader header, TGAFooter footer, ubyte[] imageData, ubyte[] paletteData = null, char[] imageID = null){
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
	public static TGA load(FILE = std.stdio.File, bool loadDevArea = false, bool loadExtArea = false)(FILE file){
		import std.stdio;
		ubyte[] loadRLEImageData(const ref TGAHeader header){
			size_t target = header.width * header.height;
			const size_t bytedepth = (header.pixelDepth / 8);
			target >>= header.pixelDepth < 8 ? 1 : 0;
			target >>= header.pixelDepth < 4 ? 1 : 0;
			target >>= header.pixelDepth < 2 ? 1 : 0;
			ubyte[] result, dataBuffer;
			result.reserve(header.pixelDepth >= 8 ? target * bytedepth : target);
			switch(header.pixelDepth){
				case 16:
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
					while(target){
						file.rawRead(dataBuffer);
						if(dataBuffer[0] & 0b1000_0000){//RLE block
							dataBuffer[0] &= 0b0111_1111;
							dataBuffer[0]++;
							ubyte[] rleBlock;
							rleBlock.length = dataBuffer[0];
							memset(rleBlock.ptr, dataBuffer[1], dataBuffer[0]);
							result ~= rleBlock;
						}else{//literal block
							dataBuffer[0] &= 0b0111_1111;
							ubyte[] literalBlock;
							literalBlock.length = dataBuffer[0];
							file.rawRead(literalBlock);
							result ~= dataBuffer[1] ~ literalBlock;
							target--;
						}
						target -= dataBuffer[0];
					}
					assert(result.length == (header.width * header.height / (header.pixelDepth / 8)));
					return result;
			}
			while(target){
				file.rawRead(dataBuffer);
				if(dataBuffer[0] & 0b1000_0000){//RLE block
					dataBuffer[0] &= 0b0111_1111;
					dataBuffer[0]++;
					ubyte[] rleBlock;
					rleBlock.reserve(dataBuffer[0] * bytedepth);
					while(dataBuffer[0]){
						rleBlock ~= dataBuffer[1..$];
						dataBuffer[0]--;
						target--;
					}
					result ~= rleBlock;
				}else{//literal block
					dataBuffer[0] &= 0b0111_1111;
					ubyte[] literalBlock;
					literalBlock.length = dataBuffer[0] * bytedepth;
					file.rawRead(literalBlock);
					result ~= dataBuffer[1] ~ literalBlock;
					target--;
				}
			}
			assert(result.length == (header.width * header.height / (header.pixelDepth / 8)));
			return result;
		}
		TGAHeader headerLoad;
		ubyte[TGAHeader.sizeof] headerBuffer;
		file.rawRead(headerBuffer);
		headerLoad = *(cast(TGAHeader*)(cast(void*)headerBuffer.ptr));
		char[] imageIDLoad;
		imageIDLoad.length = headerLoad.idLength;
		if(imageIDLoad.length) file.rawRead(imageIDLoad);
		version(unittest) std.stdio.writeln(imageIDLoad);
		ubyte[] palette;
		palette.length = headerLoad.colorMapLength * (headerLoad.colorMapDepth / 8);
		if(palette.length) file.rawRead(palette);
		ubyte[] image;
		if(headerLoad.imageType >= TGAHeader.ImageType.RLEMapped && headerLoad.imageType <= TGAHeader.ImageType.RLEGrayscale){
			image = loadRLEImageData(headerLoad);
		}else{
			image.length = (headerLoad.width * headerLoad.height * headerLoad.pixelDepth) / 8;
			version(unittest) std.stdio.writeln(headerLoad.toString);
			if(image.length) file.rawRead(image);
		}
		static if(loadExtArea || loadDevArea){
			TGAFooter footerLoad;
			file.seek(TGAFooter.sizeof * -1, SEEK_END);
			footerLoad = file.rawRead([footerLoad]);
			TGA result = new TGA(headerLoad, footerLoad, image, palette, imageID);
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
				case 2:
					result.mod = 3;
					result.shift = 2;
				case 4:
					result.mod = 1;
					result.shift = 1;
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
			bool ignoreScanlineBounds = false)(FILE file){
		import std.stdio;
		void compressRLE(){
			static if(!ignoreScanlineBounds){
				const uint maxScanlineLength = header.width;
				scanlineTable.length = 0;
				scanlineTable.reserve(height);
			}
			switch(header.pixelDepth){
				case 16:
					break;
				case 24:
					break;
				case 32:
					break;
				default:
					ubyte* src = imageData.ptr;
					const ubyte* dest = src + imageData.length;
					ubyte[] writeBuff;
					writeBuff.length = 129;
					static if(!ignoreScanlineBounds)
						uint currScanlineLength;
					while(src < dest){
						ubyte* currBlockBegin = src, currBlockEnd = src;
						if(currBlockBegin[0] == currBlockBegin[1]){	//RLE block
							ubyte blockLength = 1;
							while(currBlockEnd[0] == currBlockEnd[1]){
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
								if(blockLength == 128 || src + 1 == dest)
									break;
							}
							blockLength--;
							blockLength |= 0b1000_0000;
							writeBuff[0] = blockLength;
							writeBuff[1] = currBlockBegin[0];
							file.rawWrite(writeBuff[0..2]);
						}else{		//literal block
							ubyte blockLength = 1;
							writeBuff[1] = currBlockEnd[0];
							while(currBlockEnd[0] != currBlockEnd[1] && currBlockEnd[1] != currBlockEnd[2]){	//also check if next byte pair isn't RLE block
								writeBuff[1 + blockLength] = currBlockEnd[1];
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
								if(blockLength == 128 || src + 2 == dest)
									break;
							}
							//writeBuff[1] = currBlockEnd[0];
							blockLength--;
							writeBuff[0] = blockLength;
							file.rawWrite(writeBuff[0..blockLength + 3]);
						}
					}
					break;
			}
		}
		//write most of the data into the file
		file.rawWrite([header]);
		file.rawWrite(imageID);
		file.rawWrite(paletteData);
		file.rawWrite(imageData);
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
	override ushort width() @nogc @safe @property const{
		return header.width;
	}
	override ushort height() @nogc @safe @property const{
		return header.height;
	}
	override bool isIndexed() @nogc @safe @property const{
		return header.colorMapType != TGAHeader.ColorMapType.NoColorMapPresent;
	}
	override ubyte getBitdepth() @nogc @safe @property const{
		return header.pixelDepth;
	}
	override ubyte getPaletteBitdepth() @nogc @safe @property const{
		return header.colorMapDepth;
	}
	override PixelFormat getPixelFormat() @nogc @safe @property const{
		if(header.pixelDepth == 16 && header.colorMapType == TGAHeader.ColorMapType.NoColorMapPresent){
			return PixelFormat.RGBA5551;
		}else{
			return PixelFormat.Undefined;
		}
	}
	/**
	 * Returns the pixel order for bitdepths less than 8. Almost excusively used for indexed bitmaps.
	 * Returns null if ordering not needed.
	 */
	override public ubyte[] getPixelOrder() @safe @property const{
		switch(header.pixelDepth){
			case 1: return pixelOrder1BitBE.dup;
			case 2: return pixelOrder2BitBE.dup;
			case 4: return pixelOrder4BitBE.dup;
			default: return null;
		}
	}
	/**
	 * Returns which pixel how much needs to be shifted right after a byteread.
	 */
	override public ubyte[] getPixelOrderBitshift() @safe @property const{
		switch(header.pixelDepth){
			case 1: return pixelShift1BitBE.dup;
			case 2: return pixelShift2BitBE.dup;
			case 4: return pixelShift4BitBE.dup;
			default: return null;
		}
	}
	public string getID(){
		return cast(string)imageID;
	}
	public string getAuthor(){
		if(extensionArea.length)
			return extensionArea[0].authorName;
		return null;
	}
	public string getComment(){
		if(extensionArea.length)
			return extensionArea[0].authorComments;
		return null;
	}
	public string getJobName(){
		if(extensionArea.length)
			return extensionArea[0].jobName;
		return null;
	}
	public string getSoftwareInfo(){
		if(extensionArea.length)
			return extensionArea[0].softwareID;
		return null;
	}
	public string getSoftwareVersion(){
		import std.conv : to;
		if(extensionArea.length)
			return to!string(extensionArea[0].softwareVersNum / 100) ~ "." ~ to!string((extensionArea[0].softwareVersNum % 100) 
					/ 10) ~ "." ~ to!string(extensionArea[0].softwareVersNum % 10) ~ extensionArea[0].softwareVersChar;
		return null;
	}
	public void setID(string val){
		if(val.length > 255)
			throw new Exception("ID is too long");
		imageID = val.dup;
		header.idLength = cast(ubyte)val.length;
	}
	public void setAuthor(string val){
		if(val.length > 41)
			throw new Exception("Author name is too long");
		memset(extensionArea[0].authorName.ptr, 0, extensionArea[0].authorName.length);
		memcpy(extensionArea[0].authorName.ptr, val.ptr, val.length);
	}
	public void setComment(string val){
		if(val.length > 324)
			throw new Exception("Comment is too long");
		memset(extensionArea[0].authorComments.ptr, 0, extensionArea[0].authorComments.length);
		memcpy(extensionArea[0].authorComments.ptr, val.ptr, val.length);
	}
	public void setJobName(string val){
		if(val.length > 41)
			throw new Exception("Jobname is too long");
		memset(extensionArea[0].jobName.ptr, 0, extensionArea[0].jobName.length);
		memcpy(extensionArea[0].jobName.ptr, val.ptr, val.length);
	}
	public void setSoftwareInfo(string val){
		if(val.length > 41)
			throw new Exception("SoftwareID is too long");
		memset(extensionArea[0].softwareID.ptr, 0, extensionArea[0].softwareID.length);
		memcpy(extensionArea[0].softwareID.ptr, val.ptr, val.length);
	}
	public void setSoftwareVersion(string val){

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
	public ref TGAHeader getHeader() @nogc @safe nothrow{
		return header;
	}
}
/**
 * Implements Truevision Graphics bitmap header.
 */
public struct TGAHeader {
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
		RLEMapped				=	9,
		RLETrueColor			=	10,
		RLEGrayscale			=	11,
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
		ubyte, "reserved", 2, 
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
struct TGAFooter {
align(1) :
	uint			extensionAreaOffset;				/// offset of the extensionArea, zero if doesn't exist
	uint			developerAreaOffset;				/// offset of the developerArea, zero if doesn't exist
	char[16]		signature = "TRUEVISION-XFILE";		/// if equals with "TRUEVISION-XFILE", it's the new format
	char			reserved = '.';						/// should be always a dot
	ubyte			terminator;							/// terminates the file, always null
	///Returns true if it's a valid TGA footer
	@property bool isValid(){
		return signature == "TRUEVISION-XFILE";
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
	assert(TGAHeader.sizeof == 18);
	ubyte[] tempStream;
	//test 8 bit RLE load for 8 bit greyscale and indexed
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
	greyscaleUnc.getHeader.imageType = TGAHeader.ImageType.RLEGrayscale;
	//VFile virtualFile = VFile(tempStream);
	std.stdio.File virtualFile = std.stdio.File("test/tga/grey_8_rle_gen.tga", "wb");
	greyscaleUnc.save(virtualFile);
	std.stdio.writeln("Save to virtual file was successful");
	greyscaleRLE = TGA.load(virtualFile);
	std.stdio.writeln("Load from virtual file was successful");
	compareImages(greyscaleUnc, greyscaleRLE);
}