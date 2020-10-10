module dimage.types;

import std.bitmanip : bitfields;
//import std.conv : roundTo;

///Sets the byteorder of
enum Endianness {
	Little,
	Big
}

alias ARGB8888 = ARGB8888Templ!(Endianness.Little);
alias ARGB8888BE = ARGB8888Templ!(Endianness.Big);

/**
 * 4 * 32 bit floating point pixel representation.
 * Used for RGBA conversion and other things.
 */
struct RGBA_f32 {
	float	fR;
	float	fG;
	float	fB;
	float	fA;
	///Standard CTOR
	this(float fR, float fG, float fB, float fA) @safe @nogc pure nothrow {
		this.fR = fR;
		this.fG = fG;
		this.fB = fB;
		this.fA = fA;
	}
	///Conversion CTOR
	this(ColorType)(ColorType orig) @safe @nogc pure nothrow {
		this.fR = orig.fR;
		this.fG = orig.fG;
		this.fB = orig.fB;
		this.fA = orig.fA;
	}
	///Conversion CTOR from monochrome
	this(float fY, float fA = 1.0) @safe @nogc pure nothrow {
		this.fR = fY;
		this.fG = fY;
		this.fB = fY;
		this.fA = fA;
	}
}
/**
 * Standard 32 bit pixel representation.
 */
struct ARGB8888Templ (Endianness byteOrder = Endianness.Little) {
	union{
		ubyte[4] bytes;     /// BGRA
		uint base;          /// Direct address
	}
	static if (byteOrder == Endianness.Big) {
		///Red
		@safe @nogc @property nothrow pure ref auto r() inout { return bytes[1]; }
		///Green
		@safe @nogc @property nothrow pure ref auto g() inout { return bytes[2]; }
		///Blue
		@safe @nogc @property nothrow pure ref auto b() inout { return bytes[3]; }
		///Alpha
		@safe @nogc @property nothrow pure ref auto a() inout { return bytes[0]; }
	} else {
		///Red
		@safe @nogc @property nothrow pure ref auto r() inout { return bytes[2]; }
		///Green
		@safe @nogc @property nothrow pure ref auto g() inout { return bytes[1]; }
		///Blue
		@safe @nogc @property nothrow pure ref auto b() inout { return bytes[0]; }
		///Alpha
		@safe @nogc @property nothrow pure ref auto a() inout { return bytes[3]; }
	}
	static immutable double fRStepping = 1.0 / 255;	///Floating-point red stepping
	static immutable double fGStepping = 1.0 / 255;	///Floating-point green stepping
	static immutable double fBStepping = 1.0 / 255;	///Floating-point blue stepping
	static immutable double fAStepping = 1.0 / 255;	///Floating-point alpha stepping
	///Returns the red channel as a normalized floating-point value
	@property float fR() @safe @nogc pure nothrow const {
		return r * fRStepping;
	}
	///Returns the green channel as a normalized floating-point value
	@property float fG() @safe @nogc pure nothrow const {
		return g * fGStepping;
	}
	///Returns the blue channel as a normalized floating-point value
	@property float fB() @safe @nogc pure nothrow const {
		return b * fBStepping;
	}
	///Returns the alpha channel as a normalized floating-point value
	@property float fA() @safe @nogc pure nothrow const {
		return a * fAStepping;
	}
	///Sets the red value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fR(float val) @safe @nogc pure nothrow {
		//if(val >= 1) r = 255;
		//else 
		r = cast(ubyte)(val / fRStepping);
		return fR;
	}
	///Sets the green value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fG(float val) @safe @nogc pure nothrow {
		g = cast(ubyte)(val / fGStepping);
		return fG;
	}
	///Sets the blue value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fB(float val) @safe @nogc pure nothrow {
		b = cast(ubyte)(val / fBStepping);
		return fB;
	}
	///Sets the alpha value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fA(float val) @safe @nogc pure nothrow {
		a = cast(ubyte)(val / fAStepping);
		return fA;
	}
	///Creates a standard pixel representation out from a 4 element array
	this(ubyte[4] bytes) @safe @nogc pure nothrow {
		this.bytes = bytes;
	}
	///Creates a standard pixel representation out from 4 separate values
	this(ubyte r, ubyte g, ubyte b, ubyte a) @safe @nogc pure nothrow {
		this.b = b;
		this.g = g;
		this.r = r;
		this.a = a;
	}
	///Standard CTOR
	this(float fR, float fG, float fB, float fA) @safe @nogc pure nothrow {
		this.fR = fR;
		this.fG = fG;
		this.fB = fB;
		this.fA = fA;
	}
	///Template for pixel conversion
	this(ColorType)(ColorType orig) @safe @nogc pure nothrow {
		this.fB = orig.fB;
		this.fG = orig.fG;
		this.fR = orig.fR;
		this.fA = orig.fA;
	}
	///Conversion CTOR from monochrome
	this(float fY, float fA = 1.0) @safe @nogc pure nothrow {
		this.fR = fY;
		this.fG = fY;
		this.fB = fY;
		this.fA = fA;
	}
	///Conversion from 8bit monochrome
	this(ubyte p) @safe @nogc pure nothrow {
		this.b = p;
		this.g = p;
		this.r = p;
		this.a = 0xFF;
	}
	///String representation of this struct
	string toString() const {
		import std.conv : to;
		return to!string(r) ~ "," ~ to!string(g) ~ "," ~ to!string(b) ~ "," ~ to!string(a);
	}
	///Returns true if type has alpha channel support
	static bool hasAlphaChannelSupport() {
		return true;
	}

}

