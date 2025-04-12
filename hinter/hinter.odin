package runic_hinter

import ttf "../ttf"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:math"
import "core:slice"
import "base:runtime"
import "core:math/linalg"
import "../memory"

make_multi :: memory.make_multi
Make_Multi :: memory.Make_Multi

// NOTE(lucas): the highest precision graphics state vector in the hinter has
// 14 bits of accuracy, so anything under 1 / 16384 can be considered as 0
HINTER_EPS :: 1 / 16_384
F_DOT_P_MIN :: 1 / 16
HINTER_DEBUG_ENABLED :: false
HINTER_DEBUG_INSTRUCTIONS :: true
HINTER_DEBUG_LOG :: true
HINTER_DEBUG_STACK :: false
HINTER_TTF_SCALAR_VERSION :: 40

Ttf_Hinter_Stage :: enum u8 {
	font,
	cvt,
	glyph,
}

Ttf_Hinter_Round_State :: enum {
	to_half_grid,
	to_grid,
	to_double_grid,
	down_to_grid,
	up_to_grid,
	off,
}

Ttf_Hinter_Instruction :: enum u8 {
	// 0x00
	ins_svtca_0,
	ins_svtca_1,
	ins_spvtca_0,
	ins_spvtca_1,
	ins_sfvtca_0,
	ins_sfvtca_1,
	ins_spvtl_0,
	ins_spvtl_1,
	ins_sfvtl_0,
	ins_sfvtl_1,
	ins_spvfs,
	ins_sfvfs,
	ins_gpv,
	ins_gfv,
	ins_sfvtpv,
	ins_isect,

	// 0x10
	ins_srp0,
	ins_srp1,
	ins_srp2,
	ins_szp0,
	ins_szp1,
	ins_szp2,
	ins_szps,
	ins_sloop,
	ins_rtg,
	ins_rthg,
	ins_smd,
	ins_else,
	ins_jmpr,
	ins_scvtci,
	ins_sswci,
	ins_ssw,

	// 0x20
	ins_dup,
	ins_pop,
	ins_clear,
	ins_swap,
	ins_depth,
	ins_cindex,
	ins_mindex,
	ins_alignpts,
	_,
	ins_utp,
	ins_loopcall,
	ins_call,
	ins_fdef,
	ins_endf,
	ins_mdap_0,
	ins_mdap_1,

	// 0x30
	ins_iup_0,
	ins_iup_1,
	ins_shp_0,
	ins_shp_1,
	ins_shc_0,
	ins_shc_1,
	ins_shz_0,
	ins_shz_1,
	ins_shpix,
	ins_ip,
	ins_msirp_0,
	ins_msirp_1,
	ins_alignrp,
	ins_rtdg,
	ins_miap_0,
	ins_miap_1,

	// 0x40
	ins_npushb,
	ins_npushw,
	ins_ws,
	ins_rs,
	ins_wcvtp,
	ins_rcvt,
	ins_gc_0,
	ins_gc_1,
	ins_scfs,
	ins_md_0,
	ins_md_1,
	ins_mppem,
	ins_mps,
	ins_flipon,
	ins_flipoff,
	ins_debug,

	// 0x50
	ins_lt,
	ins_lteq,
	ins_gt,
	ins_gteq,
	ins_eq,
	ins_neq,
	ins_odd,
	ins_even,
	ins_if,
	ins_eif,
	ins_and,
	ins_or,
	ins_not,
	ins_deltap1,
	ins_sdb,
	ins_sds,

	// 0x60
	ins_add,
	ins_sub,
	ins_div,
	ins_mul,
	ins_abs,
	ins_neg,
	ins_floor,
	ins_ceiling,
	ins_round_0,
	ins_round_1,
	ins_round_2,
	ins_round_3,
	ins_nround_0,
	ins_nround_1,
	ins_nround_2,
	ins_nround_3,

	// 0x70
	ins_wcvtf,
	ins_deltap2,
	ins_deltap3,
	ins_deltac1,
	ins_deltac2,
	ins_deltac3,
	ins_sround,
	ins_s45round,
	ins_jrot,
	ins_jrof,
	ins_roff,
	_,
	ins_rutg,
	ins_rdtg,
	ins_sangw,
	ins_aa,

	// 0x80
	ins_flippt,
	ins_fliprgon,
	ins_fliprgoff,
	_,
	_,
	ins_scanctrl,
	ins_sdpvtl_0,
	ins_sdpvtl_1,
	ins_getinfo,
	ins_idef,
	ins_roll,
	ins_max,
	ins_min,
	ins_scantype,
	ins_instctrl,
	_,

	// 0x90
	_,
	ins_getvar,
	ins_getdata,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,

	// 0xA0
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	_,

	// 0xB0
	ins_pushb_0,
	ins_pushb_1,
	ins_pushb_2,
	ins_pushb_3,
	ins_pushb_4,
	ins_pushb_5,
	ins_pushb_6,
	ins_pushb_7,
	ins_pushw_0,
	ins_pushw_1,
	ins_pushw_2,
	ins_pushw_3,
	ins_pushw_4,
	ins_pushw_5,
	ins_pushw_6,
	ins_pushw_7,

	// 0xC0
	ins_mdrp_00,
	ins_mdrp_01,
	ins_mdrp_02,
	ins_mdrp_03,
	ins_mdrp_04,
	ins_mdrp_05,
	ins_mdrp_06,
	ins_mdrp_07,
	ins_mdrp_08,
	ins_mdrp_09,
	ins_mdrp_10,
	ins_mdrp_11,
	ins_mdrp_12,
	ins_mdrp_13,
	ins_mdrp_14,
	ins_mdrp_15,

	// 0xD0
	ins_mdrp_16,
	ins_mdrp_17,
	ins_mdrp_18,
	ins_mdrp_19,
	ins_mdrp_20,
	ins_mdrp_21,
	ins_mdrp_22,
	ins_mdrp_23,
	ins_mdrp_24,
	ins_mdrp_25,
	ins_mdrp_26,
	ins_mdrp_27,
	ins_mdrp_28,
	ins_mdrp_29,
	ins_mdrp_30,
	ins_mdrp_31,

	// 0xE0
	ins_mirp_00,
	ins_mirp_01,
	ins_mirp_02,
	ins_mirp_03,
	ins_mirp_04,
	ins_mirp_05,
	ins_mirp_06,
	ins_mirp_07,
	ins_mirp_08,
	ins_mirp_09,
	ins_mirp_10,
	ins_mirp_11,
	ins_mirp_12,
	ins_mirp_13,
	ins_mirp_14,
	ins_mirp_15,

	// 0xF0
	ins_mirp_16,
	ins_mirp_17,
	ins_mirp_18,
	ins_mirp_19,
	ins_mirp_20,
	ins_mirp_21,
	ins_mirp_22,
	ins_mirp_23,
	ins_mirp_24,
	ins_mirp_25,
	ins_mirp_26,
	ins_mirp_27,
	ins_mirp_28,
	ins_mirp_29,
	ins_mirp_30,
	ins_mirp_31,
}

// NOTE(lucas): negative length means variable sized
@(rodata)
TTF_HINTER_INSTRUCTION_LEN := [256]i8 {
	1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,
	1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,
	1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,
	1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,

   -1,-2, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,
	1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,
	1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,
	1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,

	1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,
	1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,
	1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,
	2, 3, 4, 5,  6, 7, 8, 9,  3, 5, 7, 9, 11,13,15,17,

	1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,
	1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,
	1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,
	1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,
}

Hinter_Program_Ttf_Graphics_State :: struct {
	rp0: u32,
	rp1: u32,
	rp2: u32,

	dual_vector: [2]f32,
	proj_vector: [2]f32,
	free_vector: [2]f32,

	loop: i32,
	min_distance: f32,
	round_state: Ttf_Hinter_Round_State,

	auto_flip: bool,

	control_value_cutin: f32,
	single_width_cutin: f32,
	single_width_value: f32,
	delta_base: u16,
	delta_shift: u32,

	instruct_control: u8,

	scan_control: bool,
	scan_type: i32,

	gep0: u16,
	gep1: u16,
	gep2: u16,

	is_rotated: bool,
	is_stretched: bool,
	is_subpixel_rendering: bool,
}

HINTER_PROGRAM_TTF_GRAPHICS_STATE_DEFAULT :: Hinter_Program_Ttf_Graphics_State {
	rp0 = 0,
	rp1 = 0,
	rp2 = 0,

	dual_vector = { 1, 0 },
	proj_vector = { 1, 0 },
	free_vector = { 1, 0 },

	loop = 1,
	min_distance = 1,
	round_state = .to_grid,

	auto_flip = true,

	control_value_cutin = 17.0/16.0,
	single_width_cutin = 0,
	single_width_value = 0,
	delta_base = 9,
	delta_shift = 3,

	instruct_control = 0,

	scan_control = false,
	scan_type = 0,

	gep0 = 1,
	gep1 = 1,
	gep2 = 1,

	is_rotated = false,
	is_stretched = false,
	is_subpixel_rendering = true,
}

TTF_HINTER_TOUCH_X :: u8(1)
TTF_HINTER_TOUCH_Y :: u8(2)
TTF_HINTER_TOUCH_XY :: u8(3)

Hinter_Program_Ttf_Instructions :: struct {
	data: []byte,
	offset: int,
}

Hinter_Program_Ttf_Stack :: struct {
	data: []i32,
	count: int,
}

Hinter_Font_Wide_Data :: struct {
	stack_size: i32,
	storage_size: i32,
	zone_0_size: i32,
	shared_instructions: [][]byte,
	bad_font_program: bool,
}

Hinter_Program :: struct {
	font: ^ttf.Font,
	zone0: Hinter_Program_Ttf_Zone,
	zone1: Hinter_Program_Ttf_Zone,
	ppem: u32,
	point_size: f32,
	funits_to_pixels_scale: f32,
	cvt: []f32,
	storage: []i32,
	shared_intructions: [][]byte,
	stack_data: []i32,
	clear_type_enabled: bool,

	base_ptr: rawptr,
	allocator: runtime.Allocator,
}

Hinter_Program_Ttf_Zone :: struct {
	cur: [][2]f32,
	orig: [][2]f32,
	orig_scaled: [][2]f32,
	touch: []u8,
	end_points: []u32,
}

Hinter_Program_Execution_Context :: struct {
	program: ^Hinter_Program,
	stack: Hinter_Program_Ttf_Stack,
	is_compound_glyph: bool,
	instructions: Hinter_Program_Ttf_Instructions,
	gs: Hinter_Program_Ttf_Graphics_State,
	zp0: ^Hinter_Program_Ttf_Zone,
	zp1: ^Hinter_Program_Ttf_Zone,
	zp2: ^Hinter_Program_Ttf_Zone,
	proc_project: proc(ctx: ^Hinter_Program_Execution_Context, d: [2]i32) -> i32,
	proc_dual_project: proc(ctx: ^Hinter_Program_Execution_Context, d: [2]i32) -> i32,
	instruction_count: i64,
	storage: []i32,
	ins: Ttf_Hinter_Instruction,
	stage: Ttf_Hinter_Stage,
	iup_state: u8,
	debug: bool,
	started: bool,
	error: bool,
}

@(cold)
hinter_program_error :: proc(ctx: ^Hinter_Program_Execution_Context, msg: string) {
	if ! ctx.error {
		ctx.error = true
		log.errorf("[Ttf Hinter] An error occured during hinting: %v", msg)
	}
}

@(disabled=! HINTER_DEBUG_ENABLED || ! HINTER_DEBUG_INSTRUCTIONS)
hinter_program_ttf_debug_instruction :: proc(ctx: ^Hinter_Program_Execution_Context, ins: Ttf_Hinter_Instruction) {
	if ctx.debug {
		log.debugf("%v) %v", ctx.instruction_count, ins)
	}
}

@(disabled=! HINTER_DEBUG_ENABLED || ! HINTER_DEBUG_LOG)
hinter_program_ttf_debug_log :: proc(ctx: ^Hinter_Program_Execution_Context, fmt: string, args: ..any) {
	if ctx.debug {
		log.debugf(fmt, ..args)
	}
}

@(disabled=! HINTER_DEBUG_ENABLED || ! HINTER_DEBUG_STACK)
hinter_program_ttf_debug_stack_push :: proc(ctx: ^Hinter_Program_Execution_Context, val: i32) {
	if ctx.debug {
		log.debugf("	stack push: %v [%v]", val, ctx.stack.count)
	}
}

@(disabled=! HINTER_DEBUG_ENABLED || ! HINTER_DEBUG_STACK)
hinter_program_ttf_debug_stack_pop :: proc(ctx: ^Hinter_Program_Execution_Context, val: i32) {
	if ctx.debug {
		log.debugf("	stack pop: %v [%v]", val, ctx.stack.count)
	}
}

hinter_program_ttf_instructions_has_next :: proc(ctx: ^Hinter_Program_Execution_Context) -> bool {
	return ctx.instructions.offset < len(ctx.instructions.data)
}

hinter_program_ttf_instructions_jump :: proc(ctx: ^Hinter_Program_Execution_Context, offset: i32) {
	new_offset := ctx.instructions.offset + int(offset)
	if new_offset < 0 || new_offset >= len(ctx.instructions.data) {
		hinter_program_error(ctx, "Jump OOB")
		return
	}
	ctx.instructions.offset = new_offset
}

hinter_program_ttf_add_cvt :: proc(ctx: ^Hinter_Program_Execution_Context, idx: u32, val: f32) #no_bounds_check {
	if i64(idx) >= i64(len(ctx.program.cvt)) {
		hinter_program_error(ctx, "cvt OOB write")
	}
	if ctx.error {
		return
	}
	ctx.program.cvt[idx] += val
	hinter_program_ttf_debug_log(ctx, "    cvt: %v [%v]", ctx.program.cvt[idx], val)
}

hinter_program_ttf_set_cvt :: proc(ctx: ^Hinter_Program_Execution_Context, idx: u32, val: f32) #no_bounds_check{
	if i64(idx) >= i64(len(ctx.program.cvt)) {
		hinter_program_error(ctx, "cvt OOB write")
	}
	if ctx.error {
		return
	}
	ctx.program.cvt[idx] = val
	hinter_program_ttf_debug_log(ctx, "    cvt: %v [%v]", val, idx)
}

hinter_program_ttf_get_cvt :: proc(ctx: ^Hinter_Program_Execution_Context, idx: u32) -> f32 #no_bounds_check {
	if i64(idx) >= i64(len(ctx.program.cvt)) {
		hinter_program_error(ctx, "cvt OOB read")
	}
	if ctx.error {
		return 0
	}
	return ctx.program.cvt[idx]
}

hinter_program_ttf_get_storage :: proc(ctx: ^Hinter_Program_Execution_Context, idx: u32) -> i32 #no_bounds_check {
	if i64(idx) >= i64(len(ctx.storage)) {
		hinter_program_error(ctx, "storage OOB read")
	}
	if ctx.error {
		return 0
	}
	return ctx.program.storage[idx]
}

