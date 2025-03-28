package ttf


import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:unicode/utf16"
is_enum :: intrinsics.type_is_enum

// Integer types
BYTE :: u8
CHAR :: i8
USHORT :: u16be
SHORT :: i16be
UINT24 :: u32be // 24-bit unsigned integer (stored in 3 bytes)
ULONG :: u32be
LONG :: i32be
LONGDATETIME :: i64be // Date and time represented as seconds since 12:00 midnight on January 1, 1904

// Coordinate and distance types
FWORD :: i16be
UFWORD :: u16be

// Fixed-point types
Fixed :: i32be // 32-bit signed fixed-point number (16.16)
F2DOT14 :: i16be // 16-bit signed fixed-point number with 2 integer and 14 fractional bits (2.14)
LONGLONG :: i64be

Raw_Glyph :: distinct u16be


// Special types
Offset16 :: u16be // 16-bit offset
Offset32 :: u32be // 32-bit offset
Version16Dot16 :: u32be // OpenType version number (16.16)
u24 :: [3]byte


Tag :: distinct u32

tag_to_u32 :: proc(tag: [4]byte) -> Tag {
	return Tag(u32(tag[0]) << 24 | u32(tag[1]) << 16 | u32(tag[2]) << 8 | u32(tag[3]))
}


// Helper function to convert Fixed to float
Fixed_to_Float :: proc(fixed: Fixed) -> f32 {
	return f32(fixed) / 65536.0
}

// Helper function to convert F2DOT14 to float
F2DOT14_to_Float :: proc(value: F2DOT14) -> f32 {
	return f32(value) / 16384.0
}

utf16be_to_utf8 :: proc(data: []u8) -> string {
	if len(data) == 0 || len(data) % 2 != 0 {
		return string(data) // Return as-is for empty or invalid data
	}
	when ODIN_ENDIAN == .Little {
		// Convert the BE bytes to u16 array with correct endianness
		u16_data := make([]u16, len(data) / 2)
		for i := 0; i < len(data) / 2; i += 1 {
			// Convert from BE to native endianness
			u16_data[i] = (u16(data[i * 2]) << 8) | u16(data[i * 2 + 1])
		}
	} else {
		u16_data := data
	}
	// UTF-8 can be up to 2 times larger than UTF-16
	utf8_buf := make([]byte, len(u16_data) * 2)

	// Convert from UTF-16 to UTF-8
	n := utf16.decode_to_utf8(utf8_buf, u16_data)

	when ODIN_ENDIAN == .Little {delete(u16_data)}
	return string(utf8_buf[:n])
}

read_at_offset :: proc(buf: []u8, byte_offset: uint, $T: typeid) -> T {
	assert(int(byte_offset) + size_of(T) <= len(buf), "Buffer overrun")
	ptr := transmute(^T)(&buf[byte_offset])
	return ptr^
}
// Reads BE format; returns BE value
read_u16be :: proc(data: []byte, offset: uint) -> u16be {
	return read_at_offset(data, offset, u16be)
}
read_u32be :: proc(data: []byte, offset: uint) -> u32be {
	return read_at_offset(data, offset, u32be)
}
read_i16be :: proc(data: []byte, offset: uint) -> i16be {
	return read_at_offset(data, offset, i16be)
}
read_i32be :: proc(data: []byte, offset: uint) -> i32be {
	return read_at_offset(data, offset, i32be)
}
// Type-specific readers with proper endianness conversion
read_u8 :: proc(buf: []u8, offset: uint) -> u8 {
	return read_at_offset(buf, offset, u8)
}

read_i8 :: proc(buf: []u8, offset: uint) -> i8 {
	return read_at_offset(buf, offset, i8)
}

read_u16 :: proc(buf: []u8, offset: uint) -> u16 {
	v := read_at_offset(buf, offset, u16)
	return be_to_host_u16(v)
}

read_i16 :: proc(buf: []u8, offset: uint) -> i16 {
	v := read_at_offset(buf, offset, i16)
	return be_to_host_i16(v)
}

read_u32 :: proc(buf: []u8, offset: uint) -> u32 {
	v := read_at_offset(buf, offset, u32)
	return be_to_host_u32(v)
}

read_i32 :: proc(buf: []u8, offset: uint) -> i32 {
	v := read_at_offset(buf, offset, i32)
	return be_to_host_i32(v)
}

read_u64 :: proc(buf: []u8, offset: uint) -> u64 {
	// For 64-bit values, read as two 32-bit values to ensure proper alignment
	high := u64(read_u32(buf, offset)) << 32
	low := u64(read_u32(buf, offset + 4))
	return high | low
}

read_i64 :: proc(buf: []u8, offset: uint) -> i64 {
	return transmute(i64)read_u64(buf, offset)
}

// Font-specific type readers
read_fixed :: proc(buf: []u8, offset: uint) -> f32 {
	raw := read_u32(buf, offset)
	whole := f32(raw >> 16)
	frac := f32(raw & 0xFFFF) / 65536.0
	return whole + frac
}

