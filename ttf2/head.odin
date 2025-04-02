package runic_ttf

import "core:log"

TTF_TABLE_HEAD_MAGIC :: 0x5F0F3CF5
Table_Head :: struct #packed {
    version: Ttf_Fixed,
    font_revision: Ttf_Fixed,
    check_sum_adjustment: Ttf_u32,
    magic_number: Ttf_u32,
    flags: Ttf_u16,
    units_per_em: Ttf_u16,
    created: Ttf_longDateTime,
    modified: Ttf_longDateTime,
    x_min: Ttf_Fword,
    y_min: Ttf_Fword,
    x_max: Ttf_Fword,
    y_max: Ttf_Fword,
    mac_style: Ttf_u16,
    lowest_rec_ppem: Ttf_u16,
    font_direction_hint: Ttf_i16,
    index_to_loc_format: Ttf_i16,
    glyph_data_format: Ttf_i16,
}

parse_head_table :: proc(ctx: ^Read_Context, table: Table_Blob) -> (^Table_Head, bool) {
    @(static) _dummy: Table_Head
    result: ^Table_Head = &_dummy
    if table.valid && table.tag == .head {
        reader := Reader { ctx, table.data, 0 }
        head, _ := read_t_ptr(Table_Head, &reader)
        if head.magic_number != TTF_TABLE_HEAD_MAGIC {
            log.errorf("[Ttf parser] Bad head table magic number, got: %v, expected: %v", head.magic_number, TTF_TABLE_HEAD_MAGIC)
            ctx.ok = false
        }
        result = head
    } else {
        log.error("[Ttf parser] Bad head table")
        ctx.ok = false
    }
    return result, ctx.ok
}