alias RGBA8888BE = RGBA8888Templ!(Endianness.Big);
alias RGBA8888 = RGBA8888Templ!(Endianness.Little);
/**
 * Standard 32 bit pixel representation.
 */
struct RGBA8888Templ (Endianness byteOrder = Endianness.Little) {
	union{
		ubyte[4] bytes;     /// RGBA
		uint base;          /// Direct address
	}
	static if (byteOrder == Endianness.Big) {
		///Red
		@safe @nogc @property pure ref auto r() inout { return bytes[0]; }
		///Green
		@safe @nogc @property pure ref auto g() inout { return bytes[1]; }
		///Blue
		@safe @nogc @property pure ref auto b() inout { return bytes[2]; }
		///Alpha
		@safe @nogc @property pure ref auto a() inout { return bytes[3]; }
	} else {
		///Red
		@safe @nogc @property pure ref auto r() inout { return bytes[3]; }
		///Green
		@safe @nogc @property pure ref auto g() inout { return bytes[2]; }
		///Blue
		@safe @nogc @property pure ref auto b() inout { return bytes[1]; }
		///Alpha
		@safe @nogc @property pure ref auto a() inout { return bytes[0]; }
	}
	static immutable double fRStepping = 1.0 / 255;	///Floating-point red stepping
	static immutable double fGStepping = 1.0 / 255;	///Floating-point green stepping
	static immutable double fBStepping = 1.0 / 255;	///Floating-point blue stepping
	static immutable double fAStepping = 1.0 / 255;	///Floating-point alpha stepping
	///Returns the red channel as a normalized floating-point value
	@property float fR() @safe @nogc pure nothrow const {
		return r * fRStepping;
	}
	///Returns the green channel as a normalized floating-point value
	@property float fG() @safe @nogc pure nothrow const {
		return g * fGStepping;
	}
	///Returns the blue channel as a normalized floating-point value
	@property float fB() @safe @nogc pure nothrow const {
		return b * fBStepping;
	}
	///Returns the alpha channel as a normalized floating-point value
	@property float fA() @safe @nogc pure nothrow const {
		return a * fAStepping;
	}
	///Sets the red value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fR(float val) @safe @nogc pure nothrow {
		r = cast(ubyte)(val / fRStepping);
		return fR;
	}
	///Sets the green value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fG(float val) @safe @nogc pure nothrow {
		g = cast(ubyte)(val / fGStepping);
		return fG;
	}
	///Sets the blue value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fB(float val) @safe @nogc pure nothrow {
		b = cast(ubyte)(val / fBStepping);
		return fB;
	}
	///Sets the alpha value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fA(float val) @safe @nogc pure nothrow {
		a = cast(ubyte)(val / fAStepping);
		return fA;
	}
	///Creates a standard pixel representation out from a 4 element array
	this(ubyte[4] bytes) @safe @nogc pure nothrow {
		this.bytes = bytes;
	}
	///Creates a standard pixel representation out from 4 separate values
	this(ubyte r, ubyte g, ubyte b, ubyte a) @safe @nogc pure nothrow {
		bytes[0] = r;
		bytes[1] = g;
		bytes[2] = b;
		bytes[3] = a;
	}
	///Standard CTOR
	this(float fR, float fG, float fB, float fA) @safe @nogc pure nothrow {
		this.fR = fR;
		this.fG = fG;
		this.fB = fB;
		this.fA = fA;
	}
	///Conversion CTOR from monochrome
	this(float fY, float fA = 1.0) @safe @nogc pure nothrow {
		this.fR = fY;
		this.fG = fY;
		this.fB = fY;
		this.fA = fA;
	}
	///Template for pixel conversion
	this(ColorType)(ColorType orig) @safe @nogc pure nothrow {
		this.fB = orig.fB;
		this.fG = orig.fG;
		this.fR = orig.fR;
		this.fA = orig.fA;
	}
	///Conversion from 8bit monochrome
	this(ubyte p) @safe @nogc pure nothrow {
		this.b = p;
		this.g = p;
		this.r = p;
		this.a = 0xFF;
	}
	///Returns true if type has alpha channel support
	static bool hasAlphaChannelSupport() {
		return true;
	}
}
alias YA88 = YA88Templ!(Endianness.Little);
alias YA88BE = YA88Templ!(Endianness.Big);
/**
 * For monochrome images with a single channel
 */
