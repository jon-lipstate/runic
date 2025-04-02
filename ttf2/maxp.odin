package runic_ttf

import "base:runtime"
import "core:log"

Table_Maxp_0_Dot_5 :: struct #packed {
    version: Ttf_Fixed,
    num_glyphs: Ttf_u16,
}

Table_Maxp :: struct #packed {
    version: Ttf_Fixed,
    num_glyphs: Ttf_u16,
    max_points: Ttf_u16,
    max_contours: Ttf_u16,
    max_component_points: Ttf_u16,
    max_component_contours: Ttf_u16,
    max_zones: Ttf_u16,
    max_twilight_points: Ttf_u16,
    max_storage: Ttf_u16,
    max_function_defs: Ttf_u16,
    max_instruction_defs: Ttf_u16,
    max_stack_elements: Ttf_u16,
    max_size_of_instructions: Ttf_u16,
    max_component_elements: Ttf_u16,
    max_component_depth: Ttf_u16,
}

parse_maxp_table :: proc(ctx: ^Read_Context, table: Table_Blob, allocator: runtime.Allocator) -> (^Table_Maxp, bool) {
    @(static) _dummy: Table_Maxp
    result: ^Table_Maxp = &_dummy
    if table.valid && table.tag == .maxp {
        reader := Reader { ctx, table.data, 0 }
        reader_copy := reader
        version := read_t_copy(Ttf_Version16Dot16, &reader)
        reader = reader_copy
        switch version {
        case 0x00005000:
            dummy_table := new(Table_Maxp, allocator)
            v_0dot5_header := read_t_ptr(Table_Maxp_0_Dot_5, &reader)
            dummy_table.version = v_0dot5_header.version
            dummy_table.num_glyphs = v_0dot5_header.num_glyphs
            result = dummy_table
        case 0x00010000:
            result = read_t_ptr(Table_Maxp, &reader)
        }
    } else {
        log.error("[Ttf parser] Bad maxp table")
        ctx.ok = false
    }
    return result, ctx.ok
}