hinter_program_ttf_set_storage :: proc(ctx: ^Hinter_Program_Execution_Context, idx: u32, val: i32) #no_bounds_check {
	if i64(idx) >= i64(len(ctx.storage)) {
		hinter_program_error(ctx, "storage OOB write")
	}
	if ctx.error {
		return
	}
	ctx.program.storage[idx] = val
	hinter_program_ttf_debug_log(ctx, "    storage: %v [%v]", val, idx)
}

hinter_program_ttf_zp_bounds_check :: proc(ctx: ^Hinter_Program_Execution_Context, points: []$T, idx: u32) {
	if i64(idx) >= i64(len(points)) {
		hinter_program_error(ctx, "zp OOB read")
	}
}

hinter_program_ttf_get_zp :: proc(ctx: ^Hinter_Program_Execution_Context, points: []$T, idx: u32) -> T #no_bounds_check {
	hinter_program_ttf_zp_bounds_check(ctx, points, idx)
	if ctx.error {
		return {}
	}
	return points[idx]
}

hinter_program_ttf_set_zp :: proc(ctx: ^Hinter_Program_Execution_Context, points: []$T, idx: u32, res: T) #no_bounds_check {
	hinter_program_ttf_zp_bounds_check(ctx, points, idx)
	if ! ctx.error {
		points[idx] = res
	}
}

hinter_program_ttf_add_zp :: proc(ctx: ^Hinter_Program_Execution_Context, points: []$T, idx: u32, res: T) #no_bounds_check {
	hinter_program_ttf_zp_bounds_check(ctx, points, idx)
	if ! ctx.error {
		points[idx] += res
	}
}

hinter_program_ttf_or_zp :: proc(ctx: ^Hinter_Program_Execution_Context, points: []$T, idx: u32, res: T) #no_bounds_check {
	hinter_program_ttf_zp_bounds_check(ctx, points, idx)
	if ! ctx.error {
		points[idx] |= res
	}
}

hinter_program_ttf_and_zp :: proc(ctx: ^Hinter_Program_Execution_Context, points: []$T, idx: u32, res: T) #no_bounds_check {
	hinter_program_ttf_zp_bounds_check(ctx, points, idx)
	if ! ctx.error {
		points[idx] |= res
	}
}

hinter_program_interpolate :: proc(ctx: ^Hinter_Program_Execution_Context, axis: int, start_point_idx: u32, end_point_idx: u32, touch_0: u32, touch_1: u32) {
	max_points := u32(len(ctx.program.zone1.cur))
	if touch_0 >= max_points || touch_1 >= max_points || end_point_idx >= max_points {
		return
	}

	for i := start_point_idx; i <= end_point_idx; i += 1 {
		total_dist_cur := ctx.program.zone1.cur[touch_1][axis] - ctx.program.zone1.cur[touch_0][axis]
		total_dist_org := (ctx.program.zone1.orig[touch_1][axis] - ctx.program.zone1.orig[touch_0][axis])
		orig_dist	   := ctx.program.zone1.orig[i][axis] - ctx.program.zone1.orig[touch_0][axis]
		scale: f32
		if abs(total_dist_org) != 0 {
			scale = total_dist_cur / total_dist_org
		}
		old := ctx.program.zone1.cur[i][axis]
		touch_0_c := ctx.program.zone1.cur[touch_0][axis]
		ctx.program.zone1.cur[i][axis] = ctx.program.zone1.cur[touch_0][axis] + (scale * orig_dist)
		hinter_program_ttf_debug_log(ctx, "    ---- interp: index = %v axis = %v touch_0: %v touch_1: %v", i, axis, touch_0, touch_1)
		hinter_program_ttf_debug_log(ctx, "    moved to: %v ", ctx.program.zone1.cur[i][axis])
		hinter_program_ttf_debug_log(ctx, "    moved from: %v ", old)
		hinter_program_ttf_debug_log(ctx, "    delta was: %v ", scale * orig_dist)
		hinter_program_ttf_debug_log(ctx, "    touch 0 was: %v [%v]", touch_0_c, touch_0)
	}
}

hinter_program_shift :: proc(ctx: ^Hinter_Program_Execution_Context, axis: int, start_point_idx: u32, end_point_idx: u32, touch_0: u32) {
	max_points := u32(len(ctx.program.zone1.cur))
	if touch_0 >= max_points || end_point_idx >= max_points {
		return
	}
	for i := start_point_idx; i <= end_point_idx; i += 1 {
		/*
		diff_0 := abs(ctx.program.zone1.orig[touch_0][axis] - ctx.program.zone1.orig[i][axis])
		diff_1 := abs(ctx.program.zone1.orig[touch_1][axis] - ctx.program.zone1.orig[i][axis])
		touch := diff_0 < diff_1 ? touch_0 : touch_1
		diff := ctx.program.zone1.cur[touch][axis] - ctx.program.zone1.orig_scaled[touch][axis]
		ctx.program.zone1.cur[i][axis] += diff
		hinter_program_ttf_debug_log(ctx, "    ---- shift: %v %v %v", i, axis, ctx.program.zone1.cur[i][axis])
		*/
	}
}


hinter_program_interpolate_or_shift :: proc(ctx: ^Hinter_Program_Execution_Context, axis: int, start_point_idx: u32, end_point_idx: u32, touch_0: u32, touch_1: u32) {
	iup_interpolate :: proc(ctx: ^Hinter_Program_Execution_Context, axis: int, i: u32, touch_0: u32, touch_1: u32) {
		total_dist_cur := ctx.program.zone1.cur[touch_1][axis] - ctx.program.zone1.cur[touch_0][axis]
		total_dist_org := (ctx.program.zone1.orig[touch_1][axis] - ctx.program.zone1.orig[touch_0][axis])
		orig_dist	   := ctx.program.zone1.orig[i][axis] - ctx.program.zone1.orig[touch_0][axis]
		scale: f32
		if abs(total_dist_org) != 0 {
			scale = total_dist_cur / total_dist_org
		}
		ctx.program.zone1.cur[i][axis] = ctx.program.zone1.cur[touch_0][axis] + (scale * orig_dist)
		hinter_program_ttf_debug_log(ctx, "    ---- interp: index = %v axis = %v touch_0: %v touch_1: %v", i, axis, touch_0, touch_1)
		/*
		*/
	}

	iup_shift :: proc(ctx: ^Hinter_Program_Execution_Context, axis: int, i: u32, touch_0: u32, touch_1: u32) {
		diff_0 := abs(ctx.program.zone1.orig[touch_0][axis] - ctx.program.zone1.orig[i][axis])
		diff_1 := abs(ctx.program.zone1.orig[touch_1][axis] - ctx.program.zone1.orig[i][axis])
		touch := diff_0 < diff_1 ? touch_0 : touch_1
		diff := ctx.program.zone1.cur[touch][axis] - ctx.program.zone1.orig_scaled[touch][axis]
		ctx.program.zone1.cur[i][axis] += diff
		hinter_program_ttf_debug_log(ctx, "    ---- shift: %v %v %v", i, axis, ctx.program.zone1.cur[i][axis])
	}

	iup_interpolate_or_shift :: proc(ctx: ^Hinter_Program_Execution_Context, axis: int, coord_0, coord_1: f32, i: u32, touch_0: u32, touch_1: u32) {
		if (coord_0 <= ctx.program.zone1.orig[i][axis] && ctx.program.zone1.orig[i][axis] <= coord_1) {
			iup_interpolate(ctx, axis, i, touch_0, touch_1)
		} else {
			iup_shift(ctx, axis, i, touch_0, touch_1)
		}
	}


	coord0, coord1: f32
	max_min :: proc(a, b: f32) -> (f32, f32) {
		return a, b if a > b else b, a
	}
	coord1, coord0 = max_min(ctx.program.zone1.orig[touch_0][axis], ctx.program.zone1.orig[touch_1][axis])

	if (touch_0 >= touch_1) {
		for i := touch_0 + 1; i <= end_point_idx; i += 1 {
			iup_interpolate_or_shift(ctx, axis, coord0, coord1, i, touch_0, touch_1)
		}

		for i := start_point_idx; i < touch_1; i += 1 {
			iup_interpolate_or_shift(ctx, axis, coord0, coord1, i, touch_0, touch_1)
		} 
	} else {
		for i := touch_0 + 1; i < touch_1; i += 1 {
			iup_interpolate_or_shift(ctx, axis, coord0, coord1, i, touch_0, touch_1)
		}
	}
}

hinter_program_ttf_stack_pop :: proc(ctx: ^Hinter_Program_Execution_Context, $N: int) -> [N]i32 {
	if ctx.stack.count < N {
		hinter_program_error(ctx, "Stack underflow")
	}
	if ctx.error {
		return {}
	}
	result: [N]i32
	for i in 0..<N {
		ctx.stack.count -= 1
		result[i] = ctx.stack.data[ctx.stack.count]
		hinter_program_ttf_debug_stack_pop(ctx, result[i])
	}
	return result
}

hinter_program_ttf_stack_push :: proc(ctx: ^Hinter_Program_Execution_Context, values: [$N]i32) {
	if ctx.stack.count + N > len(ctx.stack.data) {
		hinter_program_error(ctx, "Stack overflow")
	}
	if ctx.error {
		return
	}
	for i in 0..<N {
		ctx.stack.data[ctx.stack.count] = values[i]
		hinter_program_ttf_debug_stack_push(ctx, values[i])
		ctx.stack.count += 1
	}
}

hinter_program_ttf_instructions_next :: proc(ctx: ^Hinter_Program_Execution_Context) -> Ttf_Hinter_Instruction {
	if ! hinter_program_ttf_instructions_has_next(ctx) {
		hinter_program_error(ctx, "Instruction OOB read")
	}
	if ctx.error {
		return Ttf_Hinter_Instruction(0x28)
	}
	value := ctx.instructions.data[ctx.instructions.offset]
	ctx.instructions.offset += 1
	return Ttf_Hinter_Instruction(value)
}

hinter_program_ttf_instructions_ptr_next :: proc(ctx: ^Hinter_Program_Execution_Context) -> ^byte {
	if ! hinter_program_ttf_instructions_has_next(ctx) {
		hinter_program_error(ctx, "Instruction OOB read")
	}
	if ctx.error {
		return nil
	}
	value := &ctx.instructions.data[ctx.instructions.offset]
	ctx.instructions.offset += 1
	return value
}

hinter_program_ttf_normalize :: proc(v: [2]i32, r: [2]i32) -> [2]i32 {
	v := v
	if v == {} {
		return r
	}

	norm := [2]f32 { f32(v.x) / 64, f32(v.y) / 64 }
	norm = linalg.vector_normalize(norm) * 64

	return [2]i32 { i32(norm.x) / 4, i32(norm.y) / 4 }
}