struct YA88Templ (Endianness byteOrder = Endianness.Little) {
	union{
		ushort		base;		/// direct access
		ubyte[2]	channels;	/// individual access
	}
	static immutable double fRStepping = 1.0 / 255;	///Floating-point red stepping
	static immutable double fGStepping = 1.0 / 255;	///Floating-point green stepping
	static immutable double fBStepping = 1.0 / 255;	///Floating-point blue stepping
	static immutable double fAStepping = 1.0 / 255;	///Floating-point alpha stepping
	///Returns the red channel as a normalized floating-point value
	@property float fR() @safe @nogc pure nothrow const {
		return y * fRStepping;
	}
	///Returns the green channel as a normalized floating-point value
	@property float fG() @safe @nogc pure nothrow const {
		return y * fGStepping;
	}
	///Returns the blue channel as a normalized floating-point value
	@property float fB() @safe @nogc pure nothrow const {
		return y * fBStepping;
	}
	///Returns the alpha channel as a normalized floating-point value
	@property float fA() @safe @nogc pure nothrow const {
		return a * fAStepping;
	}
	///Sets the red value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fR(float val) @safe @nogc pure nothrow {
		y = cast(ubyte)(val / fRStepping);
		return fR;
	}
	///Sets the green value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fG(float val) @safe @nogc pure nothrow {
		y = cast(ubyte)(val / fGStepping);
		return fG;
	}
	///Sets the blue value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fB(float val) @safe @nogc pure nothrow {
		y = cast(ubyte)(val / fBStepping);
		return fB;
	}
	///Sets the alpha value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fA(float val) @safe @nogc pure nothrow {
		a = cast(ubyte)(val / fAStepping);
		return fA;
	}
	///Standard CTOR
	this(ubyte y, ubyte a) @safe @nogc pure nothrow {
		this.y = y;
		this.a = a;
	}
	///Standard CTOR
	this(float fR, float fG, float fB, float fA) @safe @nogc pure nothrow {
		this.fB = 0.2125 * fR + 0.7154 * fG + 0.0721 * fB;
		this.fA = fA;
	}
	///Template for pixel conversion
	///Uses mathematical average to calculate the new values
	this(ColorType)(ColorType orig) @safe @nogc pure nothrow {
		this.fB = 0.2125 * orig.fR + 0.7154 * orig.fG + 0.0721 * orig.fB;
		this.fA = orig.fA;
	}
	///Conversion CTOR from monochrome
	this(float fY, float fA = 1.0) @safe @nogc pure nothrow {
		this.fR = fY;
		this.fA = fA;
	}
	///Conversion from 8bit monochrome
	this(ubyte p) @safe @nogc pure nothrow {
		this.y = p;
		this.a = 0xFF;
	}
	/// luminance
	nothrow @safe @nogc @property pure ref auto y() inout { 
		static if(byteOrder == Endianness.Big) {
			return channels[1]; 
		} else {
			return channels[0]; 
		}
	}
	/// alpha
	nothrow @safe @nogc @property pure ref auto a() inout { 
		static if(byteOrder == Endianness.Big) {
			return channels[0]; 
		} else {
			return channels[1]; 
		}
	}
	/// pseudo-red (output only)
	nothrow @safe @nogc @property pure ubyte r() const { return y; }
	/// pseudo-green (output only)
	nothrow @safe @nogc @property pure ubyte g() const { return y; }
	/// pseudo-blue (output only)
	nothrow @safe @nogc @property pure ubyte b() const { return y; }
	///Returns true if type has alpha channel support
	static bool hasAlphaChannelSupport() {
		return true;
	}
}
alias YA16_16 = YA16_16Templ!(Endianness.Little);
alias YA16_16BE = YA16_16Templ!(Endianness.Big);
/**
 * For monochrome images with a single channel
 */
