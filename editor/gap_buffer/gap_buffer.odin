package gap_buffer
import "core:unicode/utf8"
import "core:mem"
import "core:testing"
import "core:fmt"
import "core:strings"

main :: proc() {
	test_chars(nil)
	test_slices(nil)
	test_utf8(nil)
}

LogicalPosition :: distinct int  // Position ignoring the gap
AbsolutePosition :: distinct int // Raw array index position

GapBuffer :: struct {
	buf:       []u8,
	gap_start: AbsolutePosition,
	gap_end:   AbsolutePosition,
}

make_gap_buffer :: proc(n_bytes: int, allocator := context.allocator) -> GapBuffer {
	b := GapBuffer{}
	b.buf = make([]u8, n_bytes)
	b.gap_end = AbsolutePosition(n_bytes)
	return b
}

insert :: proc {
	insert_rune,
	insert_slice,
	insert_string,
	insert_character,
}

insert_cursor :: proc {
	insert_rune_cursor,
	insert_string_cursor,
}

insert_rune :: proc(b: ^GapBuffer, p: LogicalPosition, r: rune) {
	bytes, len := utf8.encode_rune(r)
	insert_slice(b, p, bytes[:len])
}

// Returns the new cursor position after insertion
insert_rune_cursor :: proc(b: ^GapBuffer, p: LogicalPosition, r: rune) -> LogicalPosition {
	bytes, byte_len := utf8.encode_rune(r)
	insert_slice(b, p, bytes[:byte_len])
	return p + LogicalPosition(byte_len)
}

// Returns the new cursor position after string insertion
insert_string_cursor :: proc(b: ^GapBuffer, p: LogicalPosition, s: string) -> LogicalPosition {
	insert_slice(b, p, transmute([]u8)s)
	return p + LogicalPosition(len(s))
}

// Returns the new cursor position after rune deletion (backspace)
delete_runes_backwards_cursor :: proc(b: ^GapBuffer, p: LogicalPosition, n_runes: int = 1) -> LogicalPosition {
	if n_runes <= 0 || p == 0 {return p}
	start_pos := find_rune_start_backwards(b, p, n_runes)
	delete_bytes_at(b, start_pos, int(p - start_pos))
	return start_pos
}
insert_string :: #force_inline proc(b: ^GapBuffer, p: LogicalPosition, s: string) {
	insert_slice(b, p, transmute([]u8)s)
}
insert_slice :: proc(b: ^GapBuffer, p: LogicalPosition, chars: []u8) {
	slice_len := len(chars)
	check_gap_size(b, slice_len)
	shift_gap_to(b, p)
	gap_len := b.gap_end - b.gap_start
	gap := cast([^]u8)&b.buf[b.gap_start]
	copy_slice(gap[:gap_len], chars)
	b.gap_start += AbsolutePosition(slice_len)
}
insert_character :: proc(b: ^GapBuffer, p: LogicalPosition, char: u8) {
	check_gap_size(b, 1)
	shift_gap_to(b, p)
	b.buf[b.gap_start] = char
	b.gap_start += 1
}

delete_bytes_at :: proc(b: ^GapBuffer, p: LogicalPosition, n_bytes: int) {
	if n_bytes <= 0 {return}
	shift_gap_to(b, p)
	b.gap_end = AbsolutePosition(min(int(b.gap_end) + n_bytes, len(b.buf)))
}

delete_runes_at :: proc(b: ^GapBuffer, p: LogicalPosition, n_runes: int = 1) {
	if n_runes <= 0 {return}
	byte_len := count_bytes_for_runes(b, p, n_runes)
	delete_bytes_at(b, p, byte_len)
}

delete_runes_backwards :: proc(b: ^GapBuffer, p: LogicalPosition, n_runes: int = 1) {
	if n_runes <= 0 || p == 0 {return}
	start_pos := find_rune_start_backwards(b, p, n_runes)
	byte_len := int(p - start_pos)
	delete_bytes_at(b, start_pos, byte_len)
}

buffer_length :: proc(b: ^GapBuffer) -> int {
	return len(b.buf) - int(b.gap_end - b.gap_start)
}

