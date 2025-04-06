package ttf

import "core:os"
import "core:log"
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
		value := u32be_to_tag(extracted)
		testing.expect(t, value == tag, fmt.tprintf("expected: %v, got: %v", tag, value))
	}
}

when ODIN_OS == .Windows {

	// NOTE(lucas): these fonts have bad checksums
	FAILING_FONTS :: []string {
		"C:\\Windows\\Fonts\\corbeli.ttf",
	}

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
			if slice.contains(FAILING_FONTS, file) {
				continue
			}

			font, font_err := load_font_from_path(file, context.allocator)
			testing.expect(t, font_err == nil, file)
			destroy_font(font)
		}
		log.infof("Tested: %v fonts", len(test_files))
	}
}