struct YA16_16Templ (Endianness byteOrder = Endianness.Little) {
	union{
		uint		base;		/// direct access
		ushort[2]	channels;	/// individual access
	}
	static immutable double fRStepping = 1.0 / 65_535;	///Floating-point red stepping
	static immutable double fGStepping = 1.0 / 65_535;	///Floating-point green stepping
	static immutable double fBStepping = 1.0 / 65_535;	///Floating-point blue stepping
	static immutable double fAStepping = 1.0 / 65_535;	///Floating-point alpha stepping
	///Returns the red channel as a normalized floating-point value
	@property float fR() @safe @nogc pure nothrow const {
		return y * fRStepping;
	}
	///Returns the green channel as a normalized floating-point value
	@property float fG() @safe @nogc pure nothrow const {
		return y * fGStepping;
	}
	///Returns the blue channel as a normalized floating-point value
	@property float fB() @safe @nogc pure nothrow const {
		return y * fBStepping;
	}
	///Returns the alpha channel as a normalized floating-point value
	@property float fA() @safe @nogc pure nothrow const {
		return a * fAStepping;
	}
	///Sets the red value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fR(float val) @safe @nogc pure nothrow {
		y = cast(ubyte)(val / fRStepping);
		return fR;
	}
	///Sets the green value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fG(float val) @safe @nogc pure nothrow {
		y = cast(ubyte)(val / fGStepping);
		return fG;
	}
	///Sets the blue value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fB(float val) @safe @nogc pure nothrow {
		y = cast(ubyte)(val / fBStepping);
		return fB;
	}
	///Sets the alpha value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fA(float val) @safe @nogc pure nothrow {
		a = cast(ubyte)(val / fAStepping);
		return fA;
	}
	///Standard CTOR
	this(ushort y, ushort a) @safe @nogc pure nothrow {
		this.y = y;
		this.a = a;
	}
	///Standard CTOR
	this(float fR, float fG, float fB, float fA) @safe @nogc pure nothrow {
		this.fB = 0.2125 * fR + 0.7154 * fG + 0.0721 * fB;
		this.fA = fA;
	}
	///Template for pixel conversion
	///Uses mathematical average to calculate the new values
	this(ColorType)(ColorType orig) @safe @nogc pure nothrow {
		this.fB = 0.2125 * orig.fR + 0.7154 * orig.fG + 0.0721 * orig.fB;
		this.fA = orig.fA;
	}
	///Conversion CTOR from monochrome
	this(float fY, float fA = 1.0) @safe @nogc pure nothrow {
		this.fR = fY;
		this.fA = fA;
	}
	///Conversion from 8bit monochrome
	this(ubyte p) @safe @nogc pure nothrow {
		this.y = p;
		this.a = 0xFF;
	}
	/// luminance
	nothrow @safe @nogc @property pure ref auto y() inout { 
		static if(byteOrder == Endianness.Big) {
			return channels[1]; 
		} else {
			return channels[0]; 
		}
	}
	/// alpha
	nothrow @safe @nogc @property pure ref auto a() inout { 
		static if(byteOrder == Endianness.Big) {
			return channels[0]; 
		} else {
			return channels[1]; 
		}
	}
	/// pseudo-red (output only)
	nothrow @safe @nogc @property pure ushort r() const { return y; }
	/// pseudo-green (output only)
	nothrow @safe @nogc @property pure ushort g() const { return y; }
	/// pseudo-blue (output only)
	nothrow @safe @nogc @property pure ushort b() const { return y; }
	///Returns true if type has alpha channel support
	static bool hasAlphaChannelSupport() {
		return true;
	}
}
/**
 * 16 Bit colorspace with a single bit alpha. This is should be used with RGBX5551 with channel `a` ignored
 */
struct RGBA5551 {
	union{
		ushort base;			/// direct access
		mixin(bitfields!(
			ubyte, "_b", 5,
			ubyte, "_g", 5,
			ubyte, "_r", 5,
			bool, "_a", 1,
		));
	}
	static immutable double fRStepping = 1.0 / 31;	///Floating-point red stepping
	static immutable double fGStepping = 1.0 / 31;	///Floating-point green stepping
	static immutable double fBStepping = 1.0 / 31;	///Floating-point blue stepping
	static immutable double fAStepping = 1.0;		///Floating-point alpha stepping
	///Returns the red channel as a normalized floating-point value
	@property float fR() @safe @nogc pure nothrow const {
		return _r * fRStepping;
	}
	///Returns the green channel as a normalized floating-point value
	@property float fG() @safe @nogc pure nothrow const {
		return _g * fGStepping;
	}
	///Returns the blue channel as a normalized floating-point value
	@property float fB() @safe @nogc pure nothrow const {
		return _b * fBStepping;
	}
	///Returns the alpha channel as a normalized floating-point value
	@property float fA() @safe @nogc pure nothrow const {
		return _a ? 1.0 : 0.0;
	}
	///Sets the red value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fR(float val) @safe @nogc pure nothrow {
		_r = cast(ubyte)(val / fRStepping);
		return fR;
	}
	///Sets the green value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fG(float val) @safe @nogc pure nothrow {
		_g = cast(ubyte)(val / fGStepping);
		return fG;
	}
	///Sets the blue value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fB(float val) @safe @nogc pure nothrow {
		_b = cast(ubyte)(val / fBStepping);
		return fB;
	}
	///Sets the alpha value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fA(float val) @safe @nogc pure nothrow {
		_a = val == 0.0;
		return fA;
	}
	/// Standard CTOR with 8bit normalized inputs
	this(ubyte r, ubyte g, ubyte b, ubyte a) @safe @nogc pure nothrow {
		_r = r>>3;
		_g = g>>3;
		_b = b>>3;
		_a = a != 0;
	}
	///Standard CTOR
	this(float fR, float fG, float fB, float fA) @safe @nogc pure nothrow {
		this.fR = fR;
		this.fG = fG;
		this.fB = fB;
		this.fA = fA;
	}
	///Conversion CTOR from monochrome
	this(float fY, float fA = 1.0) @safe @nogc pure nothrow {
		this.fR = fY;
		this.fG = fY;
		this.fB = fY;
		this.fA = fA;
	}
	///Template for pixel conversion
	this(ColorType)(ColorType orig) @safe @nogc pure {
		this.fB = orig.fB;
		this.fG = orig.fG;
		this.fR = orig.fR;
		this.fA = orig.fA;
	}
	///Conversion from 8bit monochrome
	this(ubyte p) @safe @nogc pure nothrow {
		_b = p>>3;
		_g = p>>3;
		_r = p>>3;
		_a = true;
	}
	/// upconverted-red (output only)
	nothrow @safe @nogc @property pure ubyte r() const { return cast(ubyte)(_r << 3 | _r >>> 2); }
	/// upconverted-green (output only)
	nothrow @safe @nogc @property pure ubyte g() const { return cast(ubyte)(_g << 3 | _g >>> 2); }
	/// upconverted-blue (output only)
	nothrow @safe @nogc @property pure ubyte b() const { return cast(ubyte)(_b << 3 | _b >>> 2); }
	/// upconverted-alpha
	nothrow @safe @nogc @property pure ubyte a() const { return _a ? 0xFF : 0x00; }
	///Returns true if type has alpha channel support
	static bool hasAlphaChannelSupport() {
		return true;
	}
}
/**
 * 16 Bit RGB565 colorspace with no alpha.
 */