// Convert logical position to absolute array position
logical_to_absolute :: proc(b: ^GapBuffer, logical_pos: LogicalPosition) -> AbsolutePosition {
	// gap_start and gap_end are absolute positions
	// logical positions 0..gap_start-1 map to absolute positions 0..gap_start-1
	// logical positions gap_start+ map to absolute positions gap_end+
	
	if AbsolutePosition(logical_pos) < b.gap_start {
		// Position is before the gap in absolute terms
		return AbsolutePosition(logical_pos)
	} else {
		// Position is at or after the gap in logical terms
		// Skip over the gap: add gap size to get absolute position
		return AbsolutePosition(logical_pos) + (b.gap_end - b.gap_start)
	}
}

// Convert absolute array position to logical position
absolute_to_logical :: proc(b: ^GapBuffer, abs_pos: AbsolutePosition) -> LogicalPosition {
	if abs_pos < b.gap_start {
		return LogicalPosition(abs_pos)
	} else if abs_pos < b.gap_end {
		// Position is inside the gap (should not happen in normal use)
		return LogicalPosition(b.gap_start)
	} else {
		// Position is after the gap
		return LogicalPosition(abs_pos - (b.gap_end - b.gap_start))
	}
}

count_bytes_for_runes :: proc(b: ^GapBuffer, start_pos: LogicalPosition, n_runes: int) -> int {
	pos := logical_to_absolute(b, start_pos)
	byte_count := 0
	runes_found := 0
	buf_len := len(b.buf)
	
	for runes_found < n_runes && int(pos) < buf_len {
		if pos == b.gap_start {
			pos = b.gap_end
			if int(pos) >= buf_len {break}
		}
		
		// Find the length of the current UTF-8 sequence
		c := b.buf[pos]
		rune_byte_len := 1
		if c >= 0x80 {
			if c >= 0xF0 {rune_byte_len = 4}
			else if c >= 0xE0 {rune_byte_len = 3}
			else if c >= 0xC0 {rune_byte_len = 2}
		}
		
		// Make sure we don't go past the gap or buffer end
		end_pos := pos + AbsolutePosition(rune_byte_len)
		if pos < b.gap_start && end_pos > b.gap_start {
			// Rune spans across gap - this shouldn't happen with valid UTF-8
			break
		}
		if int(end_pos) > buf_len {break}
		
		pos += AbsolutePosition(rune_byte_len)
		byte_count += rune_byte_len
		runes_found += 1
	}
	
	return byte_count
}

find_rune_start_backwards :: proc(b: ^GapBuffer, from_pos: LogicalPosition, n_runes: int) -> LogicalPosition {
	pos := logical_to_absolute(b, from_pos)
	runes_found := 0
	
	for runes_found < n_runes && pos > 0 {
		pos -= 1
		
		// Skip over the gap
		if pos == b.gap_end - 1 {
			pos = b.gap_start - 1
			if pos < 0 {break}
		}
		
		// Check if this is the start of a UTF-8 sequence
		c := b.buf[pos]
		if c < 0x80 || (c & 0xC0) != 0x80 {
			// This is either ASCII or the start of a multi-byte sequence
			runes_found += 1
		}
	}
	
	return absolute_to_logical(b, pos)
}

move_cursor_forward :: proc(b: ^GapBuffer, pos: LogicalPosition, n_runes: int = 1) -> LogicalPosition {
	logical_pos := pos
	logical_buf_len := buffer_length(b)
	
	for i := 0; i < n_runes && int(logical_pos) < logical_buf_len; i += 1 {
		// Convert to absolute position for byte access
		abs_pos := logical_to_absolute(b, logical_pos)
		if int(abs_pos) >= len(b.buf) {break}
		
		// Get the byte length of the current rune
		c := b.buf[abs_pos]
		rune_byte_len := 1
		if c >= 0x80 {
			if c >= 0xF0 {rune_byte_len = 4}
			else if c >= 0xE0 {rune_byte_len = 3}
			else if c >= 0xC0 {rune_byte_len = 2}
		}
		
		logical_pos += LogicalPosition(rune_byte_len)
	}
	
	return LogicalPosition(min(int(logical_pos), logical_buf_len))
}

