/*
 * dimage - util.d
 * by Laszlo Szeremi
 *
 * Copyright under Boost Software License.
 */

module dimage.util;

/**
 * Safely casts one type of an array to another.
 */
T[] reinterpretCast(T, U)(ref U[] input) @trusted pure {
	T[] _reinterpretCast() @system pure {
		return cast(T[])(cast(void[])input);
	}
	if ((U.sizeof * input.length) % T.sizeof == 0) {
		return _reinterpretCast();
	} else {
		throw new Exception("Cannot cast safely!");
	}
}
/**
 * Safely casts one type of an array to a single instance of a type.
 */
T reinterpretGet(T, U)(ref U[] input) @trusted pure {
	T _reinterpretGet() @system pure {
		return (cast(T[])(cast(void[])input))[0];
	}
	if (U.sizeof * input.length == T.sizeof) {
		return _reinterpretGet;
	} else {
		throw new Exception("Cannot cast safely!");
	}
}
/**
 * Copies the content of a string array into a static char array
 */
void stringCpy(CR)(ref CR target, string input) {
	for(size_t i ; i < input.length ; i++){
		target[i] = input[i];
	}
}