struct RGB565 {
	union{
		ushort base;			/// direct access
		mixin(bitfields!(
			ubyte, "_b", 5,
			ubyte, "_g", 6,
			ubyte, "_r", 5,
		));
	}
	static immutable double fRStepping = 1.0 / 31;	///Floating-point red stepping
	static immutable double fGStepping = 1.0 / 63;	///Floating-point green stepping
	static immutable double fBStepping = 1.0 / 31;	///Floating-point blue stepping
	static immutable double fAStepping = 1.0;		///Floating-point alpha stepping
	///Returns the red channel as a normalized floating-point value
	@property float fR() @safe @nogc pure nothrow const {
		return _r * fRStepping;
	}
	///Returns the green channel as a normalized floating-point value
	@property float fG() @safe @nogc pure nothrow const {
		return _g * fGStepping;
	}
	///Returns the blue channel as a normalized floating-point value
	@property float fB() @safe @nogc pure nothrow const {
		return _b * fBStepping;
	}
	///Returns the alpha channel as a normalized floating-point value
	@property float fA() @safe @nogc pure nothrow const {
		return 1.0;
	}
	///Sets the red value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fR(float val) @safe @nogc pure nothrow {
		_r = cast(ubyte)(val / fRStepping);
		return fR;
	}
	///Sets the green value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fG(float val) @safe @nogc pure nothrow {
		_g = cast(ubyte)(val / fGStepping);
		return fG;
	}
	///Sets the blue value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fB(float val) @safe @nogc pure nothrow {
		_b = cast(ubyte)(val / fBStepping);
		return fB;
	}
	///Sets the alpha value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fA(float val) @safe @nogc pure nothrow {
		return 1.0;
	}
	/// Standard CTOR with 8bit normalized inputs
	this(ubyte r, ubyte g, ubyte b) @safe @nogc pure nothrow {
		_r = r>>3;
		_g = g>>2;
		_b = b>>3;
	}
	///Standard CTOR
	this(float fR, float fG, float fB, float fA) @safe @nogc pure nothrow {
		this.fR = fR;
		this.fG = fG;
		this.fB = fB;
		this.fA = fA;
	}
	///Template for pixel conversion
	this(ColorType)(ColorType orig) @safe @nogc pure nothrow {
		this.fB = orig.fB;
		this.fG = orig.fG;
		this.fR = orig.fR;
		this.fA = orig.fA;
	}
	///Conversion CTOR from monochrome
	this(float fY, float fA = 1.0) @safe @nogc pure nothrow {
		this.fR = fY;
		this.fG = fY;
		this.fB = fY;
		this.fA = fA;
	}
	///Conversion from 8bit monochrome
	this(ubyte p) @safe @nogc pure nothrow {
		_b = p>>3;
		_g = p>>2;
		_r = p>>3;
	}
	/// upconverted-red (output only)
	nothrow @safe @nogc @property pure ubyte r() const { return cast(ubyte)(_r << 3 | _r >>> 2); }
	/// upconverted-green (output only)
	nothrow @safe @nogc @property pure ubyte g() const { return cast(ubyte)(_g << 2 | _g >>> 4); }
	/// upconverted-blue (output only)
	nothrow @safe @nogc @property pure ubyte b() const { return cast(ubyte)(_b << 3 | _b >>> 2); }
	//pseudo-alpha (output only)
	nothrow @safe @nogc @property pure ubyte a() const { return 0xFF; }
	///Returns true if type has alpha channel support
	static bool hasAlphaChannelSupport() {
		return false;
	}
}
alias RGB888 = RGB888Templ!(Endianness.Little);
alias RGB888BE = RGB888Templ!(Endianness.Big);
/**
 * 24 Bit colorspace
 */
