package rune

// Can track up to 256 lookups
Lookup_Set :: struct {
	bits: [4]u64,
}

lookup_set_add :: proc(set: ^Lookup_Set, index: u16) {
	array_idx := int(index) / 64
	bit_pos := uint(index) % 64

	if array_idx < len(set.bits) {
		set.bits[array_idx] |= 1 << bit_pos
	}
}

lookup_set_contains :: proc(set: ^Lookup_Set, index: u16) -> bool {
	array_idx := int(index) / 64
	bit_pos := uint(index) % 64

	if array_idx < len(set.bits) {
		return (set.bits[array_idx] & (1 << bit_pos)) != 0
	}
	return false
}

// Combined check and add function
lookup_set_try_add :: proc(set: ^Lookup_Set, index: u16) -> (already_exists: bool) {
	array_idx := int(index) / 64
	bit_pos := uint(index) % 64

	if array_idx < len(set.bits) {
		// Check if bit is already set
		already_exists = (set.bits[array_idx] & (1 << bit_pos)) != 0

		// Set the bit regardless
		set.bits[array_idx] |= 1 << bit_pos
	} else {
		when ODIN_DEBUG {panic("Lookup_Set Out of Bounds")}
	}

	return already_exists
}
