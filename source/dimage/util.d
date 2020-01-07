/*
 * dimage - util.d
 * by Laszlo Szeremi
 *
 * Copyright under Boost Software License.
 *
 * Note: Many elements of this file might be outsourced to an external library.
 */

module dimage.util;

public import bitleveld.reinterpret;

/**
 * Copies the content of a string array into a static char array
 */
void stringCpy(CR)(ref CR target, string input) {
	for(size_t i ; i < input.length ; i++){
		target[i] = input[i];
	}
}
/**
 * Adam7 deinterlacing algorithm
 */
ubyte[] adam7(ubyte[] input, size_t bytedepth) {
	return null;
}
/**
 * Image compatison for unittests
 */
version(unittest) {
	import dimage.base;
	import std.conv : to;
	void compareImages(bool ignoreAlpha = false) (Image a, Image b) {
		assert (a.height == b.height);
		assert (a.width == b.width);
		for(int y ; y < a.height ; y++) {
			for(int x ; x < a.width ; x++) {
				auto pixelA = a.readPixel(x,y);
				auto pixelB = b.readPixel(x,y);
				static if(ignoreAlpha) {
					assert(pixelA.r == pixelB.r && pixelA.g == pixelB.g && pixelA.b == pixelB.b, "Pixel mismatch at position " ~ 
							to!string(x) ~ ";" ~ to!string(y) ~ "\nA = " ~ pixelA.toString ~ "; B = " ~ pixelB.toString);
				} else {
					assert(pixelA == pixelB, "Pixel mismatch at position " ~ 
							to!string(x) ~ ";" ~ to!string(y) ~ "\nA = " ~ pixelA.toString ~ "; B = " ~ pixelB.toString);
				}
			}
		}
	}
}