package runic_ttf

import "core:os"
import "core:mem"
import "core:slice"
import "core:log"
import "base:runtime"
import "base:intrinsics"

import runic_ts "../tmp_shared"
import "../memory"

Ttf_ShortFrac :: i16be
Ttf_Fixed :: i32be
Ttf_Fword :: i16be
Ttf_uFword :: u16be
Ttf_F2Dot14 :: i16be
Ttf_longDateTime :: i64be
Ttf_u32 :: u32be
Ttf_u16 :: u16be
Ttf_i32 :: i32be
Ttf_i16 :: i16be
Ttf_Offset16 :: u16be
Ttf_Offset32 :: u16be
Ttf_Version16Dot16 :: u32be

Table_Tag :: enum {
	unknown, // NOTE(lucas): not an actual table 

	avar,
	BASE,
	CBDT,
	CBLC,
	CFF,
	CFF2,
	cmap,
	COLR,
	CPAL,
	cvar,
	cvt,
	DSIG,
	EBDT,
	EBLC,
	EBSC,
	fpgm,
	fvar,
	gasp,
	GDEF,
	glyf,
	GPOS,
	GSUB,
	gvar,
	hdmx,
	head,
	hhea,
	hmtx,
	HVAR,
	JSTF,
	kern,
	loca,
	LTSH,
	MATH,
	maxp,
	MERG,
	meta,
	MVAR,
	name,
	OS2,
	PCLT,
	post,
	prep,
	sbix,
	STAT,
	SVG,
	VDMX,
	vhea,
	vmtx,
	VORG,
	VVAR,
}

Table_Tags :: distinct bit_set[Table_Tag]
ttf_u32_to_tag :: proc(tag: u32be) -> Table_Tag {
	switch tag {
	case 0x61766172: return .avar
	case 0x42415345: return .BASE
	case 0x43424454: return .CBDT
	case 0x43424C43: return .CBLC
	case 0x43464620: return .CFF
	case 0x43464632: return .CFF2
	case 0x636D6170: return .cmap
	case 0x434F4C52: return .COLR
	case 0x4350414C: return .CPAL
	case 0x63766172: return .cvar
	case 0x63767420: return .cvt
	case 0x44534947: return .DSIG
	case 0x45424454: return .EBDT
	case 0x45424C43: return .EBLC
	case 0x45425343: return .EBSC
	case 0x6670676D: return .fpgm
	case 0x66766172: return .fvar
	case 0x67617370: return .gasp
	case 0x47444546: return .GDEF
	case 0x676C7966: return .glyf
	case 0x47504F53: return .GPOS
	case 0x47535542: return .GSUB
	case 0x67766172: return .gvar
	case 0x68646D78: return .hdmx
	case 0x68656164: return .head
	case 0x68686561: return .hhea
	case 0x686D7478: return .hmtx
	case 0x48564152: return .HVAR
	case 0x4A535446: return .JSTF
	case 0x6B65726E: return .kern
	case 0x6C6F6361: return .loca
	case 0x4C545348: return .LTSH
	case 0x4D415448: return .MATH
	case 0x6D617870: return .maxp
	case 0x4D455247: return .MERG
	case 0x6D657461: return .meta
	case 0x4D564152: return .MVAR
	case 0x6E616D65: return .name
	case 0x4F532F32: return .OS2
	case 0x50434C54: return .PCLT
	case 0x706F7374: return .post
	case 0x70726570: return .prep
	case 0x73626978: return .sbix
	case 0x53544154: return .STAT
	case 0x53564720: return .SVG
	case 0x56444D58: return .VDMX
	case 0x76686561: return .vhea
	case 0x766D7478: return .vmtx
	case 0x564F5247: return .VORG
	case 0x56564152: return .VVAR
	}
	return .unknown
}

Table_Blob :: struct {
	tag: Table_Tag,
	check_sum: u32,
	data: []byte,
	valid: bool,
}

Font :: struct {
	data: []byte,
	has_tables: Table_Tags,
	tables: [Table_Tag]Table_Blob,

	// NOTE(lucas): these are dynamically created just in time as the user requests glyphs
	glyphs: []^runic_ts.Extracted_Glyph,

	units_per_em: f32,
	hinting_data: Font_Hinting_Data,

	allocator: runtime.Allocator,
	arena: runtime.Arena,
}

Font_Hinting_Data :: struct {
	enabled: bool,
	stack_size: i32,
	storage_size: i32,
	zone_0_size: i32,
	ran_font_program: bool,
	shared_instructions: [][]byte,
}

Table_Offset :: struct #packed {
	scalar_type: Ttf_u32,
	num_tables: Ttf_u16,
	search_range: Ttf_u16,
	entry_selector: Ttf_u16,
	range_shift: Ttf_u16,
}

Table_Directory :: struct #packed {
	tag: Ttf_u32,
	check_sum: Ttf_u32,
	offset: Ttf_u32,
	length: Ttf_u32,
}