hinter_program_ttf_execute :: proc(ctx: ^Hinter_Program_Execution_Context) -> bool {
	if ! ctx.started {
		ctx.started = true
		hinter_program_ttf_debug_log(ctx, "--- executing %v hinter program ---", ctx.stage)
	}

	for ! ctx.error && hinter_program_ttf_instructions_has_next(ctx) {
		ins := hinter_program_ttf_instructions_next(ctx)
		assert(! ctx.error) // should not fail
		hinter_program_ttf_debug_instruction(ctx, ins)
		ctx.instruction_count += 1

		ctx.iup_state = 0

		ctx.ins = ins
		switch ins {
		case .ins_svtca_0: fallthrough
		case .ins_svtca_1: fallthrough
		case .ins_spvtca_0: fallthrough
		case .ins_spvtca_1: fallthrough
		case .ins_sfvtca_0: fallthrough
		case .ins_sfvtca_1:
			hinter_program_ttf_ins_sxytca(ctx)

		case .ins_spvtl_0: fallthrough
		case .ins_spvtl_1:
			hinter_program_ttf_ins_spvtl(ctx)

		case .ins_sfvtl_0: fallthrough
		case .ins_sfvtl_1:
			hinter_program_ttf_ins_sfvtl(ctx)

		case .ins_spvfs:
			hinter_program_ttf_ins_spvfs(ctx)

		case .ins_sfvfs:
			hinter_program_ttf_ins_sfvfs(ctx)

		case .ins_gpv:
			hinter_program_ttf_ins_gpv(ctx)

		case .ins_gfv:
			hinter_program_ttf_ins_gfv(ctx)

		case .ins_sfvtpv:
			hinter_program_ttf_ins_sfvtpv(ctx)

		case .ins_isect:
			hinter_program_ttf_ins_isect(ctx)

		case .ins_srp0:
			hinter_program_ttf_ins_srp0(ctx)

		case .ins_srp1:
			hinter_program_ttf_ins_srp1(ctx)

		case .ins_srp2:
			hinter_program_ttf_ins_srp2(ctx)

		case .ins_szp0:
			hinter_program_ttf_ins_szp0(ctx)

		case .ins_szp1:
			hinter_program_ttf_ins_szp1(ctx)

		case .ins_szp2:
			hinter_program_ttf_ins_szp2(ctx)

		case .ins_szps:
			hinter_program_ttf_ins_szps(ctx)

		case .ins_sloop:
			hinter_program_ttf_ins_sloop(ctx)

		case .ins_rtg:
			hinter_program_ttf_ins_rtg(ctx)

		case .ins_rthg:
			hinter_program_ttf_ins_rthg(ctx)

		case .ins_smd:
			hinter_program_ttf_ins_smd(ctx)

		case .ins_else:
			hinter_program_ttf_ins_else(ctx)

		case .ins_jmpr:
			hinter_program_ttf_ins_jmpr(ctx)

		case .ins_scvtci:
			hinter_program_ttf_ins_scvtci(ctx)

		case .ins_sswci:
			hinter_program_ttf_ins_sswci(ctx)

		case .ins_ssw:
			hinter_program_ttf_ins_ssw(ctx)

		case .ins_dup:
			hinter_program_ttf_ins_dup(ctx)

		case .ins_pop:
			hinter_program_ttf_ins_pop(ctx)

		case .ins_clear:
			hinter_program_ttf_ins_clear(ctx)

		case .ins_swap:
			hinter_program_ttf_ins_swap(ctx)

		case .ins_depth:
			hinter_program_ttf_ins_depth(ctx)

		case .ins_cindex:
			hinter_program_ttf_ins_cindex(ctx)

		case .ins_mindex:
			hinter_program_ttf_ins_mindex(ctx)

		case .ins_alignpts:
			hinter_program_ttf_ins_alignpts(ctx)

		case .ins_utp:
			hinter_program_ttf_ins_utp(ctx)

		case .ins_loopcall:
			hinter_program_ttf_ins_loopcall(ctx)

		case .ins_call:
			hinter_program_ttf_ins_call(ctx)

		case .ins_fdef:
			hinter_program_ttf_ins_fdef(ctx)

		case .ins_endf:
			hinter_program_ttf_ins_endf(ctx)

		case .ins_mdap_0: fallthrough
		case .ins_mdap_1:
			hinter_program_ttf_ins_mdap(ctx)

		case .ins_iup_0: fallthrough
		case .ins_iup_1:
			hinter_program_ttf_ins_iup(ctx)

		case .ins_shp_0: fallthrough
		case .ins_shp_1:
			hinter_program_ttf_ins_shp(ctx)

		case .ins_shc_0: fallthrough
		case .ins_shc_1:
			hinter_program_ttf_ins_shc(ctx)

		case .ins_shz_0: fallthrough
		case .ins_shz_1:
			hinter_program_ttf_ins_shz(ctx)

		case .ins_shpix:
			hinter_program_ttf_ins_shpix(ctx)

		case .ins_ip:
			hinter_program_ttf_ins_ip(ctx)

		case .ins_msirp_0: fallthrough
		case .ins_msirp_1:
			hinter_program_ttf_ins_msirp(ctx)

		case .ins_alignrp:
			hinter_program_ttf_ins_alignrp(ctx)

		case .ins_rtdg:
			hinter_program_ttf_ins_rtdg(ctx)

		case .ins_miap_0: fallthrough
		case .ins_miap_1:
			hinter_program_ttf_ins_miap(ctx)

		case .ins_npushb:
			hinter_program_ttf_ins_npushb(ctx)

		case .ins_npushw:
			hinter_program_ttf_ins_npushw(ctx)

		case .ins_ws:
			hinter_program_ttf_ins_ws(ctx)

		case .ins_rs:
			hinter_program_ttf_ins_rs(ctx)

		case .ins_wcvtp:
			hinter_program_ttf_ins_wcvtp(ctx)

		case .ins_rcvt:
			hinter_program_ttf_ins_rcvt(ctx)

		case .ins_gc_0: fallthrough
		case .ins_gc_1:
			hinter_program_ttf_ins_gc(ctx)

		case .ins_scfs:
			hinter_program_ttf_ins_scfs(ctx)

		case .ins_md_0: fallthrough
		case .ins_md_1:
			hinter_program_ttf_ins_md(ctx)

		case .ins_mppem:
			hinter_program_ttf_ins_mppem(ctx)

		case .ins_mps:
			hinter_program_ttf_ins_mps(ctx)

		case .ins_flipon:
			hinter_program_ttf_ins_flipon(ctx)

		case .ins_flipoff:
			hinter_program_ttf_ins_flipoff(ctx)

		case .ins_debug:
			hinter_program_ttf_ins_debug(ctx)

		case .ins_lt:
			hinter_program_ttf_ins_lt(ctx)

		case .ins_lteq:
			hinter_program_ttf_ins_lteq(ctx)

		case .ins_gt:
			hinter_program_ttf_ins_gt(ctx)

		case .ins_gteq:
			hinter_program_ttf_ins_gteq(ctx)

		case .ins_eq:
			hinter_program_ttf_ins_eq(ctx)

		case .ins_neq:
			hinter_program_ttf_ins_neq(ctx)

		case .ins_odd:
			hinter_program_ttf_ins_odd(ctx)

		case .ins_even:
			hinter_program_ttf_ins_even(ctx)

		case .ins_if:
			hinter_program_ttf_ins_if(ctx)

		case .ins_eif:
			hinter_program_ttf_ins_eif(ctx)

		case .ins_and:
			hinter_program_ttf_ins_and(ctx)

		case .ins_or:
			hinter_program_ttf_ins_or(ctx)

		case .ins_not:
			hinter_program_ttf_ins_not(ctx)

		case .ins_sdb:
			hinter_program_ttf_ins_sdb(ctx)

		case .ins_sds:
			hinter_program_ttf_ins_sds(ctx)

		case .ins_add:
			hinter_program_ttf_ins_add(ctx)

		case .ins_sub:
			hinter_program_ttf_ins_sub(ctx)

		case .ins_div:
			hinter_program_ttf_ins_div(ctx)

		case .ins_mul:
			hinter_program_ttf_ins_mul(ctx)

		case .ins_abs:
			hinter_program_ttf_ins_abs(ctx)

		case .ins_neg:
			hinter_program_ttf_ins_neg(ctx)

		case .ins_floor:
			hinter_program_ttf_ins_floor(ctx)

		case .ins_ceiling:
			hinter_program_ttf_ins_ceiling(ctx)

		case .ins_round_0: fallthrough
		case .ins_round_1: fallthrough
		case .ins_round_2: fallthrough
		case .ins_round_3:
			hinter_program_ttf_ins_round(ctx)

		case .ins_nround_0: fallthrough
		case .ins_nround_1: fallthrough
		case .ins_nround_2: fallthrough
		case .ins_nround_3:
			hinter_program_ttf_ins_nround(ctx)

		case .ins_wcvtf:
			hinter_program_ttf_ins_wcvtf(ctx)

		case .ins_deltap1: fallthrough
		case .ins_deltap2: fallthrough
		case .ins_deltap3:
			hinter_program_ttf_ins_deltap(ctx)

		case .ins_deltac1: fallthrough
		case .ins_deltac2: fallthrough
		case .ins_deltac3:
			hinter_program_ttf_ins_deltac(ctx)

		case .ins_sround:
			hinter_program_ttf_ins_sround(ctx)

		case .ins_s45round:
			hinter_program_ttf_ins_s45round(ctx)

		case .ins_jrot:
			hinter_program_ttf_ins_jrot(ctx)

		case .ins_jrof:
			hinter_program_ttf_ins_jrof(ctx)

		case .ins_roff:
			hinter_program_ttf_ins_roff(ctx)

		case .ins_rutg:
			hinter_program_ttf_ins_rutg(ctx)

		case .ins_rdtg:
			hinter_program_ttf_ins_rdtg(ctx)

		case .ins_sangw:
			hinter_program_ttf_ins_sangw(ctx)

		case .ins_aa:
			hinter_program_ttf_ins_aa(ctx)

		case .ins_flippt:
			hinter_program_ttf_ins_flippt(ctx)

		case .ins_fliprgon:
			hinter_program_ttf_ins_fliprgon(ctx)

		case .ins_fliprgoff:
			hinter_program_ttf_ins_fliprgoff(ctx)

		case .ins_scanctrl:
			hinter_program_ttf_ins_scanctrl(ctx)

		case .ins_sdpvtl_0: fallthrough
		case .ins_sdpvtl_1:
			hinter_program_ttf_ins_sdpvtl(ctx)

		case .ins_getinfo:
			hinter_program_ttf_ins_getinfo(ctx)

		case .ins_idef:
			hinter_program_ttf_ins_idef(ctx)

		case .ins_roll:
			hinter_program_ttf_ins_roll(ctx)

		case .ins_max:
			hinter_program_ttf_ins_max(ctx)

		case .ins_min:
			hinter_program_ttf_ins_min(ctx)

		case .ins_scantype:
			hinter_program_ttf_ins_scantype(ctx)

		case .ins_instctrl:
			hinter_program_ttf_ins_instctrl(ctx)

		case .ins_getvar:
			hinter_program_ttf_ins_getvar(ctx)

		case .ins_getdata:
			hinter_program_ttf_ins_getdata(ctx)

		case .ins_pushb_0: fallthrough
		case .ins_pushb_1: fallthrough
		case .ins_pushb_2: fallthrough
		case .ins_pushb_3: fallthrough
		case .ins_pushb_4: fallthrough
		case .ins_pushb_5: fallthrough
		case .ins_pushb_6: fallthrough
		case .ins_pushb_7:
			hinter_program_ttf_ins_pushb(ctx)

		case .ins_pushw_0: fallthrough
		case .ins_pushw_1: fallthrough
		case .ins_pushw_2: fallthrough
		case .ins_pushw_3: fallthrough
		case .ins_pushw_4: fallthrough
		case .ins_pushw_5: fallthrough
		case .ins_pushw_6: fallthrough
		case .ins_pushw_7:
			hinter_program_ttf_ins_pushw(ctx)

		case .ins_mdrp_00: fallthrough
		case .ins_mdrp_01: fallthrough
		case .ins_mdrp_02: fallthrough
		case .ins_mdrp_03: fallthrough
		case .ins_mdrp_04: fallthrough
		case .ins_mdrp_05: fallthrough
		case .ins_mdrp_06: fallthrough
		case .ins_mdrp_07: fallthrough
		case .ins_mdrp_08: fallthrough
		case .ins_mdrp_09: fallthrough
		case .ins_mdrp_10: fallthrough
		case .ins_mdrp_11: fallthrough
		case .ins_mdrp_12: fallthrough
		case .ins_mdrp_13: fallthrough
		case .ins_mdrp_14: fallthrough
		case .ins_mdrp_15: fallthrough
		case .ins_mdrp_16: fallthrough
		case .ins_mdrp_17: fallthrough
		case .ins_mdrp_18: fallthrough
		case .ins_mdrp_19: fallthrough
		case .ins_mdrp_20: fallthrough
		case .ins_mdrp_21: fallthrough
		case .ins_mdrp_22: fallthrough
		case .ins_mdrp_23: fallthrough
		case .ins_mdrp_24: fallthrough
		case .ins_mdrp_25: fallthrough
		case .ins_mdrp_26: fallthrough
		case .ins_mdrp_27: fallthrough
		case .ins_mdrp_28: fallthrough
		case .ins_mdrp_29: fallthrough
		case .ins_mdrp_30: fallthrough
		case .ins_mdrp_31:
			hinter_program_ttf_ins_mdrp(ctx)

		case .ins_mirp_00: fallthrough
		case .ins_mirp_01: fallthrough
		case .ins_mirp_02: fallthrough
		case .ins_mirp_03: fallthrough
		case .ins_mirp_04: fallthrough
		case .ins_mirp_05: fallthrough
		case .ins_mirp_06: fallthrough
		case .ins_mirp_07: fallthrough
		case .ins_mirp_08: fallthrough
		case .ins_mirp_09: fallthrough
		case .ins_mirp_10: fallthrough
		case .ins_mirp_11: fallthrough
		case .ins_mirp_12: fallthrough
		case .ins_mirp_13: fallthrough
		case .ins_mirp_14: fallthrough
		case .ins_mirp_15: fallthrough
		case .ins_mirp_16: fallthrough
		case .ins_mirp_17: fallthrough
		case .ins_mirp_18: fallthrough
		case .ins_mirp_19: fallthrough
		case .ins_mirp_20: fallthrough
		case .ins_mirp_21: fallthrough
		case .ins_mirp_22: fallthrough
		case .ins_mirp_23: fallthrough
		case .ins_mirp_24: fallthrough
		case .ins_mirp_25: fallthrough
		case .ins_mirp_26: fallthrough
		case .ins_mirp_27: fallthrough
		case .ins_mirp_28: fallthrough
		case .ins_mirp_29: fallthrough
		case .ins_mirp_30: fallthrough
		case .ins_mirp_31:
			hinter_program_ttf_ins_mirp(ctx)

		case:
			hinter_program_error(ctx, "Illegal instruction")
		}
	}

	return ! ctx.error
}

hinter_program_f2dot14_to_f32 :: #force_inline proc(f2_dot_14: i16) -> f32 {
	return f32(f2_dot_14) / 16_384
}

hinter_program_f32_to_f2dot14 :: #force_inline proc(v: f32) -> i16 {
	return i16(v * 16_384)
}

hinter_program_f26dot6_to_f32 :: #force_inline proc(f26dot6: i32) -> f32 {
	return f32(f26dot6) / 64
}

hinter_program_f32_to_f26dot6 :: #force_inline proc(v: f32) -> i32 {
	return i32(math.round(v * 64))
}

hinter_program_ttf_ins_sxytca :: proc(ctx: ^Hinter_Program_Execution_Context) {
	ins_as_i16 := i16(ctx.ins)
	aa, bb: i16
	aa = (ins_as_i16 & 1) << 14
	bb = aa ~ 0x4000

	aa_f32 := hinter_program_f2dot14_to_f32(aa)
	bb_f32 := hinter_program_f2dot14_to_f32(bb)

	if ins_as_i16 < 4 {
		ctx.gs.proj_vector.x = aa_f32
		ctx.gs.proj_vector.y = bb_f32

		ctx.gs.dual_vector.x = aa_f32
		ctx.gs.dual_vector.y = bb_f32
	}
	if (ins_as_i16 & 2) == 0 {
		ctx.gs.free_vector.x = aa_f32
		ctx.gs.free_vector.y = bb_f32
	}
}

hinter_program_ttf_norm_f32 :: #force_inline proc(v: [2]f32) -> [2]f32 {
	n := linalg.normalize0(v)
	if n == {} {
		n = { 1, 0 }
	}
	if abs(n.x) < HINTER_EPS {
		n.x = 0
		n.y = 1
	}
	if abs(n.y) < HINTER_EPS {
		n.x = 1
		n.y = 0
	}
	return n
}

hinter_program_ttf_project :: proc(ctx: ^Hinter_Program_Execution_Context, d: [2]f32) -> f32 {
	return linalg.dot(ctx.gs.proj_vector, d)
}

hinter_program_ttf_dual_project :: proc(ctx: ^Hinter_Program_Execution_Context, d: [2]f32) -> f32 {
	return linalg.dot(ctx.gs.dual_vector, d)
}

hinter_program_ttf_round_according_to_state :: proc(ctx: ^Hinter_Program_Execution_Context, v: f32) -> f32 {
	new_v := abs(v)
	switch ctx.gs.round_state {
		case .to_half_grid: new_v = math.floor(new_v) + 0.5
		case .to_grid: new_v = math.round(new_v)
		case .to_double_grid: new_v = math.round(new_v * 2) / 2
		case .down_to_grid: new_v = math.floor(abs(new_v))
		case .up_to_grid: new_v = math.ceil(new_v)
		case .off: return v
	}
	return v < 0 ? -new_v : new_v
}

hinter_program_ttf_move_point_orig :: proc(ctx: ^Hinter_Program_Execution_Context, zone: ^Hinter_Program_Ttf_Zone, idx: u32, dist: f32) {
	hinter_program_ttf_zp_bounds_check(ctx, zone.orig, idx)
	if ctx.error {
		return
	}

	move := ctx.gs.free_vector * dist / hinter_program_f_dot_p(ctx)

	if ctx.gs.free_vector.x == 0 {
		move.x = 0
	}
	if ctx.gs.free_vector.y == 0 {
		move.y = 0
	}
	hinter_program_ttf_add_zp(ctx, zone.cur, idx, move)
}

