package enum_rewriter

import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:os"
import "core:strings"

Entry :: struct {
	ident, comment: string,
}

main :: proc() {
	// Source file with the enum
	source_path := "./tags.odin"

	// Output files
	enum_output_path := "./tags_generated.odin"
	switch_output_path := "./tag_switch.odin"

	// Read the source file
	data, ok := os.read_entire_file(source_path)
	if !ok {
		fmt.printf("Failed to read file: %v\n", source_path)
		return
	}
	defer delete(data)

	// Parse the file
	p := parser.Parser{}
	f := ast.File {
		src      = string(data),
		fullpath = source_path,
	}
	ok = parser.parse_file(&p, &f)
	if !ok {
		fmt.printf("Failed to parse file: %v\n", source_path)
		return
	}

	// Look for the Feature_Tag enum
	enum_name := ""
	enum_fields: [dynamic]Entry

	for decl in f.decls {
		value, vok := decl.derived_stmt.(^ast.Value_Decl)
		if !vok {
			continue // Not a value declaration
		}

		if len(value.names) == 0 || len(value.values) == 0 {
			continue // No name or value
		}

		the_name := string(data[value.names[0].pos.offset:value.names[0].end.offset])
		the_body := value.values[0]
		// We're only interested in enum types
		enum_type, is_enum := the_body.derived.(^ast.Enum_Type)
		if !is_enum {continue}

		enum_name = the_name

		// Collect all enum fields
		for field in enum_type.fields {
			if ident, ok := field.derived.(^ast.Ident); ok {
				field_name := ident.name

				// If there's a comment after the field, grab it
				comment := ""
				if ident.end.offset < len(data) {
					line_end := strings.index_byte(string(data[ident.end.offset:]), '\n')
					if line_end > 0 {
						// +1 dont get ,
						comment_text := string(
							data[ident.end.offset + 1:ident.end.offset + line_end],
						)
						if strings.contains(comment_text, "//") {
							comment = comment_text
						}
					}
				}
				append(&enum_fields, Entry{field_name, comment})
			}
		}

		break // Found what we were looking for
	}

	// Generate the updated enum with u32 values
	enum_content := generate_enum_with_u32_values(enum_name, enum_fields[:])
	switch_content := generate_switch_statement(enum_name, enum_fields[:])

	os.write_entire_file("gen_enum.odin", transmute([]byte)enum_content)
	// os.write_entire_file("gen_switch.odin", transmute([]byte)switch_content)

}

// Generate an updated version of the enum with u32 values for each tag
// Returns the generated content as a string
generate_enum_with_u32_values :: proc(enum_name: string, fields: []Entry) -> string {
	sb := strings.builder_make()

	// Begin enum definition
	strings.write_string(&sb, "// Tags are encoded by [4]u8 into a u32 for faster compares\n")
	strings.write_string(&sb, enum_name)
	strings.write_string(&sb, " :: enum u32 {\n")

	// Special handling for AUTO
	strings.write_string(&sb, "    AUTO = 0x20_20_20_20, // Four spaces\n")

	// Write each enum field with its u32 value
	for i := 1; i < len(fields); i += 1 {
		field := fields[i]

		// Split field name and comment if present
		field_name := field.ident
		comment := field.comment

		// Calculate the u32 value for this tag
		tag_value := tag_to_u32(field_name)

		// Format hex value with underscores for readability
		hex_value := fmt.aprintf(
			"0x%02X_%02X_%02X_%02X",
			(tag_value >> 24) & 0xFF,
			(tag_value >> 16) & 0xFF,
			(tag_value >> 8) & 0xFF,
			tag_value & 0xFF,
		)

		// Write the field with its value and comment
		if comment != "" {
			strings.write_string(
				&sb,
				fmt.aprintf("    %s = %s, %s\n", field_name, hex_value, comment),
			)
		} else {
			strings.write_string(&sb, fmt.aprintf("    %s = %s,\n", field_name, hex_value))
		}
	}

	// Close the enum definition
	strings.write_string(&sb, "}\n")

	return strings.to_string(sb)
}

// Generate a switch statement for mapping tags to bit positions
// Generate a switch statement for mapping tags to bit positions
// Returns the generated content as a string
generate_switch_statement :: proc(enum_name: string, fields: []Entry) -> string {
	sb := strings.builder_make()

	// Begin the switch function
	strings.write_string(&sb, strings.to_lower(enum_name))
	strings.write_string(&sb, "_indexer")
	strings.write_string(&sb, fmt.aprintf(" :: proc(tag: %s) ", enum_name))
	strings.write_string(&sb, "-> (array_index: int, bit_position: uint) {\n")
	strings.write_string(&sb, "    #partial switch tag {\n")

	// Write case for each field
	for i := 0; i < len(fields); i += 1 {
		field := fields[i]

		// Extract field name
		field_name := field.ident

		// Calculate bit position - use sequential positions for simplicity
		array_idx := i / 64
		bit_pos := i % 64

		strings.write_string(
			&sb,
			fmt.aprintf("    case .%s: return %d, %d\n", field_name, array_idx, bit_pos),
		)
	}

	// Default case
	strings.write_string(&sb, "    case:\n")
	strings.write_string(&sb, "        return 0, 0\n")
	strings.write_string(&sb, "    }\n")
	strings.write_string(&sb, "}\n")

	return strings.to_string(sb)
}
// Convert a tag string to its u32 representation
tag_to_u32 :: proc(tag: string) -> u32 {
	result: u32 = 0

	// Process up to 4 characters
	for i := 0; i < min(len(tag), 4); i += 1 {
		result = (result << 8) | u32(tag[i])
	}

	// Pad with spaces if less than 4 characters
	for i := len(tag); i < 4; i += 1 {
		result = (result << 8) | 0x20 // Space character
	}

	return result
}