align(1) struct RGB888Templ (Endianness byteOrder = Endianness.Little) {
	ubyte[3] bytes;				///individual access
	static if (byteOrder == Endianness.Big) {
		///red
		nothrow @safe @nogc @property pure ref auto r() inout { return bytes[0]; }
		///green
		nothrow @safe @nogc @property pure ref auto g() inout { return bytes[1]; }
		///blue
		nothrow @safe @nogc @property pure ref auto b() inout { return bytes[2]; }
	} else {
		///red
		nothrow @safe @nogc @property pure ref auto r() inout { return bytes[2]; }
		///green
		nothrow @safe @nogc @property pure ref auto g() inout { return bytes[1]; }
		///blue
		nothrow @safe @nogc @property pure ref auto b() inout { return bytes[0]; }
	}
	static immutable double fRStepping = 1.0 / 255;	///Floating-point red stepping
	static immutable double fGStepping = 1.0 / 255;	///Floating-point green stepping
	static immutable double fBStepping = 1.0 / 255;	///Floating-point blue stepping
	static immutable double fAStepping = 1.0;	///Floating-point alpha stepping
	///Returns the red channel as a normalized floating-point value
	@property float fR() @safe @nogc pure nothrow const {
		return r * fRStepping;
	}
	///Returns the green channel as a normalized floating-point value
	@property float fG() @safe @nogc pure nothrow const {
		return g * fGStepping;
	}
	///Returns the blue channel as a normalized floating-point value
	@property float fB() @safe @nogc pure nothrow const {
		return b * fBStepping;
	}
	///Returns the alpha channel as a normalized floating-point value
	@property float fA() @safe @nogc pure nothrow const {
		return 1.0;
	}
	///Sets the red value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fR(float val) @safe @nogc pure nothrow {
		r = cast(ubyte)(val / fRStepping);
		return fR;
	}
	///Sets the green value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fG(float val) @safe @nogc pure nothrow {
		g = cast(ubyte)(val / fGStepping);
		return fG;
	}
	///Sets the blue value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fB(float val) @safe @nogc pure nothrow {
		b = cast(ubyte)(val / fBStepping);
		return fB;
	}
	///Sets the alpha value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fA(float val) @safe @nogc pure nothrow {
		return 1.0;
	}
	///Standard CTOR
	this(ubyte r, ubyte g, ubyte b) pure nothrow @safe @nogc {
		this.r = r;
		this.g = g;
		this.b = b;
	}
	///Standard CTOR
	this(float fR, float fG, float fB, float fA) {
		this.fR = fR;
		this.fG = fG;
		this.fB = fB;
		this.fA = fA;
	}
	///Conversion CTOR from monochrome
	this(float fY, float fA = 1.0) {
		this.fR = fY;
		this.fG = fY;
		this.fB = fY;
		this.fA = fA;
	}
	///Template for pixel conversion
	this(ColorType)(ColorType orig) @safe @nogc pure {
		this.fB = orig.fB;
		this.fG = orig.fG;
		this.fR = orig.fR;
		this.fA = orig.fA;
	}
	///Conversion from 8bit monochrome
	this(ubyte p) @safe @nogc pure {
		this.b = p;
		this.g = p;
		this.r = p;
	}
	//pseudo-alpha (output only)
	nothrow @safe @nogc @property pure ubyte a() const { return 0xFF; }
	///direct access read
	nothrow @safe @nogc @property pure uint base(){ return 0xff_00_00_00 | r << 16 | g << 8 | b; }
	///Returns true if type has alpha channel support
	static bool hasAlphaChannelSupport() {
		return false;
	}
}
alias RGB16_16_16 = RGB16_16_16Templ!(Endianness.Little);
alias RGB16_16_16BE = RGB16_16_16Templ!(Endianness.Big);
/**
 * 48 bit RGB colorspace with 16 bit per channel.
 */