hinter_program_ttf_move_point :: proc(ctx: ^Hinter_Program_Execution_Context, zone: ^Hinter_Program_Ttf_Zone, idx: u32, dist: f32, touch: bool) {
	move := ctx.gs.free_vector * dist / hinter_program_f_dot_p(ctx)
	if ctx.gs.free_vector.x != 0 {
		if touch {
			hinter_program_ttf_or_zp(ctx, zone.touch, idx, TTF_HINTER_TOUCH_X)
		}
		// In accordance with the FreeType's v40 interpreter (with backward 
		// compatability enabled), movement along the x-axis is disabled 
		move.x = 0
	}
	if ctx.gs.free_vector.y != 0 {
		if touch {
			hinter_program_ttf_or_zp(ctx, zone.touch, idx, TTF_HINTER_TOUCH_Y)
		}
		if ctx.iup_state == TTF_HINTER_TOUCH_XY {
			move.y = 0
		}
	}

	hinter_program_ttf_add_zp(ctx, zone.cur, idx, move)
	hinter_program_ttf_debug_log(ctx, "    moved: %v [%v], %v", hinter_program_ttf_get_zp(ctx, zone.cur, idx), idx, dist)
}

hinter_program_ttf_ins_sxvtl :: proc(ctx: ^Hinter_Program_Execution_Context, idx_1: u32, idx_2: u32) -> [2]f32 {
	ins := u8(ctx.ins)

	p1 := hinter_program_ttf_get_zp(ctx, ctx.zp1.cur, idx_1)
	p2 := hinter_program_ttf_get_zp(ctx, ctx.zp2.cur, idx_2)

	delta := p1 - p2

	norm := hinter_program_ttf_norm_f32(delta)
	if ins & 1 != 0 {
		norm = { -norm.y, norm.x }
	}

	return norm
}

hinter_program_ttf_ins_spvtl :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	v := hinter_program_ttf_ins_sxvtl(ctx, u32(values[0]), u32(values[1]))
	ctx.gs.proj_vector = v
	ctx.gs.dual_vector = v
}

hinter_program_ttf_ins_sfvtl :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	v := hinter_program_ttf_ins_sxvtl(ctx, u32(values[0]), u32(values[1]))
	ctx.gs.free_vector = v
}

hinter_program_ttf_ins_spvfs :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	y := hinter_program_f2dot14_to_f32(i16(values[0]))
	x := hinter_program_f2dot14_to_f32(i16(values[1]))

	norm := hinter_program_ttf_norm_f32({ x, y })

	ctx.gs.proj_vector = norm
	ctx.gs.dual_vector = norm
}

hinter_program_ttf_ins_sfvfs :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	y := hinter_program_f2dot14_to_f32(i16(values[0]))
	x := hinter_program_f2dot14_to_f32(i16(values[1]))

	norm := hinter_program_ttf_norm_f32({ x, y })

	ctx.gs.free_vector = norm

}

hinter_program_ttf_ins_gpv :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := [2]i32 {
		i32(hinter_program_f32_to_f2dot14(ctx.gs.proj_vector.x)),
		i32(hinter_program_f32_to_f2dot14(ctx.gs.proj_vector.y)),
	}
	hinter_program_ttf_stack_push(ctx, values)
}

hinter_program_ttf_ins_gfv :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := [2]i32 {
		i32(hinter_program_f32_to_f2dot14(ctx.gs.free_vector.x)),
		i32(hinter_program_f32_to_f2dot14(ctx.gs.free_vector.y)),
	}
	hinter_program_ttf_stack_push(ctx, values)
}

hinter_program_ttf_ins_sfvtpv :: proc(ctx: ^Hinter_Program_Execution_Context) {
	ctx.gs.free_vector = ctx.gs.proj_vector
}

hinter_program_ttf_ins_isect :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 5)

	b1_i := u32(values[0])
	b0_i := u32(values[1])
	a1_i := u32(values[2])
	a0_i := u32(values[3])
	point := u32(values[4])

	a0 := hinter_program_ttf_get_zp(ctx, ctx.zp1.cur, a0_i)
	a1 := hinter_program_ttf_get_zp(ctx, ctx.zp1.cur, a1_i)
	b0 := hinter_program_ttf_get_zp(ctx, ctx.zp0.cur, b0_i)
	b1 := hinter_program_ttf_get_zp(ctx, ctx.zp0.cur, b1_i)

	denom := (a0.x - a1.x) * (b0.y - b1.y) - (a0.y - a1.y) * (b0.x - b1.x)
	if abs(denom) > HINTER_EPS {
		a_cross := linalg.cross(a0, a1)
		b_cross := linalg.cross(b0, b1)

		val := (a_cross * (b0 - b1) - b_cross * (a0 - a1)) / denom
		hinter_program_ttf_set_zp(ctx, ctx.zp2.cur, point, val)
	} else {
		hinter_program_ttf_set_zp(ctx, ctx.zp2.cur, point, (a0 + a1 + b0 + b1) / 4)
	}

	hinter_program_ttf_or_zp(ctx, ctx.zp2.touch, point, TTF_HINTER_TOUCH_XY)
}

hinter_program_ttf_ins_srp0 :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 1)
	ctx.gs.rp0 = u32(values[0])
	hinter_program_ttf_debug_log(ctx, "    rp0 = %v", ctx.gs.rp0)
}

hinter_program_ttf_ins_srp1 :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := hinter_program_ttf_stack_pop(ctx, 1)[0]
	ctx.gs.rp1 = u32(value)
	hinter_program_ttf_debug_log(ctx, "    rp1 = %v", ctx.gs.rp1)
}

hinter_program_ttf_ins_srp2 :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := hinter_program_ttf_stack_pop(ctx, 1)[0]
	ctx.gs.rp2 = u32(value)
	hinter_program_ttf_debug_log(ctx, "    rp2 = %v", ctx.gs.rp2)
}

hinter_program_ttf_set_zone :: proc(ctx: ^Hinter_Program_Execution_Context, zp: ^^Hinter_Program_Ttf_Zone, value: u32) {
	switch value {
	case 0: zp^ = &ctx.program.zone0
	case 1: zp^ = &ctx.program.zone1
	case: hinter_program_error(ctx, "Illegal zone value")
	}
}

hinter_program_ttf_ins_szp0 :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	hinter_program_ttf_set_zone(ctx, &ctx.zp0, value)
	ctx.gs.gep0 = u16(value)
}

hinter_program_ttf_ins_szp1 :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	hinter_program_ttf_set_zone(ctx, &ctx.zp1, value)
	ctx.gs.gep1 = u16(value)
}

hinter_program_ttf_ins_szp2 :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	hinter_program_ttf_set_zone(ctx, &ctx.zp2, value)
	ctx.gs.gep2 = u16(value)
}

hinter_program_ttf_ins_szps :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	hinter_program_ttf_set_zone(ctx, &ctx.zp0, value)
	hinter_program_ttf_set_zone(ctx, &ctx.zp1, value)
	hinter_program_ttf_set_zone(ctx, &ctx.zp2, value)
	ctx.gs.gep0 = u16(value)
	ctx.gs.gep1 = u16(value)
	ctx.gs.gep2 = u16(value)
}

hinter_program_ttf_ins_sloop :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := hinter_program_ttf_stack_pop(ctx, 1)[0]
	ctx.gs.loop = min(value, 0xFFFF)
}

hinter_program_ttf_ins_rtg :: proc(ctx: ^Hinter_Program_Execution_Context) {
	ctx.gs.round_state = .to_grid
}

hinter_program_ttf_ins_rthg :: proc(ctx: ^Hinter_Program_Execution_Context) {
	ctx.gs.round_state = .to_half_grid
}

hinter_program_ttf_ins_smd :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := hinter_program_ttf_stack_pop(ctx, 1)[0]
	ctx.gs.min_distance = hinter_program_f26dot6_to_f32(value)
}

hinter_program_ttf_skip_code :: proc(ctx: ^Hinter_Program_Execution_Context) {
	next := hinter_program_ttf_instructions_next(ctx)
	real_len := int(TTF_HINTER_INSTRUCTION_LEN[u8(next)])
	if real_len < 0 {
		real_len = abs(real_len) * int(hinter_program_ttf_instructions_next(ctx))
	} else {
		real_len -= 1
	}
	ctx.instructions.offset += real_len
	if ctx.instructions.offset >= len(ctx.instructions.data) {
		hinter_program_error(ctx, "oob instruction")
	}
	if ctx.error {
		return
	}
	ctx.ins = Ttf_Hinter_Instruction(ctx.instructions.data[ctx.instructions.offset])
}

hinter_program_ttf_ins_else :: proc(ctx: ^Hinter_Program_Execution_Context) {
	n_ifs := 1
	for n_ifs != 0 {
		hinter_program_ttf_skip_code(ctx)
		if ctx.error {
			return
		}
		#partial switch ctx.ins {
		case .ins_if: n_ifs += 1
		case .ins_eif: n_ifs -= 1
		}
	}
	// NOTE(lucas): eat last eif
	hinter_program_ttf_instructions_next(ctx)
}

hinter_program_ttf_ins_jmpr :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := hinter_program_ttf_stack_pop(ctx, 1)[0]
	hinter_program_ttf_instructions_jump(ctx, value)
}

hinter_program_ttf_ins_scvtci :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := hinter_program_ttf_stack_pop(ctx, 1)[0]
	ctx.gs.control_value_cutin = hinter_program_f26dot6_to_f32(value)
}

hinter_program_ttf_ins_sswci :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := hinter_program_ttf_stack_pop(ctx, 1)[0]
	ctx.gs.single_width_cutin = hinter_program_f26dot6_to_f32(value)
}

hinter_program_ttf_ins_ssw :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := hinter_program_ttf_stack_pop(ctx, 1)[0]
	ctx.gs.single_width_cutin = hinter_program_f26dot6_to_f32(value) * ctx.program.funits_to_pixels_scale
}

hinter_program_ttf_ins_dup :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := hinter_program_ttf_stack_pop(ctx, 1)[0]
	hinter_program_ttf_stack_push(ctx, [2]i32 { value, value })
}

hinter_program_ttf_ins_pop :: proc(ctx: ^Hinter_Program_Execution_Context) {
	hinter_program_ttf_stack_pop(ctx, 1)
}

hinter_program_ttf_ins_clear :: proc(ctx: ^Hinter_Program_Execution_Context) {
	ctx.stack.count = 0
}

hinter_program_ttf_ins_swap :: proc(ctx: ^Hinter_Program_Execution_Context) {
	hinter_program_ttf_stack_push(ctx, hinter_program_ttf_stack_pop(ctx, 2))
}

hinter_program_ttf_ins_depth :: proc(ctx: ^Hinter_Program_Execution_Context) {
	hinter_program_ttf_stack_push(ctx, [1]i32 { i32(ctx.stack.count) })
}

hinter_program_ttf_ins_cindex :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := hinter_program_ttf_stack_pop(ctx, 1)[0]
	offset := ctx.stack.count - int(value)
	if offset < 0 || offset >= ctx.stack.count {
		hinter_program_error(ctx, "Stack read OOB")
		return
	}
	hinter_program_ttf_stack_push(ctx, [1]i32 { ctx.stack.data[offset] })
}

hinter_program_ttf_ins_mindex :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := hinter_program_ttf_stack_pop(ctx, 1)[0]
	offset := ctx.stack.count - int(value)
	if offset < 0 || offset >= ctx.stack.count {
		hinter_program_error(ctx, "Stack read OOB")
		return
	}
	move := ctx.stack.data[offset]
	copy(ctx.stack.data[offset:], ctx.stack.data[offset+1:])
	ctx.stack.data[ctx.stack.count - 1] = move
}

hinter_program_ttf_ins_alignpts :: proc(ctx: ^Hinter_Program_Execution_Context) {
	points := hinter_program_ttf_stack_pop(ctx, 2)

	p1 := u32(points[1])
	p2 := u32(points[0])

	v1 := hinter_program_ttf_get_zp(ctx, ctx.zp1.cur, p1)
	v2 := hinter_program_ttf_get_zp(ctx, ctx.zp2.cur, p2)

	distance := hinter_program_ttf_project(ctx, v2 - v1) / 2

	// func_move
	hinter_program_ttf_move_point(ctx, ctx.zp1, p1, distance, true)
	hinter_program_ttf_move_point(ctx, ctx.zp0, p2, -distance, true)
}

hinter_program_ttf_ins_utp :: proc(ctx: ^Hinter_Program_Execution_Context) {
	point := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	mask := u8(0xFF)
	if ctx.gs.free_vector.x != 0 {
		mask &= ~TTF_HINTER_TOUCH_X
	}
	if ctx.gs.free_vector.y != 0{
		mask &= ~TTF_HINTER_TOUCH_Y
	}
	hinter_program_ttf_and_zp(ctx, ctx.zp0.touch, point, mask)
}

hinter_program_ttf_call_func :: proc(ctx: ^Hinter_Program_Execution_Context, func_id: u32, count: i32) {
	stashed_instructions := ctx.instructions
	if func_id < 0 || i64(func_id) >= i64(len(ctx.program.shared_intructions)) {
		hinter_program_error(ctx, "execute invalid instruction stream")
	}
	if ctx.error {
		return
	}
	ctx.instructions.data = ctx.program.shared_intructions[func_id]
	for _ in 0..<count {
		if ctx.error {
			break
		}
		ctx.instructions.offset = 0
		hinter_program_ttf_execute(ctx)
	}
	ctx.instructions = stashed_instructions
}

hinter_program_ttf_ins_loopcall :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	func_id := u32(values[0])
	count := values[1]
	hinter_program_ttf_call_func(ctx, func_id, count)
}

hinter_program_ttf_ins_call :: proc(ctx: ^Hinter_Program_Execution_Context) {
	func_id := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	hinter_program_ttf_call_func(ctx, func_id, 1)
}

hinter_program_ttf_ins_fdef :: proc(ctx: ^Hinter_Program_Execution_Context) {
	func_id := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	if func_id < 0 || i64(func_id) >= i64(len(ctx.program.shared_intructions)) {
		hinter_program_error(ctx, "execute invalid instruction stream")
	}
	ins_start := hinter_program_ttf_instructions_ptr_next(ctx)
	len := 1
	for hinter_program_ttf_instructions_next(ctx) != .ins_endf && ! ctx.error {
		len += 1
	}
	if ctx.error {
		return
	}
	ctx.program.shared_intructions[func_id] = mem.slice_ptr(ins_start, len)
}

hinter_program_ttf_ins_endf :: proc(ctx: ^Hinter_Program_Execution_Context) {
	// NOTE(lucas): no op
}

hinter_program_ttf_ins_mdap :: proc(ctx: ^Hinter_Program_Execution_Context) {
	ins := u8(ctx.ins)

	point := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	distance: f32
	if ins & 0x1 != 0 {
		v := hinter_program_ttf_get_zp(ctx, ctx.zp0.cur, point)
		d := hinter_program_ttf_project(ctx, v)
		distance = hinter_program_ttf_round_according_to_state(ctx, d) - d
	} else {
		distance = 0
	}
	hinter_program_ttf_move_point(ctx, ctx.zp0, point, distance, true)

	ctx.gs.rp0 = point
	ctx.gs.rp1 = point
	hinter_program_ttf_debug_log(ctx, "    rp0 = %v", ctx.gs.rp0)
	hinter_program_ttf_debug_log(ctx, "    rp1 = %v", ctx.gs.rp1)
}