read_tag :: proc(buf: []u8, byte_offset: uint) -> string {
	assert(int(byte_offset) * 4 <= len(buf), "Buffer overrun")
	ptr := transmute([^]u8)(&buf[byte_offset])
	tag := ptr[:4]
	// Trim any non-ASCII characters from the end (supports for 3-letter tables)
	non_char_values := 0
	for i := 3; i >= 0; i -= 1 {
		if (transmute([]u8)tag)[i] < 0x20 || (transmute([]u8)tag)[i] > 0x7F {non_char_values += 1}
	}
	tag = tag[:4 - non_char_values]
	return string(tag)
}

be_to_host_u16 :: proc(val: u16) -> u16 {
	when ODIN_ENDIAN == .Little {
		return (val >> 8) | (val << 8)
	} else {
		return val
	}
}

be_to_host_i16 :: proc(val: i16) -> i16 {
	when ODIN_ENDIAN == .Little {
		v := transmute(u16)val
		r := (v >> 8) | (v << 8)
		return transmute(i16)r
	} else {
		return val
	}
}

be_to_host_u32 :: proc(val: u32) -> u32 {
	when ODIN_ENDIAN == .Little {
		return(
			((val & 0x000000FF) << 24) |
			((val & 0x0000FF00) << 8) |
			((val & 0x00FF0000) >> 8) |
			((val & 0xFF000000) >> 24) \
		)
	} else {
		return val
	}
}

be_to_host_i32 :: proc(val: i32) -> i32 {
	when ODIN_ENDIAN == .Little {
		v := transmute(u32)val
		r :=
			((v & 0x000000FF) << 24) |
			((v & 0x0000FF00) << 8) |
			((v & 0x00FF0000) >> 8) |
			((v & 0xFF000000) >> 24)
		return transmute(i32)r
	} else {
		return val
	}
}

be_to_host_u64 :: proc(val: u64) -> u64 {
	when ODIN_ENDIAN == .Little {
		return(
			((val & 0x00000000000000FF) << 56) |
			((val & 0x000000000000FF00) << 40) |
			((val & 0x0000000000FF0000) << 24) |
			((val & 0x00000000FF000000) << 8) |
			((val & 0x000000FF00000000) >> 8) |
			((val & 0x0000FF0000000000) >> 24) |
			((val & 0x00FF000000000000) >> 40) |
			((val & 0xFF00000000000000) >> 56) \
		)
	} else {
		return val
	}
}

be_to_host_i64 :: proc(val: i64) -> i64 {
	when ODIN_ENDIAN == .Little {
		v := transmute(u64)val
		r :=
			((v & 0x00000000000000FF) << 56) |
			((v & 0x000000000000FF00) << 40) |
			((v & 0x0000000000FF0000) << 24) |
			((v & 0x00000000FF000000) << 8) |
			((v & 0x000000FF00000000) >> 8) |
			((v & 0x0000FF0000000000) >> 24) |
			((v & 0x00FF000000000000) >> 40) |
			((v & 0xFF00000000000000) >> 56)
		return transmute(i64)r
	} else {
		return val
	}
}

// For Fixed point values (16.16)
be_to_host_fixed :: proc(val: u32) -> f32 {
	v := be_to_host_u32(val)
	whole := f32(v >> 16)
	frac := f32(v & 0xFFFF) / 65536.0
	return whole + frac
}

// For F2DOT14 values (2.14)
be_to_host_f2dot14 :: proc(val: i16) -> f32 {
	v := be_to_host_i16(val)
	return f32(v) / 16384.0
}

u24_to_u32 :: proc(value: u24) -> u32 {
	return (u32(value[0]) << 16) | (u32(value[1]) << 8) | u32(value[2])
}

xbounds_check :: #force_inline proc(condition: bool, loc := #caller_location) -> bool {
	when ODIN_DEBUG {
		assert(!condition, "Font parser bounds check failed", loc)
	}
	return condition
}
bounds_check :: proc(condition: bool, loc := #caller_location) -> bool {
	if condition {
		fmt.printf("BOUNDS CHECK FAILURE at %v:%v\n", loc.file_path, loc.line)
		return true
	}
	return false
}

enum_tag_into_string :: proc(t: $T) -> [4]u8 where is_enum(T) {
	str := reflect.enum_string(t)
	tag: [4]u8
	for i in 0 ..< min(len(str), 4) {
		tag[i] = u8(str[i])
	}
	return tag
}


// insert_at_elem inserts elements at a specific position in a dynamic array
insert_at_elem :: proc(array: ^[dynamic]$T, index: int, values: ..T) {
	if array == nil || index < 0 || index > len(array^) {return}

	if len(values) == 0 {return} 	// Nothing to insert

	// Ensure we have enough capacity
	old_len := len(array^)
	new_len := old_len + len(values)
	if cap(array^) < new_len {
		// Grow by at least 50% to avoid frequent reallocations
		new_cap := max(new_len, cap(array^) * 3 / 2)
		reserve(array, new_cap)
		resize(array, new_len)
	} else {
		// We have enough capacity, just extend the length
		resize(array, new_len)
	}

	// Shift elements to make room
	if index < old_len {
		// Move elements from the end
		for i := old_len - 1; i >= index; i -= 1 {
			array[i + len(values)] = array[i]
		}
	}

	// Insert new values
	for i := 0; i < len(values); i += 1 {
		array[index + i] = values[i]
	}
}