move_cursor_backward :: proc(b: ^GapBuffer, pos: LogicalPosition, n_runes: int = 1) -> LogicalPosition {
	return find_rune_start_backwards(b, pos, n_runes)
}

copy_line_from_buffer :: proc(
	dest: [^]u8,
	max_width: int,
	b: ^GapBuffer,
	start_pos: LogicalPosition,
) -> (
	n_copied: int,
	wrote_to: LogicalPosition,
) {
	logical_pos := start_pos
	logical_buf_len := buffer_length(b)
	n_copied = 0
	
	for i := 0; i < max_width && int(logical_pos) < logical_buf_len; i += 1 {
		// Convert to absolute position for byte access
		abs_pos := logical_to_absolute(b, logical_pos)
		if int(abs_pos) >= len(b.buf) {break}
		
		c := b.buf[abs_pos]
		dest[i] = c
		n_copied += 1
		logical_pos += 1
		
		if c == '\n' {break} // End of line
	}
	
	return n_copied, LogicalPosition(min(int(logical_pos), logical_buf_len))
}

shift_gap_to :: proc(b: ^GapBuffer, p: LogicalPosition) {
	gap_len := int(b.gap_end - b.gap_start)
	p_clamped := AbsolutePosition(min(int(p), len(b.buf) - gap_len)) // prevent referencing off the end of the buffer
	if b.gap_start == p_clamped {return}

	if b.gap_start < p_clamped {
		//   v~~~~v
		//[12]           [3456789abc]
		//--------|------------------ Gap is BEFORE Cursor
		//[123456]           [789abc]
		delta := int(p_clamped - b.gap_start)
		mem.copy(&b.buf[b.gap_start], &b.buf[b.gap_end], delta)
		b.gap_start += AbsolutePosition(delta)
		b.gap_end += AbsolutePosition(delta)
	} else if b.gap_start > p_clamped {
		//   v~~~v
		//[123456]           [789abc]
		//---|----------------------- Gap is AFTER Cursor
		//[12]           [3456789abc]
		delta := int(b.gap_start - p_clamped)
		mem.copy(&b.buf[b.gap_end - AbsolutePosition(delta)], &b.buf[b.gap_start - AbsolutePosition(delta)], delta)
		b.gap_start -= AbsolutePosition(delta)
		b.gap_end -= AbsolutePosition(delta)
	}
}
check_gap_size :: proc(b: ^GapBuffer, n_bytes_req: int, allocator := context.allocator) {
	gap_len := int(b.gap_end - b.gap_start)
	if gap_len < n_bytes_req {
		shift_gap_to(b, LogicalPosition(len(b.buf) - gap_len))
		new_buf := make([]u8, 2 * len(b.buf)) // TODO: re-allocate HeapRealloc() ?
		copy_slice(new_buf, b.buf[:])
		delete(b.buf)
		b.buf = new_buf
		b.gap_end = AbsolutePosition(len(b.buf))
	}
}

// Helper functions for the test
find_line_start_test :: proc(pos: int, gb: ^GapBuffer) -> int {
	current_pos := 0
	
	for current_pos <= pos {
		line := make([]u8, 100)
		n, next_pos := copy_line_from_buffer(&line[0], len(line), gb, LogicalPosition(current_pos))
		if n == 0 {break}
		
		// If position is in this line, return current_pos
		if pos >= current_pos && pos < int(next_pos) {
			return current_pos
		}
		
		current_pos = int(next_pos)
	}
	
	return current_pos
}

find_line_end_test :: proc(line_start: int, gb: ^GapBuffer) -> int {
	line := make([]u8, 100)
	n, next_pos := copy_line_from_buffer(&line[0], len(line), gb, LogicalPosition(line_start))
	
	if n == 0 {return line_start}
	
	line_text := string(line[:n])
	if strings.has_suffix(line_text, "\n") {
		// Position just before the newline (end of actual text)
		return int(next_pos) - 2  // -1 for newline, -1 more to get last text char
	} else {
		// End of buffer (no newline) - position after last character
		return int(next_pos) - 1
	}
}