hinter_program_ttf_ins_iup :: proc(ctx: ^Hinter_Program_Execution_Context) {
	ins := u8(ctx.ins)
	if ctx.zp2 == &ctx.program.zone0 {
		hinter_program_error(ctx, "Invalid IUP zone")
		return
	}

	// In accordance with the FreeType's v40 interpreter (with backward 
	// compatability enabled), points cannot be moved on either axis post-IUP.
	// Post-IUP occurs after IUP has been executed using both the x and y axes.

	if (ctx.iup_state == TTF_HINTER_TOUCH_XY) {
		return
	}

	touch_flag := ins & 1 != 0 ? TTF_HINTER_TOUCH_X : TTF_HINTER_TOUCH_Y
	ctx.iup_state |= touch_flag
	axis := touch_flag == TTF_HINTER_TOUCH_X ? 0 : 1

	/*
	point_idx := u32(0)
	for end_point_idx in ctx.program.zone1.end_points {
		start_point_idx := point_idx
		for point_idx <= end_point_idx && hinter_program_ttf_get_zp(ctx, ctx.program.zone1.touch, point_idx) & touch_flag == 0 {
			point_idx += 1
		}

		if point_idx <= end_point_idx {
			first_touched_idx := point_idx
			current_touched_idx := point_idx

			point_idx += 1

			for point_idx <= end_point_idx {
				if hinter_program_ttf_get_zp(ctx, ctx.program.zone1.touch, point_idx) & touch_flag != 0 {
					hinter_program_interpolate(ctx, axis, current_touched_idx + 1, point_idx - 1, current_touched_idx, point_idx)
					current_touched_idx = point_idx
				}
				point_idx += 1
			}

			if current_touched_idx == first_touched_idx {
				hinter_program_shift(ctx, axis, start_point_idx, end_point_idx, current_touched_idx)
			} else {
				hinter_program_interpolate(ctx, axis, current_touched_idx + 1, end_point_idx, current_touched_idx, first_touched_idx)
				if first_touched_idx > 0 {
					hinter_program_interpolate(ctx, axis, start_point_idx, first_touched_idx - 1, current_touched_idx, first_touched_idx)
				}
			}
		}
	}
	*/

	point_idx := u32(0)
	for end_point_idx in ctx.program.zone1.end_points {
		start_point_idx := point_idx
		touch_0: u32
		finding_touch_1: bool
		for point_idx <= end_point_idx {

			if ctx.program.zone1.touch[point_idx] & touch_flag != 0 {
				if finding_touch_1 {
					hinter_program_interpolate_or_shift(ctx, axis, start_point_idx, end_point_idx, touch_0, point_idx)

					finding_touch_1 = point_idx != end_point_idx || ctx.program.zone1.touch[start_point_idx] & touch_flag == 0
					if finding_touch_1 {
						touch_0 = point_idx
					}
				} else {
					touch_0 = point_idx
					finding_touch_1 = true
				}
			}

			point_idx += 1
		}

		if finding_touch_1 {
			// The index of the second touched point wraps back to the beginning.
			for i in start_point_idx..=touch_0 {
				if ctx.program.zone1.touch[i] & touch_flag != 0 {
					hinter_program_interpolate_or_shift(ctx, axis, start_point_idx, end_point_idx, touch_0, i)
					break
				}
			}
		}
	}
}

hinter_program_f_dot_p :: proc(ctx: ^Hinter_Program_Execution_Context) -> f32 {
	v := linalg.dot(ctx.gs.free_vector, ctx.gs.proj_vector)
	if abs(v) < F_DOT_P_MIN {
		v = 1
	}
	return v
}

hinter_program_compute_point_displacement :: proc(ctx: ^Hinter_Program_Execution_Context) -> (f32, ^Hinter_Program_Ttf_Zone, u32) {
	ins := u8(ctx.ins)
	ref_p: u32
	ref_zone: ^Hinter_Program_Ttf_Zone
	if ins & 0x1 != 0 {
		ref_p = ctx.gs.rp1
		ref_zone = ctx.zp0
	} else {
		ref_p = ctx.gs.rp2
		ref_zone = ctx.zp1
	}

	cur := hinter_program_ttf_get_zp(ctx, ref_zone.cur, ref_p)
	orig := hinter_program_ttf_get_zp(ctx, ref_zone.orig_scaled, ref_p)
	if ctx.error {
		return 0, nil, 0
	}

	d := hinter_program_ttf_project(ctx, cur - orig)

	return d, ref_zone, ref_p
}

hinter_program_ttf_ins_shp :: proc(ctx: ^Hinter_Program_Execution_Context) {
	d, _, _ := hinter_program_compute_point_displacement(ctx)
	if ctx.error {
		return
	}

	for _ in 0..<ctx.gs.loop {
		point := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
		hinter_program_ttf_move_point(ctx, ctx.zp2, point, d, true)
	}
	ctx.gs.loop = 1
}

hinter_program_ttf_ins_shc :: proc(ctx: ^Hinter_Program_Execution_Context) {
	contour := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	d, ref_zone, ref_p := hinter_program_compute_point_displacement(ctx)
	if ctx.error {
		return
	}
	if ref_zone != ctx.zp2 {
		ref_p = 0xFFFFFFFF
	}

	start := u32(0)
	limit := u32(0)
	if contour != 0 {
		start = hinter_program_ttf_get_zp(ctx, ctx.zp2.end_points, contour - 1) + 1
	}
	if ctx.gs.gep2 == 0 {
		limit = u32(len(ctx.zp2.end_points))
	} else {
		limit = hinter_program_ttf_get_zp(ctx, ctx.zp2.end_points, contour) + 1
	}

	for i := start; i < limit; i += 1 {
		if i != ref_p {
			hinter_program_ttf_move_point(ctx, ctx.zp2, i, d, true)
		}
	}
}

hinter_program_ttf_ins_shz :: proc(ctx: ^Hinter_Program_Execution_Context) {
	contour := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	d, ref_zone, ref_p := hinter_program_compute_point_displacement(ctx)
	if ctx.error {
		return
	}
	if ref_zone != ctx.zp2 {
		ref_p = 0xFFFFFFFF
	}

	limit := u32(0)
	if ctx.gs.gep2 == 0 {
		limit = u32(len(ctx.zp2.end_points))
	} else {
		limit = hinter_program_ttf_get_zp(ctx, ctx.zp2.end_points, contour)
	}

	for i := u32(0); i < limit; i += 1 {
		if i != ref_p {
			hinter_program_ttf_move_point(ctx, ctx.zp2, i, d, false)
		}
	}
}

hinter_program_ttf_is_twilight_zone :: proc(ctx: ^Hinter_Program_Execution_Context) -> bool {
	return ctx.gs.gep0 == 0 && ctx.gs.gep1 == 0 && ctx.gs.gep2 == 0
}

hinter_program_ttf_ins_shpix :: proc(ctx: ^Hinter_Program_Execution_Context) {
	amt := hinter_program_f2dot14_to_f32(i16(hinter_program_ttf_stack_pop(ctx, 1)[0]))
	is_twilight_zone := hinter_program_ttf_is_twilight_zone(ctx)

	for _ in 0..<ctx.gs.loop {
		point_idx := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
		should_move := is_twilight_zone
		if ! should_move && ctx.iup_state != TTF_HINTER_TOUCH_XY {
			should_move = (ctx.is_compound_glyph && ctx.gs.free_vector.y != 0) ||
			(hinter_program_ttf_get_zp(ctx, ctx.zp2.touch, point_idx) & TTF_HINTER_TOUCH_Y != 0)
		}
	
		if should_move {
			hinter_program_ttf_move_point(ctx, ctx.zp2, point_idx, amt, true)
		}
	}
	ctx.gs.loop = 1
}

hinter_program_ttf_ins_ip :: proc(ctx: ^Hinter_Program_Execution_Context) {
	rp1_cur := hinter_program_ttf_get_zp(ctx, ctx.zp0.cur, ctx.gs.rp1)
	rp2_cur := hinter_program_ttf_get_zp(ctx, ctx.zp1.cur, ctx.gs.rp2)

	rp1_orig, rp2_orig: [2]f32

	is_twilight_zone := hinter_program_ttf_is_twilight_zone(ctx)
	if is_twilight_zone {
		rp1_orig = hinter_program_ttf_get_zp(ctx, ctx.zp0.orig_scaled, ctx.gs.rp1)
		rp2_orig = hinter_program_ttf_get_zp(ctx, ctx.zp1.orig_scaled, ctx.gs.rp2)
	} else {
		rp1_orig = hinter_program_ttf_get_zp(ctx, ctx.zp0.orig, ctx.gs.rp1)
		rp2_orig = hinter_program_ttf_get_zp(ctx, ctx.zp1.orig, ctx.gs.rp2)
	}

	total_dist_cur := hinter_program_ttf_project(ctx, rp2_cur - rp1_cur)
	total_dist_orig := hinter_program_ttf_dual_project(ctx, rp2_orig - rp1_orig)

	for _ in 0..< ctx.gs.loop {
		point_idx := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])

		point_cur := hinter_program_ttf_get_zp(ctx, ctx.zp2.cur, point_idx)
		zp_target := is_twilight_zone ? ctx.zp2.orig_scaled : ctx.zp2.orig
		point_orig := hinter_program_ttf_get_zp(ctx, zp_target, point_idx)

		dist_cur := hinter_program_ttf_project(ctx, point_cur - rp1_cur)
		dist_orig := hinter_program_ttf_dual_project(ctx, point_orig - rp1_orig)
		dist_new := f32(0)
		if abs(total_dist_orig) > 0 {
			dist_new = (dist_orig * total_dist_cur) / total_dist_orig
		} else {
			dist_new = dist_orig
		}
		hinter_program_ttf_move_point(ctx, ctx.zp2, point_idx, dist_new - dist_cur, true)
	}

	ctx.gs.loop = 1
}

hinter_program_ttf_ins_msirp :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)

	distance := hinter_program_f26dot6_to_f32(values[0])
	point := u32(values[1])

	if ctx.gs.gep1 == 0 {
		orig := hinter_program_ttf_get_zp(ctx, ctx.zp0.orig, ctx.gs.rp0)
		hinter_program_ttf_set_zp(ctx, ctx.zp1.orig, point, orig)
		hinter_program_ttf_move_point_orig(ctx, ctx.zp1, point, distance)
		hinter_program_ttf_set_zp(ctx, ctx.zp1.cur, point, orig)
	}

	zp0_cur := hinter_program_ttf_get_zp(ctx, ctx.zp0.cur, ctx.gs.rp0)
	zp1_cur := hinter_program_ttf_get_zp(ctx, ctx.zp1.cur, point)
	distance_proj := hinter_program_ttf_project(ctx, zp1_cur - zp0_cur)
	hinter_program_ttf_move_point(ctx, ctx.zp1, point, distance - distance_proj, true)

	ctx.gs.rp1 = ctx.gs.rp0
	ctx.gs.rp2 = point

	if u8(ctx.ins) & 0x1 != 0 {
		ctx.gs.rp0 = point
	}
	hinter_program_ttf_debug_log(ctx, "    rp0 = %v", ctx.gs.rp0)
	hinter_program_ttf_debug_log(ctx, "    rp1 = %v", ctx.gs.rp1)
	hinter_program_ttf_debug_log(ctx, "    rp2 = %v", ctx.gs.rp2)
}

hinter_program_ttf_ins_alignrp :: proc(ctx: ^Hinter_Program_Execution_Context) {
	rp0_cur := hinter_program_ttf_get_zp(ctx, ctx.zp0.cur, ctx.gs.rp0)
	for _ in 0..<ctx.gs.loop {
		point_idx := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
		cur := hinter_program_ttf_get_zp(ctx, ctx.zp1.cur, point_idx)
		dist := hinter_program_ttf_project(ctx, rp0_cur - cur)
		hinter_program_ttf_move_point(ctx, ctx.zp1, point_idx, dist, true)
	}
	ctx.gs.loop = 1
}

hinter_program_ttf_ins_rtdg :: proc(ctx: ^Hinter_Program_Execution_Context) {
	ctx.gs.round_state = .to_double_grid
}

hinter_program_ttf_ins_miap :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	cvt_idx := u32(values[0])
	point_idx := u32(values[1])

	new_dist := hinter_program_ttf_get_cvt(ctx, cvt_idx)
	cur: [2]f32
	if ctx.gs.gep0 == 0 {
		cur = new_dist * ctx.gs.free_vector
		hinter_program_ttf_set_zp(ctx, ctx.zp0.orig_scaled, point_idx, cur)
		hinter_program_ttf_set_zp(ctx, ctx.zp0.cur, point_idx, cur)
	} else {
		cur = hinter_program_ttf_get_zp(ctx, ctx.zp0.cur, point_idx)
	}

	cur_dist := hinter_program_ttf_project(ctx, cur)
	ins := u8(ctx.ins)
	if ins & 0x1 != 0 {
		if abs(new_dist - cur_dist) > ctx.gs.control_value_cutin {
			new_dist = cur_dist
		}
		new_dist = hinter_program_ttf_round_according_to_state(ctx, new_dist)
	}
	hinter_program_ttf_move_point(ctx, ctx.zp0, point_idx, new_dist - cur_dist, true)

	ctx.gs.rp0 = point_idx
	ctx.gs.rp1 = point_idx
	hinter_program_ttf_debug_log(ctx, "    rp0 = %v", ctx.gs.rp0)
	hinter_program_ttf_debug_log(ctx, "    rp1 = %v", ctx.gs.rp1)
}

hinter_program_ttf_ins_npushb :: proc(ctx: ^Hinter_Program_Execution_Context) {
	count := u8(hinter_program_ttf_instructions_next(ctx))
	for _ in 0..<count {
		v := hinter_program_ttf_instructions_next(ctx)
		hinter_program_ttf_stack_push(ctx, [1]i32 { i32(v) })
	}
}

hinter_program_ttf_ins_npushw :: proc(ctx: ^Hinter_Program_Execution_Context) {
	count := u8(hinter_program_ttf_instructions_next(ctx))
	for _ in 0..<count {
		ms := hinter_program_ttf_instructions_next(ctx)
		ls := hinter_program_ttf_instructions_next(ctx)
		v := i32(i16(u16(ms) << 8 | u16(ls)))
		hinter_program_ttf_stack_push(ctx, [1]i32 { v })
	}
}

hinter_program_ttf_ins_ws :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	value := values[0]
	idx := u32(values[1])
	hinter_program_ttf_set_storage(ctx, idx, value)
}

hinter_program_ttf_ins_rs :: proc(ctx: ^Hinter_Program_Execution_Context) {
	idx := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	val := hinter_program_ttf_get_storage(ctx, idx)
	hinter_program_ttf_stack_push(ctx, [1]i32 { val })
}

