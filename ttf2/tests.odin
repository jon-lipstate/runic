package runic_ttf

import "core:os"
import "core:math/rand"
import "core:testing"
import "core:reflect"
import "core:fmt"
import "core:slice"
import "core:path/filepath"

@(test)
u32_to_tag_test :: proc(t: ^testing.T) {
	for tag in Table_Tag {
		if tag == .unknown {
			continue
		}
		as_str: string
		#partial switch tag {
		case .CFF: as_str = "CFF "
		case .cvt: as_str = "cvt "
		case .OS2: as_str = "OS/2"
		case .SVG: as_str = "SVG "
		case: as_str = reflect.enum_string(tag)
		}
		extracted := (cast(^u32be)raw_data(as_str))^
		value := ttf_u32_to_tag(extracted)
		testing.expect(t, value == tag, fmt.tprintf("expected: %v, got: %v", tag, value))
	}
}

when ODIN_OS == .Windows {
	test_gather_windows_fonts :: proc(t: ^testing.T) -> []string {
		ttf_files, ttf_err := filepath.glob("C:\\Windows\\Fonts\\*.ttf", context.temp_allocator)
		testing.expect(t, ttf_err == nil)
		otf_files, otf_err := filepath.glob("C:\\Windows\\Fonts\\*.otf", context.temp_allocator)
		testing.expect(t, otf_err == nil)

		test_files, test_err := slice.concatenate([][]string{ ttf_files, otf_files }, context.temp_allocator)
		testing.expect(t, test_err == nil)
		return test_files
	}

	@(test)
	parse_all_windows_fonts :: proc(t: ^testing.T) {
		test_files := test_gather_windows_fonts(t)
		for file, i in test_files {
			data, data_ok := os.read_entire_file(file, context.temp_allocator)
			testing.expect(t, data_ok)

			font, font_ok := font_make_from_data(data, context.allocator)
			testing.expect(t, font_ok)
			font_delete(font)
		}
	}

	@(test)
	parse_check_sum_test :: proc(t: ^testing.T) {
		test_files := test_gather_windows_fonts(t)
		for file, i in test_files {
			data, data_ok := os.read_entire_file(file, context.temp_allocator)
			testing.expect(t, data_ok)
			if len(data) <= 0 {
				continue
			}
			// NOTE(lucas): introduce an error into the file
			value := rand.int_max(len(data))
			data[value] += 1

			context.logger.lowest_level = .Warning
			_, font_ok := font_make_from_data(data, context.allocator)
			testing.expect(t, ! font_ok)
		}
	}

	@(test)
	parse_truncated_file :: proc(t: ^testing.T) {
		test_files := test_gather_windows_fonts(t)
		for file, i in test_files {
			data, data_ok := os.read_entire_file(file, context.temp_allocator)
			testing.expect(t, data_ok)
			if len(data) <= 0 {
				continue
			}
			// NOTE(lucas): introduce an error into the file
			value := rand.int_max(len(data))
			trunc_data := data[:value]

			_, font_ok := font_make_from_data(trunc_data, context.allocator, { skip_check_sum = true })
			testing.expect(t, ! font_ok)
		}
	}
}