align(2) public struct RGB16_16_16Templ (Endianness byteOrder = Endianness.Little) {
	ushort[3] bytes;				///individual access
	static if (byteOrder == Endianness.Big) {
		///red
		nothrow @safe @nogc @property pure ref auto r() inout { return bytes[0]; }
		///green
		nothrow @safe @nogc @property pure ref auto g() inout { return bytes[1]; }
		///blue
		nothrow @safe @nogc @property pure ref auto b() inout { return bytes[2]; }
	} else {
		///red
		nothrow @safe @nogc @property pure ref auto r() inout { return bytes[2]; }
		///green
		nothrow @safe @nogc @property pure ref auto g() inout { return bytes[1]; }
		///blue
		nothrow @safe @nogc @property pure ref auto b() inout { return bytes[0]; }
	}
	static immutable double fRStepping = 1.0 / 65_535;///Floating-point red stepping
	static immutable double fGStepping = 1.0 / 65_535;///Floating-point green stepping
	static immutable double fBStepping = 1.0 / 65_535;///Floating-point blue stepping
	static immutable double fAStepping = 1.0;		///Floating-point alpha stepping
	///Returns the red channel as a normalized floating-point value
	@property float fR() @safe @nogc pure nothrow const {
		return r * fRStepping;
	}
	///Returns the green channel as a normalized floating-point value
	@property float fG() @safe @nogc pure nothrow const {
		return g * fGStepping;
	}
	///Returns the blue channel as a normalized floating-point value
	@property float fB() @safe @nogc pure nothrow const {
		return b * fBStepping;
	}
	///Returns the alpha channel as a normalized floating-point value
	@property float fA() @safe @nogc pure nothrow const {
		return 1.0;
	}
	///Sets the red value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fR(float val) @safe @nogc pure nothrow {
		r = cast(ushort)(val / fRStepping);
		return fR;
	}
	///Sets the green value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fG(float val) @safe @nogc pure nothrow {
		g = cast(ushort)(val / fGStepping);
		return fG;
	}
	///Sets the blue value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fB(float val) @safe @nogc pure nothrow {
		b = cast(ushort)(val / fBStepping);
		return fB;
	}
	///Sets the alpha value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fA(float val) @safe @nogc pure nothrow {
		return 1.0;
	}
	///Standard CTOR
	this(ushort r, ushort g, ushort b) pure nothrow @safe @nogc {
		this.r = r;
		this.g = g;
		this.b = b;
	}
	///Standard CTOR
	this(float fR, float fG, float fB, float fA) {
		this.fR = fR;
		this.fG = fG;
		this.fB = fB;
		this.fA = fA;
	}
	///Conversion CTOR from monochrome
	this(float fY, float fA = 1.0) {
		this.fR = fY;
		this.fG = fY;
		this.fB = fY;
		this.fA = fA;
	}
	///Template for pixel conversion
	this(ColorType)(ColorType orig) @safe @nogc pure {
		this.fB = orig.fB;
		this.fG = orig.fG;
		this.fR = orig.fR;
		this.fA = orig.fA;
	}
	///Returns true if type has alpha channel support
	static bool hasAlphaChannelSupport() {
		return false;
	}
}
alias RGBA16_16_16_16 = RGBA16_16_16_16Templ!(Endianness.Little);
alias RGBA16_16_16_16BE = RGBA16_16_16_16Templ!(Endianness.Big);
/**
 * 48 bit RGB colorspace with 16 bit per channel.
 */
align(2) public struct RGBA16_16_16_16Templ (Endianness byteOrder = Endianness.Little) {
	ushort[4] bytes;				///individual access
	static if (byteOrder == Endianness.Big) {
		///red
		nothrow @safe @nogc @property pure ref auto r() inout { return bytes[0]; }
		///green
		nothrow @safe @nogc @property pure ref auto g() inout { return bytes[1]; }
		///blue
		nothrow @safe @nogc @property pure ref auto b() inout { return bytes[2]; }
		///alpha
		nothrow @safe @nogc @property pure ref auto a() inout { return bytes[3]; }
	} else {
		///red
		nothrow @safe @nogc @property pure ref auto r() inout { return bytes[3]; }
		///green
		nothrow @safe @nogc @property pure ref auto g() inout { return bytes[2]; }
		///blue
		nothrow @safe @nogc @property pure ref auto b() inout { return bytes[1]; }
		///alpha
		nothrow @safe @nogc @property pure ref auto a() inout { return bytes[0]; }
	}
	static immutable double fRStepping = 1.0 / 65_535;///Floating-point red stepping
	static immutable double fGStepping = 1.0 / 65_535;///Floating-point green stepping
	static immutable double fBStepping = 1.0 / 65_535;///Floating-point blue stepping
	static immutable double fAStepping = 1.0 / 65_535;///Floating-point alpha stepping
	///Returns the red channel as a normalized floating-point value
	@property float fR() @safe @nogc pure nothrow const {
		return r * fRStepping;
	}
	///Returns the green channel as a normalized floating-point value
	@property float fG() @safe @nogc pure nothrow const {
		return g * fGStepping;
	}
	///Returns the blue channel as a normalized floating-point value
	@property float fB() @safe @nogc pure nothrow const {
		return b * fBStepping;
	}
	///Returns the alpha channel as a normalized floating-point value
	@property float fA() @safe @nogc pure nothrow const {
		return a * fAStepping;
	}
	///Sets the red value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fR(float val) @safe @nogc pure nothrow {
		r = cast(ushort)(val / fRStepping);
		return fR;
	}
	///Sets the green value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fG(float val) @safe @nogc pure nothrow {
		g = cast(ushort)(val / fGStepping);
		return fG;
	}
	///Sets the blue value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fB(float val) @safe @nogc pure nothrow {
		b = cast(ushort)(val / fBStepping);
		return fB;
	}
	///Sets the alpha value channel a normalized floating-point value
	///Returns the new requantized value
	@property float fA(float val) @safe @nogc pure nothrow {
		a = cast(ushort)(val / fAStepping);
		return fB;
	}
	///Standard CTOR
	this(ushort r, ushort g, ushort b, ushort a) pure nothrow @safe @nogc {
		this.r = r;
		this.g = g;
		this.b = b;
		this.a = a;
	}
	///Standard CTOR
	this(float fR, float fG, float fB, float fA) {
		this.fR = fR;
		this.fG = fG;
		this.fB = fB;
		this.fA = fA;
	}
	///Conversion CTOR from monochrome
	this(float fY, float fA = 1.0) {
		this.fR = fY;
		this.fG = fY;
		this.fB = fY;
		this.fA = fA;
	}
	///Template for pixel conversion
	this(ColorType)(ColorType orig) @safe @nogc pure {
		this.fB = orig.fB;
		this.fG = orig.fG;
		this.fR = orig.fR;
		this.fA = orig.fA;
	}
	///Returns true if type has alpha channel support
	static bool hasAlphaChannelSupport() {
		return false;
	}
}
/**
 * Pixel format flags.
 * Undefined should be used for all indexed bitmaps, except 16 bit big endian ones, in which case a single BigEndian bit should be set high.
 * Lower 16 bits should be used for general identification, upper 16 bits are general identificators (endianness, valid alpha channel, etc).
 * 0x01 - 0x1F are reserved for 16 bit truecolor, 0x20 - 0x2F are reserved for 24 bit truecolor, 0x30 - 3F are reserved for integer grayscale,
 * 0x40 - 0x5F are reserved for 32 bit truecolor, 0xF00-0xF0F are reserved for "chunky" indexed images, 0xF10-0xF1F are reserved for planar 
 * indexed images.
 */