hinter_program_ttf_ins_wcvtp :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	pixels := hinter_program_f26dot6_to_f32(values[0])
	idx := u32(values[1])
	hinter_program_ttf_set_cvt(ctx, idx, pixels)
}

hinter_program_ttf_ins_rcvt :: proc(ctx: ^Hinter_Program_Execution_Context) {
	idx := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	pixels := hinter_program_ttf_get_cvt(ctx, idx)
	hinter_program_ttf_debug_log(ctx, "    cvt value: %v [%v]", pixels, idx)
	hinter_program_ttf_stack_push(ctx, [1]i32 { hinter_program_f32_to_f26dot6(pixels) })
}

hinter_program_ttf_ins_gc :: proc(ctx: ^Hinter_Program_Execution_Context) {
	idx := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	ins := u8(ctx.ins)

	val: f32
	if ins & 0x1 != 0 {
		orig_scaled := hinter_program_ttf_get_zp(ctx, ctx.zp2.orig_scaled, idx)
		val = hinter_program_ttf_dual_project(ctx, orig_scaled)
	} else {
		cur := hinter_program_ttf_get_zp(ctx, ctx.zp2.cur, idx)
		val = hinter_program_ttf_project(ctx, cur)
	}

	hinter_program_ttf_stack_push(ctx, [1]i32 { hinter_program_f32_to_f26dot6(val) })
}

hinter_program_ttf_ins_scfs :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	k := hinter_program_f26dot6_to_f32(values[0])
	point_idx := u32(values[1])

	projection := hinter_program_ttf_project(ctx, hinter_program_ttf_get_zp(ctx, ctx.zp2.cur, point_idx))
	hinter_program_ttf_move_point(ctx, ctx.zp2, point_idx, projection - k, true)
	if ctx.gs.gep2 == 0 {
		twilight := hinter_program_ttf_get_zp(ctx, ctx.zp2.cur, point_idx)
		hinter_program_ttf_set_zp(ctx, ctx.zp2.orig_scaled, point_idx, twilight)
	}
}

hinter_program_ttf_ins_md :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	point_idx_0 := u32(values[0])
	point_idx_1 := u32(values[1])

	ins := u8(ctx.ins)
	dist: f32
	if ins & 1 != 0 {
		cur_0 := hinter_program_ttf_get_zp(ctx, ctx.zp1.cur, point_idx_0)
		cur_1 := hinter_program_ttf_get_zp(ctx, ctx.zp0.cur, point_idx_1)
		dist = hinter_program_ttf_project(ctx, cur_1 - cur_0)
	} else {
		is_twilight := ctx.gs.gep0 == 0 || ctx.gs.gep1 == 0
		if is_twilight {
			orig_0 := hinter_program_ttf_get_zp(ctx, ctx.zp1.orig_scaled, point_idx_0)
			orig_1 := hinter_program_ttf_get_zp(ctx, ctx.zp0.orig_scaled, point_idx_1)
			dist = hinter_program_ttf_dual_project(ctx, orig_1 - orig_0)
		} else {
			orig_0 := hinter_program_ttf_get_zp(ctx, ctx.zp1.orig, point_idx_0)
			orig_1 := hinter_program_ttf_get_zp(ctx, ctx.zp0.orig, point_idx_1)
			dist = hinter_program_ttf_dual_project(ctx, orig_1 - orig_0) * ctx.program.funits_to_pixels_scale
		}
	}

	hinter_program_ttf_stack_push(ctx, [1]i32 { hinter_program_f32_to_f26dot6(dist) })
}

hinter_program_ttf_ins_mppem :: proc(ctx: ^Hinter_Program_Execution_Context) {
	hinter_program_ttf_stack_push(ctx, [1]i32 { i32(ctx.program.ppem) })
}

hinter_program_ttf_ins_mps :: proc(ctx: ^Hinter_Program_Execution_Context) {
	hinter_program_ttf_stack_push(ctx, [1]i32 { hinter_program_f32_to_f26dot6(ctx.program.point_size) })
}

hinter_program_ttf_ins_flipon :: proc(ctx: ^Hinter_Program_Execution_Context) {
	ctx.gs.auto_flip = true
}

hinter_program_ttf_ins_flipoff :: proc(ctx: ^Hinter_Program_Execution_Context) {
	ctx.gs.auto_flip = false
}

hinter_program_ttf_ins_debug :: proc(ctx: ^Hinter_Program_Execution_Context) {
	hinter_program_ttf_stack_pop(ctx, 1)
}

hinter_program_ttf_ins_lt :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	hinter_program_ttf_stack_push(ctx, [1]i32 { e1 < e2 ? 1 : 0 })
}

hinter_program_ttf_ins_lteq :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	hinter_program_ttf_stack_push(ctx, [1]i32 { e1 <= e2 ? 1 : 0 })
}

hinter_program_ttf_ins_gt :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	hinter_program_ttf_stack_push(ctx, [1]i32 { e1 > e2 ? 1 : 0 })
}

hinter_program_ttf_ins_gteq :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	hinter_program_ttf_stack_push(ctx, [1]i32 { e1 >= e2 ? 1 : 0 })
}

hinter_program_ttf_ins_eq :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	hinter_program_ttf_stack_push(ctx, [1]i32 { e1 == e2 ? 1 : 0 })
}

hinter_program_ttf_ins_neq :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	hinter_program_ttf_stack_push(ctx, [1]i32 { e1 != e2 ? 1 : 0 })
}

hinter_program_ttf_ins_odd :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := hinter_program_f26dot6_to_f32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	value = hinter_program_ttf_round_according_to_state(ctx, value)
	is_odd := hinter_program_f32_to_f26dot6(value) & 127 == 64
	hinter_program_ttf_stack_push(ctx, [1]i32 { is_odd ? 1 : 0 })
}

hinter_program_ttf_ins_even :: proc(ctx: ^Hinter_Program_Execution_Context) {
	value := hinter_program_f26dot6_to_f32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	value = hinter_program_ttf_round_according_to_state(ctx, value)
	is_even := hinter_program_f32_to_f26dot6(value) & 127 == 0
	hinter_program_ttf_stack_push(ctx, [1]i32 { is_even ? 1 : 0 })
}

hinter_program_ttf_ins_if :: proc(ctx: ^Hinter_Program_Execution_Context) {
	val := hinter_program_ttf_stack_pop(ctx, 1)[0]
	if val != 0 {
		return
	}

	n_ifs := 1
	out := false
	for ! out && ! ctx.error {
		hinter_program_ttf_skip_code(ctx)
		#partial switch ctx.ins {
		case .ins_if:
			n_ifs += 1
		case .ins_else:
			out = n_ifs == 1
		case .ins_eif:
			n_ifs -= 1
			out = n_ifs == 0
		}
	}
	// NOTE(lucas): eat last else/eif
	hinter_program_ttf_instructions_next(ctx)
}

hinter_program_ttf_ins_eif :: proc(ctx: ^Hinter_Program_Execution_Context) {
	// no op
}

hinter_program_ttf_ins_and :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	hinter_program_ttf_stack_push(ctx, [1]i32 { e1 != 0 && e2 != 0 ? 1 : 0 })
}

hinter_program_ttf_ins_or :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	hinter_program_ttf_stack_push(ctx, [1]i32 { e1 != 0 || e2 != 0 ? 1 : 0 })
}

hinter_program_ttf_ins_not :: proc(ctx: ^Hinter_Program_Execution_Context) {
	val := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	hinter_program_ttf_stack_push(ctx, [1]i32 { val == 0 ? 1 : 0 })
}

hinter_program_ttf_ins_sdb :: proc(ctx: ^Hinter_Program_Execution_Context) {
	val := u16(hinter_program_ttf_stack_pop(ctx, 1)[0])
	ctx.gs.delta_base = val
}

hinter_program_ttf_ins_sds :: proc(ctx: ^Hinter_Program_Execution_Context) {
	val := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	ctx.gs.delta_shift = val
}

hinter_program_ttf_ins_add :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	hinter_program_ttf_stack_push(ctx, [1]i32 { values[0] + values[1] })
}

hinter_program_ttf_ins_sub :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	hinter_program_ttf_stack_push(ctx, [1]i32 { values[1] - values[0] })
}

hinter_program_ttf_ins_div :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	n1 := hinter_program_f26dot6_to_f32(values[0])
	n2 := hinter_program_f26dot6_to_f32(values[1])

	hinter_program_ttf_stack_push(ctx, [1]i32 { hinter_program_f32_to_f26dot6(n2 / n1) })
}

hinter_program_ttf_ins_mul :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	n1 := hinter_program_f26dot6_to_f32(values[0])
	n2 := hinter_program_f26dot6_to_f32(values[1])

	hinter_program_ttf_stack_push(ctx, [1]i32 { hinter_program_f32_to_f26dot6(n2 * n1) })
}

hinter_program_ttf_ins_abs :: proc(ctx: ^Hinter_Program_Execution_Context) {
	val := hinter_program_ttf_stack_pop(ctx, 1)[0]
	hinter_program_ttf_stack_push(ctx, [1]i32 { abs(val) })
}

hinter_program_ttf_ins_neg :: proc(ctx: ^Hinter_Program_Execution_Context) {
	val := hinter_program_ttf_stack_pop(ctx, 1)[0]
	hinter_program_ttf_stack_push(ctx, [1]i32 { -val })
}

hinter_program_ttf_ins_floor :: proc(ctx: ^Hinter_Program_Execution_Context) {
	val := hinter_program_ttf_stack_pop(ctx, 1)[0]
	hinter_program_ttf_stack_push(ctx, [1]i32 { i32(u32(val) & 0xFFFFFFC0) })
}

hinter_program_ttf_ins_ceiling :: proc(ctx: ^Hinter_Program_Execution_Context) {
	val := hinter_program_ttf_stack_pop(ctx, 1)[0]
	hinter_program_ttf_stack_push(ctx, [1]i32 { i32((u32(val) + 0x3F) & 0xFFFFFFC0) })
}

hinter_program_ttf_ins_round :: proc(ctx: ^Hinter_Program_Execution_Context) {
	val := hinter_program_f26dot6_to_f32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	val = hinter_program_ttf_round_according_to_state(ctx, val)
	hinter_program_ttf_stack_push(ctx, [1]i32 { hinter_program_f32_to_f26dot6(val) })
}

hinter_program_ttf_ins_nround :: proc(ctx: ^Hinter_Program_Execution_Context) {
	// NOTE(lucas): we no-op here as we do not have engine compensation
	// TODO(lucas): maybe we want compensation?
}

hinter_program_ttf_ins_wcvtf :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	funits := f32(u32(values[0]))
	cvt_idx := u32(values[1])
	hinter_program_ttf_set_cvt(ctx, cvt_idx, funits * ctx.program.funits_to_pixels_scale)
}

hinter_program_ttf_try_get_delta_value :: proc(ctx: ^Hinter_Program_Execution_Context, exc: u32, range: u32) -> (f32, bool) {
	ppem := ((exc & 0xF0) >> 4) + u32(ctx.gs.delta_base) + range
	if ctx.program.ppem != ppem {
		return {}, false
	}
	num_steps := i32(exc & 0xF) - 8
	if num_steps > 0 {
		num_steps += 1
	}

	steps := i32(num_steps * (1 << (6 - ctx.gs.delta_shift)))
	return hinter_program_f26dot6_to_f32(steps), true
}

hinter_program_ttf_ins_deltap :: proc(ctx: ^Hinter_Program_Execution_Context) {
	range: u32 = 0
	#partial switch ctx.ins {
	case .ins_deltap1: range = 0
	case .ins_deltap2: range = 16
	case .ins_deltap3: range = 32
	}

	count := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	for _ in 0..<count {
		values := hinter_program_ttf_stack_pop(ctx, 2)
		point_index := u32(values[0])
		exc := u32(values[1])
		if delta, ok := hinter_program_ttf_try_get_delta_value(ctx, exc, range); ok {
			touch_state := hinter_program_ttf_get_zp(ctx, ctx.zp0.touch, point_index)
			a := ctx.iup_state != TTF_HINTER_TOUCH_XY
			b := ctx.is_compound_glyph && ctx.gs.free_vector.y != 0
			c := touch_state & TTF_HINTER_TOUCH_Y != 0
			can_move := a && b || c
			if can_move {
				hinter_program_ttf_move_point(ctx, ctx.zp0, point_index, delta, true)
			}
		}
	}
}

hinter_program_ttf_ins_deltac :: proc(ctx: ^Hinter_Program_Execution_Context) {
	range: u32 = 0
	#partial switch ctx.ins {
	case .ins_deltac1: range = 0
	case .ins_deltac2: range = 16
	case .ins_deltac3: range = 32
	}
	count := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])
	for _ in 0..<count {
		values := hinter_program_ttf_stack_pop(ctx, 2)
		cvt_index := u32(values[0])
		exc := u32(values[1])
		if delta, ok := hinter_program_ttf_try_get_delta_value(ctx, exc, range); ok {
			hinter_program_ttf_add_cvt(ctx, cvt_index, delta)
		}
	}
}

hinter_program_ttf_ins_sround :: proc(ctx: ^Hinter_Program_Execution_Context) {
	hinter_program_error(ctx, "unimplemented instruction sround")
}

hinter_program_ttf_ins_s45round :: proc(ctx: ^Hinter_Program_Execution_Context) {
	hinter_program_error(ctx, "unimplemented instruction s45round")
}

hinter_program_ttf_ins_jrot :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	val := values[0]
	off := values[1]
	if val != 0 {
		hinter_program_ttf_instructions_jump(ctx, off - 1)
	}
}

hinter_program_ttf_ins_jrof :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	val := values[0]
	off := values[1]
	if val == 0 {
		hinter_program_ttf_instructions_jump(ctx, off - 1)
	}
}

hinter_program_ttf_ins_roff :: proc(ctx: ^Hinter_Program_Execution_Context) {
	ctx.gs.round_state = .off
}

hinter_program_ttf_ins_rutg :: proc(ctx: ^Hinter_Program_Execution_Context) {
	ctx.gs.round_state = .up_to_grid
}

hinter_program_ttf_ins_rdtg :: proc(ctx: ^Hinter_Program_Execution_Context) {
	ctx.gs.round_state = .down_to_grid
}

hinter_program_ttf_ins_sangw :: proc(ctx: ^Hinter_Program_Execution_Context) {
	// NOTE(lucas): not even freetype runs this instruction
}

hinter_program_ttf_ins_aa :: proc(ctx: ^Hinter_Program_Execution_Context) {
	// NOTE(lucas): not even freetype runs this instruction
}

hinter_program_ttf_ins_flippt :: proc(ctx: ^Hinter_Program_Execution_Context) {
	hinter_program_error(ctx, "unimplemented instruction flippt")
}

hinter_program_ttf_ins_fliprgon :: proc(ctx: ^Hinter_Program_Execution_Context) {
	hinter_program_error(ctx, "unimplemented instruction fliprgon")
}