Font_Make_Options :: struct {
	debug: bool,
	skip_check_sum: bool,
	allow_duplicate_tables: bool,
	arena_size: int,
	clone_data: bool,
}

font_make_from_data :: proc(data: []byte, allocator: runtime.Allocator, options: Font_Make_Options = {}) -> (^Font, bool) {
	context.allocator = mem.panic_allocator()
	allocator := allocator
	// NOTE(lucas): we multiply the file size by 3 as an estimate of the total amount of memory used
	// during parsing, once everything is up and running we can tweak this.
	font: ^Font
	{
		arena: runtime.Arena
		arena_err := runtime.arena_init(&arena, options.arena_size <= 0 ? len(data) * 3 : uint(options.arena_size), allocator)
		if arena_err != nil {
			return {}, false
		}

		new_font, font_err := new(Font, allocator)
		if font_err != nil {
			return {}, false
		}
		font = new_font
		font.arena = arena
	}
	allocator = runtime.arena_allocator(&font.arena)
	font.allocator = allocator

	ctx: Read_Context = { ok = true }
	ok := false
	defer if ! ok {
		runtime.arena_destroy(&font.arena)
	}

	data := data
	if options.clone_data {
		data = slice.clone(data, allocator)
	}
	font.data = data

	// NOTE(lucas): ingest all tables
	{
		reader := Reader { &ctx, data, 0 }
		offset_table, _ := read_t_ptr(Table_Offset, &reader)
		table_directories, _ := read_t_slice(Table_Directory, &reader, i64(offset_table.num_tables))
		for table in table_directories {
			tag := ttf_u32_to_tag(table.tag)
			if tag == .unknown {
				continue
			}
			if ! options.allow_duplicate_tables && tag in font.has_tables {
				ctx.ok = false
				log.errorf("[Ttf parser] found duplicate table '%v'", tag)
			} else {
				table_data, table_ok := get_table_from_directory(&ctx, i64(table.offset), i64(table.length), data)
				font.has_tables += { tag }
				font.tables[tag] = { tag, u32(table.check_sum), table_data, true }
			}
		}
	}

	// NOTE(lucas): validate checksums
	if ! options.skip_check_sum {
		for tag in font.has_tables {
			if tag == .unknown {
				continue
			}

			parsed_info := font.tables[tag]
			if ! parsed_info.valid {
				ctx.ok = false
			}
			if tag == .head {
				checksum := table_check_sum(data)
				if 0xB1B0AFBA - checksum != 0 {
					log.errorf("[Ttf parser] table '%v' has a bad checksum", tag)
					ctx.ok = false
				}
			} else {
				if table_check_sum(parsed_info.data) != parsed_info.check_sum {
					log.errorf("[Ttf parser] table '%v' has a bad checksum", tag)
					ctx.ok = false
				}
			}
		}
	}

	// NOTE(lucas): parse necessary tables
	head: ^Table_Head
	maxp: ^Table_Maxp
	{
		head, _ = parse_head_table(&ctx, font.tables[.head])
		maxp, _ = parse_maxp_table(&ctx, font.tables[.maxp], allocator)
		num_glyphs := u16(maxp.num_glyphs)
		font.glyphs = make([]^runic_ts.Extracted_Glyph, num_glyphs, allocator)
		font.units_per_em = f32(u16(head.units_per_em))
	}

	{
		// NOTE(lucas): parse hinting information, the font program will be ran
		// by the first hinter program
		hinting_tables := Table_Tags { .fpgm, .cvt, .prep, .maxp }
		has_hinting := hinting_tables - font.has_tables == {}
		if has_hinting {
			font.hinting_data.enabled = true
			font.hinting_data.stack_size = i32(maxp.max_stack_elements) + 32
			font.hinting_data.storage_size = i32(maxp.max_storage)
			font.hinting_data.zone_0_size = i32(maxp.max_twilight_points)
			font.hinting_data.shared_instructions = make([][]byte, maxp.max_function_defs, allocator)
		}
	}

	ok = ctx.ok
	return ok ? font : nil, ok
}

font_delete :: proc(font: ^Font) {
	if font != nil {
		// NOTE(lucas): copy out the arena so we don't go try accessing deleted memory
		// as the arena will delete the font containing the arena
		arena := font.arena
		runtime.arena_destroy(&arena)
	}
}

get_table_from_directory :: proc(ctx: ^Read_Context, offset: i64, length: i64, data: []byte) -> ([]byte, bool) {
	i64_len := i64(len(data))
	table_start := offset
	table_end, did_overflow := intrinsics.overflow_add(offset, length)
	if offset < 0 || length < 0 || table_start > i64_len || table_end > i64_len || did_overflow {
		ctx.ok = false
		return {}, false
	}
	return data[table_start:table_end], true
}

table_check_sum :: proc(data: []byte) -> u32 {
	sum: Ttf_u32
	data_len := len(data)
	for i := 0; i < data_len; i += 4 {
		sum += (cast(^Ttf_u32)(&data[i]))^
	}
	return u32(sum)
}

