package runic_hinter

import "core:path/filepath"
import "core:testing"
import "core:slice"
import "core:mem"
import "core:os"
import "../ttf"

when ODIN_OS == .Windows {

	// NOTE(lucas): fix these failing fonts! They don't even pass the CVT phase!
	FAILING_FONTS :: []string {
		"C:\\Windows\\Fonts\\Inkfree.ttf",
		"C:\\Windows\\Fonts\\arial.ttf",
		"C:\\Windows\\Fonts\\arialbi.ttf",
		"C:\\Windows\\Fonts\\arialbd.ttf",
		"C:\\Windows\\Fonts\\ariali.ttf",
		"C:\\Windows\\Fonts\\comic.ttf",
		"C:\\Windows\\Fonts\\comicbd.ttf",
		"C:\\Windows\\Fonts\\consola.ttf",
		"C:\\Windows\\Fonts\\consolai.ttf",
		"C:\\Windows\\Fonts\\cour.ttf",
		"C:\\Windows\\Fonts\\courbd.ttf",
		"C:\\Windows\\Fonts\\courbi.ttf",
		"C:\\Windows\\Fonts\\couri.ttf",
		"C:\\Windows\\Fonts\\framdit.ttf",
		"C:\\Windows\\Fonts\\georgiab.ttf",
		"C:\\Windows\\Fonts\\impact.ttf",
		"C:\\Windows\\Fonts\\l_10646.ttf",
		"C:\\Windows\\Fonts\\marlett.ttf",
		"C:\\Windows\\Fonts\\palab.ttf",
		"C:\\Windows\\Fonts\\palabi.ttf",
		"C:\\Windows\\Fonts\\palai.ttf",
		"C:\\Windows\\Fonts\\symbol.ttf",
		"C:\\Windows\\Fonts\\times.ttf",
		"C:\\Windows\\Fonts\\timesbd.ttf",
		"C:\\Windows\\Fonts\\timesbi.ttf",
		"C:\\Windows\\Fonts\\timesi.ttf",
		"C:\\Windows\\Fonts\\trebuc.ttf",
		"C:\\Windows\\Fonts\\trebucbd.ttf",
		"C:\\Windows\\Fonts\\trebucbi.ttf",
		"C:\\Windows\\Fonts\\trebucit.ttf",
		"C:\\Windows\\Fonts\\webdings.ttf",
		"C:\\Windows\\Fonts\\wingding.ttf",
		"C:\\Windows\\Fonts\\SimsunExtG.ttf",
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
	create_hinter_all_windows_fonts :: proc(t: ^testing.T) {
		test_files := test_gather_windows_fonts(t)
		for file, i in test_files {
			if slice.contains(FAILING_FONTS, file) {
				continue
			}
			allocator := context.allocator
			context.allocator = mem.panic_allocator()
			font, font_err := ttf.load_font_from_path(file, allocator)
			testing.expect(t, font_err == nil, file)
			defer ttf.destroy_font(font)

			// NOTE(lucas): we are not testing hintin the actual glyphs yet
			hinter, hinter_ok := hinter_program_make(font, 11, 96, allocator)
			testing.expect(t, hinter_ok, file)

			hinter_program_hint_glyph(hinter, 0, context.temp_allocator)

			hinter_program_delete(hinter)
		}
	}
}