// import "core:fmt"
@(test)
test_chars :: proc(t: ^testing.T) {
	gb := make_gap_buffer(2)
	insert_character(&gb, 0, 'D') // from start
	insert_character(&gb, 0, 'C')
	insert_character(&gb, 0, 'B')
	insert_character(&gb, 0, 'A')
	insert_character(&gb, 3, '3') // in middle
	insert_character(&gb, 3, '2')
	insert_character(&gb, 3, '1')
	insert_character(&gb, 7, 'E') // at tail
	insert_character(&gb, 8, 'F')

	line := make([]u8, 9)
	n, p := copy_line_from_buffer(&line[0], len(line), &gb, 0)
	text := string(line)

	assert(text == "ABC123DEF", "expected strings to match")
	assert(n == 9, "expected 9 chars copied")
	assert(p == 9, "expeceted buffer-position after line of text")
}
@(test)
test_slices :: proc(t: ^testing.T) {
	gb := make_gap_buffer(2)
	insert_slice(&gb, 0, transmute([]u8)string("ABCD")) // from start
	insert_string(&gb, 3, "123") // from start
	insert_slice(&gb, 7, transmute([]u8)string("EF")) // from start

	line := make([]u8, 9)
	n, p := copy_line_from_buffer(&line[0], len(line), &gb, 0)
	text := string(line)

	assert(text == "ABC123DEF", "expected strings to match")
	assert(n == 9, "expected 9 chars copied")
	assert(p == 9, "expeceted buffer-position after line of text")
}
@(test)
test_utf8 :: proc(t: ^testing.T) {
	gb := make_gap_buffer(2)
	insert_slice(&gb, 0, transmute([]u8)string("ABCD")) // from start
	insert_rune(&gb, 3, '涼') // from start
	insert_slice(&gb, 7, transmute([]u8)string("EF")) // from start

	line := make([]u8, 9)
	n, p := copy_line_from_buffer(&line[0], len(line), &gb, 0)
	text := string(line)
	// fmt.println(gb.buf)
	// fmt.println(text)

	assert(text == "ABC涼DEF", "expected strings to match")
	assert(n == 9, "expected 9 chars copied")
	assert(p == 9, "expeceted buffer-position after line of text")
}

@(test)
test_gap_with_newline :: proc(t: ^testing.T) {
	gb := make_gap_buffer(100)
	
	// Simulate the editor initialization with "AB\n"
	insert_string(&gb, 0, "AB\n")
	
	fmt.printf("After initial insert: gap_start=%v, gap_end=%v, buffer_length=%v\n", 
		gb.gap_start, gb.gap_end, buffer_length(&gb))
	
	// Move cursor to position 3 (after "AB\n")
	cursor_pos := 3
	fmt.printf("Cursor at position %v (end of buffer)\n", cursor_pos)
	
	// Copy the current line at cursor position
	line := make([]u8, 20)
	n, p := copy_line_from_buffer(&line[0], len(line), &gb, 0)
	text := string(line[:n])
	fmt.printf("Line 0: '%s' (n=%v, p=%v)\n", text, n, p)
	
	// Now delete the newline (backspace at position 3 to delete position 2 which is '\n')
	delete_runes_backwards(&gb, 3, 1)  // Delete 1 rune backwards from position 3
	
	fmt.printf("After deleting newline: gap_start=%v, gap_end=%v, buffer_length=%v\n", 
		gb.gap_start, gb.gap_end, buffer_length(&gb))
	
	// New cursor position should be 2 (after "AB")
	new_cursor_pos := 2
	fmt.printf("New cursor position: %v\n", new_cursor_pos)
	
	// Copy the line again to see the result
	n2, p2 := copy_line_from_buffer(&line[0], len(line), &gb, 0)
	text2 := string(line[:n2])
	fmt.printf("After deletion line 0: '%s' (n=%v, p=%v)\n", text2, n2, p2)
	
	// The line should now be "AB" with no newline
	assert(text2 == "AB", "expected line to be 'AB' after newline deletion")
	assert(!strings.has_suffix(text2, "\n"), "expected line to not end with newline")
	
	// Test line finding for different cursor positions in "AB"
	fmt.printf("\n--- Testing line detection in 'AB' ---\n")
	
	// Simulate find_line_number_at_position logic
	test_positions := []int{0, 1, 2}
	for pos in test_positions {
		line_count := 0
		current_pos := 0
		fmt.printf("Finding line for position %v:\n", pos)
		
		for current_pos < pos {
			n, next_pos := copy_line_from_buffer(&line[0], len(line), &gb, LogicalPosition(current_pos))
			if n == 0 {break}
			
			line_text := string(line[:n])
			fmt.printf("  Line %v: pos %v-%v, text='%s'\n", line_count, current_pos, int(next_pos)-1, line_text)
			
			if pos < int(next_pos) {
				fmt.printf("  -> Position %v is in line %v\n", pos, line_count)
				break
			}
			
			line_count += 1
			current_pos = int(next_pos)
		}
		
		if current_pos >= pos {
			fmt.printf("  -> Position %v is in line %v\n", pos, line_count)
		}
	}
}