hinter_program_ttf_ins_fliprgoff :: proc(ctx: ^Hinter_Program_Execution_Context) {
	hinter_program_error(ctx, "unimplemented instruction fliprgoff")
}

hinter_program_ttf_ins_scanctrl :: proc(ctx: ^Hinter_Program_Execution_Context) {
	flags := u16(hinter_program_ttf_stack_pop(ctx, 1)[0])
	thresh := u32(flags & 0xFF)
	if thresh == 0xFF {
		ctx.gs.scan_control = true
	} else if thresh == 0 {
		ctx.gs.scan_control = false
	} else {
		if flags & 0x100 != 0 && ctx.program.ppem <= thresh {
			ctx.gs.scan_control = true
		}
		if flags & 0x200 != 0 && ctx.gs.is_rotated {
			ctx.gs.scan_control = true
		}
		if flags & 0x400 != 0 && ctx.gs.is_stretched {
			ctx.gs.scan_control = true
		}
		if flags & 0x800 != 0 && ctx.program.ppem > thresh {
			ctx.gs.scan_control = false
		}
		if flags & 0x1000 != 0 && ! ctx.gs.is_rotated {
			ctx.gs.scan_control = false
		}
		if flags & 0x2000 != 0 && ! ctx.gs.is_stretched {
			ctx.gs.scan_control = false
		}
	}
}

hinter_program_ttf_ins_sdpvtl :: proc(ctx: ^Hinter_Program_Execution_Context) {
	ins := u8(ctx.ins)
	values := hinter_program_ttf_stack_pop(ctx, 2)
	p1_idx := u32(values[0])
	p2_idx := u32(values[1])

	p1 := hinter_program_ttf_get_zp(ctx, ctx.zp2.orig_scaled, p1_idx)
	p2 := hinter_program_ttf_get_zp(ctx, ctx.zp1.orig_scaled, p2_idx)

	ctx.gs.dual_vector = p2 - p1
	if abs(ctx.gs.dual_vector.x) < HINTER_EPS && abs(ctx.gs.dual_vector.y) < HINTER_EPS {
		ctx.gs.dual_vector = { 1, 0 }
		ins = 0
	}

	if ins & 0x1 != 0 {
		ctx.gs.dual_vector.x, ctx.gs.dual_vector.y = -ctx.gs.dual_vector.y, ctx.gs.dual_vector.x
	}
	ctx.gs.dual_vector = linalg.normalize0(ctx.gs.dual_vector)

	p1 = hinter_program_ttf_get_zp(ctx, ctx.zp2.cur, p1_idx)
	p2 = hinter_program_ttf_get_zp(ctx, ctx.zp1.cur, p2_idx)

	ctx.gs.proj_vector = p2 - p1
	if ins & 0x1 != 0 {
		ctx.gs.proj_vector.x, ctx.gs.proj_vector.y = -ctx.gs.proj_vector.y, ctx.gs.proj_vector.x
	}
	ctx.gs.proj_vector = linalg.normalize0(ctx.gs.proj_vector)
}

hinter_program_ttf_ins_getinfo :: proc(ctx: ^Hinter_Program_Execution_Context) {
	selector := u16(hinter_program_ttf_stack_pop(ctx, 1)[0])

	result: i32
	if selector & 0x00000001 != 0 {
		result = HINTER_TTF_SCALAR_VERSION
	}

	// Is the glyph rotated?
	if ((selector & 0x00000002 != 0) && ctx.gs.is_rotated) {
		result |= 1 << 8
	}

	// Is the glyph stretched?
	if ((selector & 0x00000004 != 0) && ctx.gs.is_stretched) {
		result |= 1 << 9
	}

	// Using Windows font smoothing grayscale?
	// Note: FreeType enables this when using grayscale rendering
	if ((selector & 0x00000020 != 0) && ! ctx.gs.is_subpixel_rendering) {
		result |= 1 << 12
	}

	// Using subpixel hinting? 
	// -- Always true in accordance with FreeType's V40 interpreter
	if (selector & 0x00000040) != 0 {
		result |= 1 << 13
	}

	// subpixel positioned?
	// -- Always true in accordance with FreeType's V40 interpreter
	if (selector & 1024) != 0 {
		result |= 1 << 17
	}
	// symmetrical smoothing?
	// -- Always true in accordance with FreeType's non mono font 
	if (selector & 2048) != 0 {
		result |= 1 << 18
	}

		// not using cleartype?
	// -- Always true in accordance with FreeType's non mono font
	if (selector & 4096) != 0 && ctx.program.clear_type_enabled {
		result |= 1 << 19
	}

	hinter_program_ttf_debug_log(ctx, "    get info: %v", result)
	hinter_program_ttf_stack_push(ctx, [1]i32 { result })
}

hinter_program_ttf_ins_idef :: proc(ctx: ^Hinter_Program_Execution_Context) {
	if ctx.stage == .glyph {
		hinter_program_error(ctx, "bad stage")
	}
	if ctx.error {
		return
	}
}

hinter_program_ttf_ins_roll :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 3)
	hinter_program_ttf_stack_push(ctx, [3]i32 { values[1], values[0], values[2] })
}

hinter_program_ttf_ins_max :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	hinter_program_ttf_stack_push(ctx, [1]i32 { i32(max(e2, e1)) })
}

hinter_program_ttf_ins_min :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	hinter_program_ttf_stack_push(ctx, [1]i32 { i32(min(e2, e1)) })
}

hinter_program_ttf_ins_scantype :: proc(ctx: ^Hinter_Program_Execution_Context) {
	val := hinter_program_ttf_stack_pop(ctx, 1)[0]
	if val >= 0 {
		ctx.gs.scan_type = val & 0xFFFF
	}
}

hinter_program_ttf_ins_instctrl :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	k := values[0]
	l := values[1]
	if k < 1 || k > 3 {
		hinter_program_error(ctx, "instctrl error")
		return
	}
	kf := i32(1 << u32(k - 1))
	if l != 0 && l != kf {
		hinter_program_error(ctx, "instctrl error")
		return
	}

	switch ctx.stage {
	case .glyph:
	case .cvt:
		ctx.gs.instruct_control &= ~u8(kf)
		ctx.gs.instruct_control |= u8(l)
	case .font:
		hinter_program_error(ctx, "instctrl error")
	}
}

hinter_program_ttf_ins_getvar :: proc(ctx: ^Hinter_Program_Execution_Context) {
	// NOTE(lucas): apparently this is some weird apple instruction
	hinter_program_error(ctx, "unimplemented instruction getvar")
}

hinter_program_ttf_ins_getdata :: proc(ctx: ^Hinter_Program_Execution_Context) {
	// NOTE(lucas): apparently this is some weird apple instruction
	hinter_program_error(ctx, "unimplemented instruction getdata")
}

hinter_program_ttf_ins_pushb :: proc(ctx: ^Hinter_Program_Execution_Context) {
	count := (u8(ctx.ins) & 0x7) + 1
	for _ in 0..<count {
		v := hinter_program_ttf_instructions_next(ctx)
		hinter_program_ttf_stack_push(ctx, [1]i32 { i32(v) })
	}
}

hinter_program_ttf_ins_pushw :: proc(ctx: ^Hinter_Program_Execution_Context) {
	count := (u8(ctx.ins) & 0x7) + 1
	for _ in 0..<count {
		ms := hinter_program_ttf_instructions_next(ctx)
		ls := hinter_program_ttf_instructions_next(ctx)
		v := i32(i16(u16(ms) << 8 | u16(ls)))
		hinter_program_ttf_stack_push(ctx, [1]i32 { v })
	}
}

hinter_program_ttf_ins_mdrp :: proc(ctx: ^Hinter_Program_Execution_Context) {
	point_idx := u32(hinter_program_ttf_stack_pop(ctx, 1)[0])

	is_twilight_zone := ctx.gs.gep0 == 0 || ctx.gs.gep1 == 0
	rp0_orig, point_orig: [2]f32

	if is_twilight_zone {
		rp0_orig = hinter_program_ttf_get_zp(ctx, ctx.zp0.orig_scaled, ctx.gs.rp0)
		point_orig = hinter_program_ttf_get_zp(ctx, ctx.zp1.orig_scaled, point_idx)
	} else {
		rp0_orig = hinter_program_ttf_get_zp(ctx, ctx.zp0.orig, ctx.gs.rp0)
		point_orig = hinter_program_ttf_get_zp(ctx, ctx.zp1.orig, point_idx)
	}

	rp0_cur := hinter_program_ttf_get_zp(ctx, ctx.zp0.cur, ctx.gs.rp0)
	point_cur := hinter_program_ttf_get_zp(ctx, ctx.zp1.cur, point_idx)

	dist_cur := hinter_program_ttf_project(ctx, point_cur - rp0_cur)
	dist_orig := hinter_program_ttf_dual_project(ctx, point_orig - rp0_orig)

	if ! is_twilight_zone {
		dist_orig = dist_orig * ctx.program.funits_to_pixels_scale
	}

	dist_orig = hinter_program_ttf_apply_single_width_cut_in(ctx, dist_orig)	
	ins := u8(ctx.ins)
	if ins & 0x04 != 0 {
		dist_orig = hinter_program_ttf_round_according_to_state(ctx, dist_orig)
	}

	if ins & 0x08 != 0 {
		dist_orig = hinter_program_ttf_apply_min_dist(ctx, dist_orig)
	}
	hinter_program_ttf_move_point(ctx, ctx.zp1, point_idx, dist_orig - dist_cur, true)
	ctx.gs.rp1 = ctx.gs.rp0
	ctx.gs.rp2 = point_idx
	if ins & 0x10 != 0 {
		ctx.gs.rp0 = point_idx
	}
	hinter_program_ttf_debug_log(ctx, "    rp0 = %v", ctx.gs.rp0)
	hinter_program_ttf_debug_log(ctx, "    rp1 = %v", ctx.gs.rp1)
	hinter_program_ttf_debug_log(ctx, "    rp2 = %v", ctx.gs.rp2)
}

hinter_program_ttf_apply_single_width_cut_in :: proc(ctx: ^Hinter_Program_Execution_Context, value: f32) -> f32 {
	absDiff := abs(value - ctx.gs.single_width_cutin)
	if absDiff < ctx.gs.single_width_cutin {
		if value < 0 {
			return -ctx.gs.single_width_cutin
		}
		return ctx.gs.single_width_cutin
	}
	return value
}

hinter_program_ttf_apply_min_dist :: proc(ctx: ^Hinter_Program_Execution_Context, value: f32) -> f32 {
	if abs(value) < ctx.gs.min_distance {
		if value < 0 {
			return -ctx.gs.min_distance
		}
		return ctx.gs.min_distance
	}
	return value
}

hinter_program_ttf_ins_mirp :: proc(ctx: ^Hinter_Program_Execution_Context) {
	values := hinter_program_ttf_stack_pop(ctx, 2)
	cvt_idx := u32(values[0])
	point_idx := u32(values[1])

	val := hinter_program_ttf_get_cvt(ctx, cvt_idx)
	cvt_val := hinter_program_ttf_apply_single_width_cut_in(ctx, val)

	rp0_orig := hinter_program_ttf_get_zp(ctx, ctx.zp0.orig_scaled, ctx.gs.rp0)
	rp0_cur := hinter_program_ttf_get_zp(ctx, ctx.zp0.cur, ctx.gs.rp0)

	point_orig := hinter_program_ttf_get_zp(ctx, ctx.zp1.orig_scaled, point_idx)
	point_cur := hinter_program_ttf_get_zp(ctx, ctx.zp1.cur, point_idx)
	if ctx.gs.gep1 == 0 {
		point_orig = rp0_orig + cvt_val * ctx.gs.free_vector
		point_cur = point_orig
		hinter_program_ttf_set_zp(ctx, ctx.zp1.orig_scaled, point_idx, point_orig)
		hinter_program_ttf_set_zp(ctx, ctx.zp1.cur, point_idx, point_cur)
	}

	dist_cur := hinter_program_ttf_project(ctx, point_cur - rp0_cur)
	dist_orig := hinter_program_ttf_dual_project(ctx, point_orig - rp0_orig)

	if ctx.gs.auto_flip {
		if ! hinter_program_same_sign(dist_orig, cvt_val) {
			cvt_val = -cvt_val
		}
	}

	dist_new: f32
	ins := u8(ctx.ins)
	if ins & 0x4 != 0 {
		if ctx.gs.gep0 == ctx.gs.gep1 {
			if abs(cvt_val - dist_orig) > ctx.gs.control_value_cutin {
				cvt_val = dist_orig
			}
		}
		dist_new = hinter_program_ttf_round_according_to_state(ctx, cvt_val)
	} else {
		dist_new = cvt_val
	}

	if ins & 0x8 != 0 {
		if dist_orig >= 0 {
			if dist_new < ctx.gs.min_distance {
				dist_new = ctx.gs.min_distance
			}
		} else {
			if dist_new > -ctx.gs.min_distance {
				dist_new = -ctx.gs.min_distance
			}
		}
	}

	hinter_program_ttf_move_point(ctx, ctx.zp1, point_idx, dist_new - dist_cur, true)
	ctx.gs.rp1 = ctx.gs.rp0
	ctx.gs.rp2 = point_idx
	if ins & 0x10 != 0 {
		ctx.gs.rp0 = point_idx
	}
	hinter_program_ttf_debug_log(ctx, "    rp0 = %v", ctx.gs.rp0)
	hinter_program_ttf_debug_log(ctx, "    rp1 = %v", ctx.gs.rp1)
	hinter_program_ttf_debug_log(ctx, "    rp2 = %v", ctx.gs.rp2)
}

hinter_program_context_make :: proc(program: ^Hinter_Program, stage: Ttf_Hinter_Stage, is_compound_glyph: bool, debug: bool, instructions: []byte, scratch: mem.Allocator) -> Hinter_Program_Execution_Context {
	program_ctx: Hinter_Program_Execution_Context
	program_ctx.program = program
	program_ctx.is_compound_glyph = is_compound_glyph
	program_ctx.stage = stage
	program_ctx.gs = HINTER_PROGRAM_TTF_GRAPHICS_STATE_DEFAULT
	program_ctx.zp0 = &program.zone1
	program_ctx.zp1 = &program.zone1
	program_ctx.zp2 = &program.zone1
	program_ctx.stack = { program.stack_data, 0 }
	program_ctx.instructions = { instructions, 0 }
	program_ctx.debug = debug
	program_ctx.storage = stage == .glyph ? slice.clone(program.storage, scratch) : program.storage

	return program_ctx
}