enum PixelFormat : uint {
	BigEndian		=	0x00_01_00_00,		///Always little endian if bit not set
	ValidAlpha		=	0x00_02_00_00,		///If set, alpha is used
	SeparateAlphaField	=	0x00_04_00_00,	///If set, then there's a separate alpha field
	RGBX5551		=	0x1,
	RGBA5551		=	RGBX5551 | ValidAlpha,
	RGB565			=	0x2,
	RGB888			=	0x20,
	Grayscale1Bit	=	0x30,
	Grayscale2Bit	=	0x31,
	Grayscale4Bit	=	0x32,
	Grayscale8Bit	=	0x33,
	Grayscale16Bit	=	0x34,
	YX88			=	0x3A,
	YA88			=	YX88 | ValidAlpha,
	YX16_16			=	0x3B,
	YA16_16			=	YX16_16 | ValidAlpha,
	RGBX8888		=	0x40,
	RGBA8888		=	RGBX8888 | ValidAlpha,
	XRGB8888		=	0x41,
	ARGB8888		=	XRGB8888 | ValidAlpha,
	RGB16_16_16		=	0x60,
	RGBX16_16_16_16	=	0x61,
	RGBA16_16_16_16	=	RGBX16_16_16_16 | ValidAlpha,
	RGBX_f32		=	0x101,
	RGBA_f32		=	RGBX_f32 | ValidAlpha,
	Indexed1Bit		=	0xF00,
	Indexed2Bit		=	0xF01,
	Indexed4Bit		=	0xF02,
	Indexed8Bit		=	0xF03,
	Indexed16Bit	=	0xF04,
	Planar2Color	=	0xF10,
	Planar4Color	=	0xF11,
	Planar8Color	=	0xF12,
	Planar16Color	=	0xF13,
	Planar32Color	=	0xF14,
	Planar64Color	=	0xF15,
	Planar128Color	=	0xF16,
	Planar256Color	=	0xF17,
	Planar512Color	=	0xF18,
	Planar1024Color	=	0xF19,
	Planar2048Color	=	0xF1A,
	Planar4096Color	=	0xF1B,
	Planar8192Color	=	0xF1C,
	Planar16384Color=	0xF1D,
	Planar32768Color=	0xF1E,
	Planar65536Color=	0xF1F,
	
	Undefined		=	0,
}
/**
 * Returns the bitdepth of a format.
 */
public ubyte getBitDepth(uint format) @nogc @safe pure nothrow {
	format &= 0xFF_FF;
	switch (format) {
		case 0x00_01: .. case 0x00_1F: case 0x0F_04, 0x00_3A:
			return 16;
		case 0x00_20: .. case 0x00_2F:
			return 24;
		case 0x00_40: .. case 0x00_5F:
			return 32;
		case 0x00_60:
			return 48;
		case 0x0F_00: 
			return 1;
		case 0x0F_01:
			return 2;
		case 0x0F_02, 0x00_31:
			return 4;
		case 0x0F_03, 0x00_30:
			return 8;
		case 0x0F_10: .. case 0x0F_1F:
			return cast(ubyte)(format & 0x0F);
		default: 
			return 0;
	}
}

@safe unittest {
	import std.conv : to;
	assert(ARGB8888.sizeof == 4);
	ARGB8888 test0 = ARGB8888(1.0,1.0,1.0,1.0);
	assert(test0.base == 0xFF_FF_FF_FF, to!string(test0.base));
	test0.fR = test0.fR - ARGB8888.fRStepping;
	assert(test0.r == 0xFE, to!string(test0.r));
	test0.r = 0xFF;
	assert(test0.fR == 1.0, to!string(test0.fR));
	RGB16_16_16 test1 = RGB16_16_16(test0);
	assert(test1.r == 0xFF_FF, to!string(test1.r));
	assert(test1.g == 0xFF_FF, to!string(test1.g));
	assert(test1.b == 0xFF_FF, to!string(test1.b));
}