@(test)
test_multi_line_navigation :: proc(t: ^testing.T) {
	gb := make_gap_buffer(100)
	
	// Create multi-line content for navigation testing
	insert_string(&gb, 0, "Line1\nLine22\nLine333\n")
	
	fmt.printf("Multi-line buffer: length=%v\n", buffer_length(&gb))
	
	// Test finding line boundaries
	test_positions := []int{0, 3, 5, 6, 9, 12, 15, 19, 20}
	for pos in test_positions {
		line_count := 0
		current_pos := 0
		
		for current_pos <= pos {
			line := make([]u8, 20)
			n, next_pos := copy_line_from_buffer(&line[0], len(line), &gb, LogicalPosition(current_pos))
			if n == 0 {break}
			
			line_text := string(line[:n])
			if pos >= current_pos && pos < int(next_pos) {
				fmt.printf("Position %v: line %v, text='%s'\n", pos, line_count, 
					strings.replace_all(line_text, "\n", "\\n"))
				break
			}
			
			current_pos = int(next_pos)
			line_count += 1
		}
	}
}

@(test)
test_home_end_navigation :: proc(t: ^testing.T) {
	gb := make_gap_buffer(100)
	
	// Create test content with multiple lines
	insert_string(&gb, 0, "First line\nSecond line\nThird line")
	
	fmt.printf("Buffer length: %v\n", buffer_length(&gb))
	
	// Debug: print each line to understand the structure
	current_pos := 0
	line_num := 0
	for current_pos < buffer_length(&gb) {
		line := make([]u8, 100)
		n, next_pos := copy_line_from_buffer(&line[0], len(line), &gb, LogicalPosition(current_pos))
		if n == 0 {break}
		
		line_text := string(line[:n])
		fmt.printf("Line %v: pos %v-%v, text='%s'\n", line_num, current_pos, int(next_pos)-1, 
			strings.replace_all(line_text, "\n", "\\n"))
		
		current_pos = int(next_pos)
		line_num += 1
	}
	
	// Test finding line start/end for different positions
	// Based on actual debug output:
	// Line 0: pos 0-10, text='First line\n' -> text ends at 9, newline at 10
	// Line 1: pos 11-22, text='Second line\n' -> text ends at 21, newline at 22  
	// Line 2: pos 23-32, text='Third line' -> text ends at 32 (end of buffer)
	test_cases := []struct{pos: int, expected_start: int, expected_end: int}{
		{5, 0, 9},   // Middle of "First line" -> start=0, end=9 (before \n)
		{11, 11, 21}, // Start of "Second line" -> start=11, end=21 (before \n)
		{16, 11, 21}, // Middle of "Second line" -> start=11, end=21 (before \n) 
		{25, 23, 32}, // Middle of "Third line" -> start=23, end=32 (end of buffer)
	}
	
	for test_case in test_cases {
		pos := test_case.pos
		expected_start := test_case.expected_start
		expected_end := test_case.expected_end
		
		// Find line start
		line_start := find_line_start_test(pos, &gb)
		
		// Find line end  
		line_end := find_line_end_test(line_start, &gb)
		
		fmt.printf("Position %v: line_start=%v (expected %v), line_end=%v (expected %v)\n", 
			pos, line_start, expected_start, line_end, expected_end)
			
		assert(line_start == expected_start, fmt.tprintf("Wrong line start for pos %v", pos))
		assert(line_end == expected_end, fmt.tprintf("Wrong line end for pos %v", pos))
	}
}