hinter_program_load_font_wide_program :: proc(font: ^ttf.Font) -> (^Hinter_Font_Wide_Data, bool) {
	_load :: proc(f: ^ttf.Font) -> (ttf.Table_Entry, ttf.Font_Error) {
		maxp, ok := ttf.get_table(f, .maxp, ttf.load_maxp_table, ttf.Maxp_Table)
		if ! ok {
			return {}, .Missing_Required_Table
		}
		base_ptr, font_data, shared_instructions, err := memory.make_multi(
			memory.Make_Multi(^Hinter_Font_Wide_Data) {},
			memory.Make_Multi([][]byte) { len = int(maxp.data.v1_0.max_function_defs) },
			f.allocator,
		)
		if err != nil {
			return {}, .Unknown
		}

		// NOTE(lucas): some fonts lie about their stack size and report a number too small
		// just add 32 for safety
		font_data.stack_size = i32(maxp.data.v1_0.max_stack_elements) + 32
		font_data.zone_0_size = i32(maxp.data.v1_0.max_twilight_points)
		font_data.storage_size = i32(maxp.data.v1_0.max_storage)
		font_data.shared_instructions = shared_instructions
		
		scratch := memory.arena_scratch({})
		program: Hinter_Program	
		program.shared_intructions = font_data.shared_instructions
		program.stack_data = make([]i32, font_data.stack_size, scratch)

		fpgm, _ := ttf.get_table_data(f, .fpgm)

		program_ctx := hinter_program_context_make(&program, .font, false, false, fpgm, {})
		font_data.bad_font_program = ! hinter_program_ttf_execute(&program_ctx)
		return { font_data }, nil
	}
	return ttf.get_table(font, .fpgm, _load, Hinter_Font_Wide_Data)
}

hinter_program_make :: proc(font: ^ttf.Font, pt_size: f32, dpi: f32, allocator: mem.Allocator, debug := false) -> (^Hinter_Program, bool) {
	if .HINTING not_in font.features {
		return {}, false
	}

	font_data, has_font_data := hinter_program_load_font_wide_program(font)
	if ! has_font_data || font_data.bad_font_program {
		return {}, false
	}

	ppem := max(math.round((pt_size * dpi) / 72), 0)
	if ppem == 0 {
		return {}, false
	}

	raw_cvt, _ := ttf.get_table_data(font, .cvt)
	cvt_table := slice.reinterpret([]i16be, raw_cvt)

	base, program, cvt, storage, zone_0_orig_scaled, zone_0_cur, zone_0_touch, stack_data, alloc_err :=
		make_multi(
			Make_Multi(^Hinter_Program) {},
			Make_Multi([]f32) { len = len(cvt_table) },
			Make_Multi([]i32) { len = int(font_data.storage_size) },
			Make_Multi([][2]f32) { len = int(font_data.zone_0_size) },
			Make_Multi([][2]f32) { len = int(font_data.zone_0_size) },
			Make_Multi([]u8) { len = int(font_data.zone_0_size) },
			Make_Multi([]i32) { len = int(font_data.stack_size) },
			allocator,
		)
	if alloc_err != nil {
		return {}, false
	}
	ok := false
	defer if ! ok {
		free(base, allocator)
	}

	program.font = font
	program.cvt = cvt
	program.storage = storage
	program.zone0.orig_scaled = zone_0_orig_scaled
	program.zone0.cur = zone_0_cur
	program.zone0.touch = zone_0_touch
	program.stack_data = stack_data
	program.shared_intructions = font_data.shared_instructions
	program.ppem = u32(ppem)
	program.point_size = pt_size
	program.clear_type_enabled = true
	program.funits_to_pixels_scale = f32(f32(u32(ppem)) / f32(font.units_per_em))
	program.base_ptr = base
	program.allocator = allocator

	for _, i in cvt_table {
		program.cvt[i] = f32(u32(cvt_table[i])) * program.funits_to_pixels_scale
	}

	prep, _ := ttf.get_table_data(font, .prep)
	program_ctx := hinter_program_context_make(program, .cvt, false, debug, prep, {})

	if ! hinter_program_ttf_execute(&program_ctx) {
		return {}, false
	}
	ok = true
	return program, true
}

hinter_program_delete :: proc(hinter: ^Hinter_Program) {
	if hinter != nil {
		free(hinter.base_ptr, hinter.allocator)
	}
}

hinter_program_same_sign :: proc(a, b: f32) -> bool {
	if a < 0 {
		return b < 0
	} else {
		return b >= 0
	}
}

hinter_program_hint_glyph :: proc(program: ^Hinter_Program, glyph_id: ttf.Glyph, allocator: mem.Allocator, debug := false) -> (ttf.Extracted_Simple_Glyph, bool) {
	scratch := memory.arena_scratch({ allocator })

	glyphs_to_hint := make([dynamic]Glyph_Job, 0, 8, scratch)
	gather_glyphs_jobs(&glyphs_to_hint, program.font, glyph_id, ttf.IDENTITY_MATRIX, false, scratch)
	if len(glyphs_to_hint) == 0 {
			return { glyph_id = glyph_id }, true
	}

	PHANTOM_POINTS :: 4
	points_needed := PHANTOM_POINTS
	contour_lengths_needed := 0
	for g in glyphs_to_hint {
		switch glyph in g.glyph {
		case ttf.Extracted_Simple_Glyph:
			points_needed += len(glyph.points)
			contour_lengths_needed += len(glyph.contour_endpoints)
		case ttf.Extracted_Compound_Glyph:
		}
	}

	on_curves := make([]bool, points_needed, scratch)
	cur := make([][2]f32, points_needed, scratch)
	orig := make([][2]f32, points_needed, scratch)
	orig_scaled := make([][2]f32, points_needed, scratch)
	touch := make([]u8, points_needed, scratch)
	end_point_indices := make([]u32, contour_lengths_needed, scratch)
	winding_fixup := make([]bool, len(glyphs_to_hint), scratch)

	offset_coords := 0
	offset_points := 0
	last_local_end_point := u32(0)
	for g, glyph_i in glyphs_to_hint {
		is_compound: bool
		glyph_end_points: []u16
		glyph_points: [][2]i16
		glyph_on_curves: []bool
		glyph_instructions: []byte
		switch glyph in g.glyph {
		case ttf.Extracted_Simple_Glyph:
			is_compound = false
			glyph_points = glyph.points
			glyph_end_points = glyph.contour_endpoints
			glyph_on_curves = glyph.on_curve
			glyph_instructions = glyph.instructions
		case ttf.Extracted_Compound_Glyph:
			is_compound = true
			glyph_instructions = glyph.instructions
			compound_min: [2]f32 = math.INF_F32
			compound_max: [2]f32 = math.NEG_INF_F32
		}

		offset_points_start := offset_points
		offset_coords_start := offset_coords
		if is_compound {
			offset_points_start -= g.child_contour_length
			assert(offset_points_start >= 0)
			if offset_points_start == 0 {
				offset_coords_start = 0
			} else {
				offset_coords_start = int(end_point_indices[offset_points_start - 1]) + 1
			}
		}
		offset_coords_end := offset_coords + PHANTOM_POINTS + len(glyph_points)
		offset_points_end := offset_points + len(glyph_end_points)

		local_cur := cur[offset_coords_start:offset_coords_end]
		local_org := orig[offset_coords_start:offset_coords_end]
		local_org_scaled := orig_scaled[offset_coords_start:offset_coords_end]
		local_touch := touch[offset_coords_start:offset_coords_end]
		mem.zero_slice(local_touch)

		local_end_points := end_point_indices[offset_points_start:offset_points_end]

		local_on_curves := on_curves[offset_coords_start:offset_coords_end]

		program.zone1.cur = local_cur
		program.zone1.orig = local_org
		program.zone1.orig_scaled = local_org_scaled
		program.zone1.touch = local_touch
		program.zone1.end_points = local_end_points

		if ! is_compound {
			for u, i in glyph_end_points {
				program.zone1.end_points[i] = u32(u)
			}
			copy(local_on_curves, glyph_on_curves)

			for i in 0..<len(glyph_points) {
				program.zone1.orig[i] = { f32(glyph_points[i].x), f32(glyph_points[i].y) }
			}
		}

		org_end := len(program.zone1.orig)
		// NOTE(lucas): fill in phantom points
		metrics, _ := ttf.get_metrics(program.font, g.glyph_id)
		lsb := f32(metrics.lsb)
		tsb := f32(metrics.tsb)
		advance_x := f32(metrics.advance_width)
		advance_y := f32(metrics.advance_height)

		program.zone1.orig[org_end - 4] = { f32(metrics.bbox.min.x) - lsb, 0 }
		program.zone1.orig[org_end - 3] = { f32(metrics.bbox.min.x) - lsb + advance_x, 0 }
		program.zone1.orig[org_end - 2] = { 0, f32(metrics.bbox.max.y) + tsb }
		program.zone1.orig[org_end - 1] = { 0, f32(metrics.bbox.max.y) + tsb - advance_y }

		if is_compound {
			for i in org_end - 4..<org_end {
				program.zone1.orig_scaled[i] = program.zone1.orig[i] * program.funits_to_pixels_scale
			}

			copy(program.zone1.orig_scaled[:org_end-4], program.zone1.cur[:org_end-4])
			copy(program.zone1.cur[org_end-4:], program.zone1.orig_scaled[org_end-4:])
		} else {
			for i in 0..<len(program.zone1.orig) {
				program.zone1.orig_scaled[i] = program.zone1.orig[i] * program.funits_to_pixels_scale
			}

			copy(program.zone1.cur, program.zone1.orig_scaled)
		}

		// NOTE(lucas): round phantom points
		program.zone1.cur[org_end - 4].x = math.round(program.zone1.cur[org_end - 4].x)
		program.zone1.cur[org_end - 3].x = math.round(program.zone1.cur[org_end - 3].x)
		program.zone1.cur[org_end - 2].y = math.round(program.zone1.cur[org_end - 2].y)
		program.zone1.cur[org_end - 1].y = math.round(program.zone1.cur[org_end - 1].y)

		if len(glyph_instructions) > 0 {
			memory.scratch_temp_scope(scratch)
			program_ctx := hinter_program_context_make(program, .glyph, is_compound, debug, glyph_instructions, scratch)

			when HINTER_DEBUG_ENABLED {
				if debug {
					log.info("---- original scaled ------")
					for c in program.zone1.cur {
						log.info(c)
					}
				}
			}

			if ! hinter_program_ttf_execute(&program_ctx) {
				return {}, false
			}

			when HINTER_DEBUG_ENABLED {
				if debug {
					log.info("---- hinted ------")
					for c in program.zone1.cur {
						log.info(c)
					}
				}
			}
		}

		if ! is_compound {
			for &p in local_end_points {
				p += u32(last_local_end_point)
			}
			if len(end_point_indices) > 0 {
				last_local_end_point = end_point_indices[offset_points_end - 1] + 1
			}
		}

		if g.transform != ttf.IDENTITY_MATRIX {
			local_transform := g.transform
			local_transform[0, 2] *= f32(program.funits_to_pixels_scale)
			local_transform[1, 2] *= f32(program.funits_to_pixels_scale)
			// NOTE(lucas): we only hint on the y axis therefore we only round on the y axis
			if g.round_transform {
				local_transform[1, 2] = math.round(local_transform[1, 2])
			}

			for &p in local_cur {
				p = transform_coordinate(local_transform, p)
			}
			// NOTE(lucas): the local original is in funits and has no rounding so use original transform
			for &p in local_org {
				p = transform_coordinate(g.transform, p)
			}

			if ! hinter_program_same_sign(local_transform[0, 0], local_transform[1, 1]) {
				group_to_wind := winding_fixup[glyph_i - g.child_length + 1:glyph_i + 1]
				for &wind in group_to_wind {
					wind = ! wind
				}
			}
		}

		offset_coords += len(glyph_points)
		offset_points += len(glyph_end_points)
	}

	// NOTE(lucas): now fixup winding
	offset_coords = 0
	for g, glyph_i in glyphs_to_hint {
		offset_coords_start := offset_coords
		offset_coords_end := offset_coords_start

		if simple_glyph, is_simple := g.glyph.(ttf.Extracted_Simple_Glyph); is_simple {
			 offset_coords_end += len(simple_glyph.points)
		}

		local_cur := cur[offset_coords_start:offset_coords_end]
		local_on_curves := on_curves[offset_coords_start:offset_coords_end]
		if winding_fixup[glyph_i] {
			slice.reverse(local_cur)
			slice.reverse(local_on_curves)
		}
		offset_coords = offset_coords_end
	}

	min: [2]f32 = math.INF_F32
	max: [2]f32 = math.NEG_INF_F32
	for &c in cur[:len(cur)-PHANTOM_POINTS] {
		c /= program.funits_to_pixels_scale
		min = linalg.min(c, min)
		max = linalg.max(c, max)
	}
	if min.x == math.INF_F32 || min.y == math.INF_F32 || max.x == math.NEG_INF_F32 || max.y == math.NEG_INF_F32 {
		min = 0
		max = 0
	}

	result: ttf.Extracted_Simple_Glyph
	result.glyph_id = glyph_id
	result.points = make([][2]i16, len(cur) - PHANTOM_POINTS, allocator)
	for &p, i in result.points {
		c := cur[i]
		p = { i16(c.x), i16(c.y) }
	}
	result.on_curve = make([]bool, len(on_curves) - PHANTOM_POINTS, allocator)
	copy(result.on_curve, on_curves)
	result.contour_endpoints = make([]u16, len(end_point_indices), allocator)
	for &e, i in result.contour_endpoints {
		assert(end_point_indices[i] <= 0xFFFF)
		e = u16(end_point_indices[i])
	}

	result.bounds = {
		{ i16(min.x), i16(min.y) },
		{ i16(max.x), i16(max.y) },
	}

	return result, true
}

Glyph_Job :: struct {
	glyph_id: ttf.Glyph,
	glyph: ttf.Extracted_Glyph,
	transform: matrix[2, 3]f32,
	child_contour_length: int,
	child_length: int,
	round_transform: bool,
}

gather_glyphs_jobs :: proc(glyphs_to_hint: ^[dynamic]Glyph_Job, font: ^ttf.Font, glyph_id: ttf.Glyph, transform: matrix[2, 3]f32, round_transform: bool, allocator: runtime.Allocator) -> (int, int) {
	glyf_table, err := ttf.load_glyf_table(font)
	if err != nil {
		return 0, 0
	}

	g, ok := ttf.get_extracted_glyph(font, glyph_id, allocator)
	child_contour_length := 0
	child_length := 1
	if ok {
		switch glyph in g {
		case ttf.Extracted_Simple_Glyph:
				child_contour_length += len(glyph.contour_endpoints)
		case ttf.Extracted_Compound_Glyph:
			for c in glyph.components {
				contour_len, child_len := gather_glyphs_jobs(glyphs_to_hint, font, c.glyph_id, c.transform, c.round_to_grid, allocator)
				child_contour_length += contour_len
				child_length += child_len
			}
		}
		append(glyphs_to_hint, Glyph_Job { glyph_id, g, transform, child_contour_length, child_length, round_transform })
	}
	return child_contour_length, child_length
}

transform_coordinate :: proc(transform: matrix[2, 3]f32, coordinate: [2]f32) -> [2]f32 {
	return transform * [3]f32 { coordinate.x, coordinate.y, 1 }
}


