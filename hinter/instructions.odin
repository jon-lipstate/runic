package runic_hinter

import "core:math/linalg"
import "core:mem"


ins_sxytca :: proc(ctx: ^Execution_Context) {
	ins_as_i16 := i16(ctx.ins)
	aa, bb: i16
	aa = (ins_as_i16 & 1) << 14
	bb = aa ~ 0x4000

	aa_f32 := f2dot14_to_f32(aa)
	bb_f32 := f2dot14_to_f32(bb)

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


ins_sxvtl :: proc(ctx: ^Execution_Context, idx_1: u32, idx_2: u32) -> [2]f32 {
	ins := u8(ctx.ins)

	p1 := zp_get(ctx, ctx.zp1.cur, idx_1)
	p2 := zp_get(ctx, ctx.zp2.cur, idx_2)

	delta := p1 - p2

	norm := norm_f32(delta)
	if ins & 1 != 0 {
		norm = {-norm.y, norm.x}
	}

	return norm
}

ins_spvtl :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	v := ins_sxvtl(ctx, u32(values[0]), u32(values[1]))
	ctx.gs.proj_vector = v
	ctx.gs.dual_vector = v
}

ins_sfvtl :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	v := ins_sxvtl(ctx, u32(values[0]), u32(values[1]))
	ctx.gs.free_vector = v
}

ins_spvfs :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	y := f2dot14_to_f32(i16(values[0]))
	x := f2dot14_to_f32(i16(values[1]))

	norm := norm_f32({x, y})

	ctx.gs.proj_vector = norm
	ctx.gs.dual_vector = norm
}

ins_sfvfs :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	y := f2dot14_to_f32(i16(values[0]))
	x := f2dot14_to_f32(i16(values[1]))

	norm := norm_f32({x, y})

	ctx.gs.free_vector = norm

}

ins_gpv :: proc(ctx: ^Execution_Context) {
	values := [2]i32 {
		i32(f32_to_f2dot14(ctx.gs.proj_vector.x)),
		i32(f32_to_f2dot14(ctx.gs.proj_vector.y)),
	}
	stack_push(ctx, values)
}

ins_gfv :: proc(ctx: ^Execution_Context) {
	values := [2]i32 {
		i32(f32_to_f2dot14(ctx.gs.free_vector.x)),
		i32(f32_to_f2dot14(ctx.gs.free_vector.y)),
	}
	stack_push(ctx, values)
}

ins_sfvtpv :: proc(ctx: ^Execution_Context) {
	ctx.gs.free_vector = ctx.gs.proj_vector
}

ins_isect :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 5)

	b1_i := u32(values[0])
	b0_i := u32(values[1])
	a1_i := u32(values[2])
	a0_i := u32(values[3])
	point := u32(values[4])

	a0 := zp_get(ctx, ctx.zp1.cur, a0_i)
	a1 := zp_get(ctx, ctx.zp1.cur, a1_i)
	b0 := zp_get(ctx, ctx.zp0.cur, b0_i)
	b1 := zp_get(ctx, ctx.zp0.cur, b1_i)

	denom := (a0.x - a1.x) * (b0.y - b1.y) - (a0.y - a1.y) * (b0.x - b1.x)
	if abs(denom) > HINTER_EPS {
		a_cross := linalg.cross(a0, a1)
		b_cross := linalg.cross(b0, b1)

		val := (a_cross * (b0 - b1) - b_cross * (a0 - a1)) / denom
		zp_set(ctx, ctx.zp2.cur, point, val)
	} else {
		zp_set(ctx, ctx.zp2.cur, point, (a0 + a1 + b0 + b1) / 4)
	}

	zp_or(ctx, ctx.zp2.touch, point, TTF_HINTER_TOUCH_XY)
}

ins_srp0 :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 1)
	ctx.gs.rp0 = u32(values[0])
	debug_log(ctx, "    rp0 = %v", ctx.gs.rp0)
}

ins_srp1 :: proc(ctx: ^Execution_Context) {
	value := stack_pop(ctx, 1)[0]
	ctx.gs.rp1 = u32(value)
	debug_log(ctx, "    rp1 = %v", ctx.gs.rp1)
}

ins_srp2 :: proc(ctx: ^Execution_Context) {
	value := stack_pop(ctx, 1)[0]
	ctx.gs.rp2 = u32(value)
	debug_log(ctx, "    rp2 = %v", ctx.gs.rp2)
}


ins_szp0 :: proc(ctx: ^Execution_Context) {
	value := u32(stack_pop(ctx, 1)[0])
	set_zone(ctx, &ctx.zp0, value)
	ctx.gs.gep0 = u16(value)
}

ins_szp1 :: proc(ctx: ^Execution_Context) {
	value := u32(stack_pop(ctx, 1)[0])
	set_zone(ctx, &ctx.zp1, value)
	ctx.gs.gep1 = u16(value)
}

ins_szp2 :: proc(ctx: ^Execution_Context) {
	value := u32(stack_pop(ctx, 1)[0])
	set_zone(ctx, &ctx.zp2, value)
	ctx.gs.gep2 = u16(value)
}

ins_szps :: proc(ctx: ^Execution_Context) {
	value := u32(stack_pop(ctx, 1)[0])
	set_zone(ctx, &ctx.zp0, value)
	set_zone(ctx, &ctx.zp1, value)
	set_zone(ctx, &ctx.zp2, value)
	ctx.gs.gep0 = u16(value)
	ctx.gs.gep1 = u16(value)
	ctx.gs.gep2 = u16(value)
}

ins_sloop :: proc(ctx: ^Execution_Context) {
	value := stack_pop(ctx, 1)[0]
	ctx.gs.loop = min(value, 0xFFFF)
}

ins_rtg :: proc(ctx: ^Execution_Context) {
	ctx.gs.round_state = .to_grid
}

ins_rthg :: proc(ctx: ^Execution_Context) {
	ctx.gs.round_state = .to_half_grid
}

ins_smd :: proc(ctx: ^Execution_Context) {
	value := stack_pop(ctx, 1)[0]
	ctx.gs.min_distance = f26dot6_to_f32(value)
}


ins_else :: proc(ctx: ^Execution_Context) {
	n_ifs := 1
	for n_ifs != 0 {
		skip_code(ctx)
		if ctx.error {
			return
		}
		#partial switch ctx.ins {
		case .ins_if:
			n_ifs += 1
		case .ins_eif:
			n_ifs -= 1
		}
	}
	// NOTE(lucas): eat last eif
	instructions_next(ctx)
}

ins_jmpr :: proc(ctx: ^Execution_Context) {
	value := stack_pop(ctx, 1)[0]
	instructions_jump(ctx, value)
}

ins_scvtci :: proc(ctx: ^Execution_Context) {
	value := stack_pop(ctx, 1)[0]
	ctx.gs.control_value_cutin = f26dot6_to_f32(value)
}

ins_sswci :: proc(ctx: ^Execution_Context) {
	value := stack_pop(ctx, 1)[0]
	ctx.gs.single_width_cutin = f26dot6_to_f32(value)
}

ins_ssw :: proc(ctx: ^Execution_Context) {
	value := stack_pop(ctx, 1)[0]
	ctx.gs.single_width_cutin = f26dot6_to_f32(value) * ctx.program.funits_to_pixels_scale
}

ins_dup :: proc(ctx: ^Execution_Context) {
	value := stack_pop(ctx, 1)[0]
	stack_push(ctx, [2]i32{value, value})
}

ins_pop :: proc(ctx: ^Execution_Context) {
	stack_pop(ctx, 1)
}

ins_clear :: proc(ctx: ^Execution_Context) {
	ctx.stack.count = 0
}

ins_swap :: proc(ctx: ^Execution_Context) {
	stack_push(ctx, stack_pop(ctx, 2))
}

ins_depth :: proc(ctx: ^Execution_Context) {
	stack_push(ctx, [1]i32{i32(ctx.stack.count)})
}

ins_cindex :: proc(ctx: ^Execution_Context) {
	value := stack_pop(ctx, 1)[0]
	offset := ctx.stack.count - int(value)
	if offset < 0 || offset >= ctx.stack.count {
		program_error(ctx, "Stack read OOB")
		return
	}
	stack_push(ctx, [1]i32{ctx.stack.data[offset]})
}

ins_mindex :: proc(ctx: ^Execution_Context) {
	value := stack_pop(ctx, 1)[0]
	offset := ctx.stack.count - int(value)
	if offset < 0 || offset >= ctx.stack.count {
		program_error(ctx, "Stack read OOB")
		return
	}
	move := ctx.stack.data[offset]
	copy(ctx.stack.data[offset:], ctx.stack.data[offset + 1:])
	ctx.stack.data[ctx.stack.count - 1] = move
}

ins_alignpts :: proc(ctx: ^Execution_Context) {
	points := stack_pop(ctx, 2)

	p1 := u32(points[1])
	p2 := u32(points[0])

	v1 := zp_get(ctx, ctx.zp1.cur, p1)
	v2 := zp_get(ctx, ctx.zp2.cur, p2)

	distance := project(ctx, v2 - v1) / 2

	// func_move
	move_point(ctx, ctx.zp1, p1, distance, true)
	move_point(ctx, ctx.zp0, p2, -distance, true)
}

ins_utp :: proc(ctx: ^Execution_Context) {
	point := u32(stack_pop(ctx, 1)[0])
	mask := u8(0xFF)
	if ctx.gs.free_vector.x != 0 {
		mask &= ~TTF_HINTER_TOUCH_X
	}
	if ctx.gs.free_vector.y != 0 {
		mask &= ~TTF_HINTER_TOUCH_Y
	}
	zp_and(ctx, ctx.zp0.touch, point, mask)
}

ins_loopcall :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	func_id := u32(values[0])
	count := values[1]
	call_func(ctx, func_id, count)
}

ins_call :: proc(ctx: ^Execution_Context) {
	func_id := u32(stack_pop(ctx, 1)[0])
	call_func(ctx, func_id, 1)
}

ins_fdef :: proc(ctx: ^Execution_Context) {
	func_id := u32(stack_pop(ctx, 1)[0])
	if func_id < 0 || i64(func_id) >= i64(len(ctx.program.shared_intructions)) {
		program_error(ctx, "execute invalid instruction stream")
	}
	ins_start := instructions_ptr_next(ctx)
	len := 1
	for instructions_next(ctx) != .ins_endf && !ctx.error {
		len += 1
	}
	if ctx.error {
		return
	}
	ctx.program.shared_intructions[func_id] = mem.slice_ptr(ins_start, len)
}

ins_endf :: proc(ctx: ^Execution_Context) {
	// NOTE(lucas): no op
}

ins_mdap :: proc(ctx: ^Execution_Context) {
	ins := u8(ctx.ins)

	point := u32(stack_pop(ctx, 1)[0])
	distance: f32
	if ins & 0x1 != 0 {
		v := zp_get(ctx, ctx.zp0.cur, point)
		d := project(ctx, v)
		distance = round_according_to_state(ctx, d) - d
	} else {
		distance = 0
	}
	move_point(ctx, ctx.zp0, point, distance, true)

	ctx.gs.rp0 = point
	ctx.gs.rp1 = point
	debug_log(ctx, "    rp0 = %v", ctx.gs.rp0)
	debug_log(ctx, "    rp1 = %v", ctx.gs.rp1)
}

ins_iup :: proc(ctx: ^Execution_Context) {
	ins := u8(ctx.ins)
	if ctx.zp2 == &ctx.program.zone0 {
		program_error(ctx, "Invalid IUP zone")
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
		for point_idx <= end_point_idx && zp_get(ctx, ctx.program.zone1.touch, point_idx) & touch_flag == 0 {
			point_idx += 1
		}

		if point_idx <= end_point_idx {
			first_touched_idx := point_idx
			current_touched_idx := point_idx

			point_idx += 1

			for point_idx <= end_point_idx {
				if zp_get(ctx, ctx.program.zone1.touch, point_idx) & touch_flag != 0 {
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
					interpolate_or_shift(
						ctx,
						axis,
						start_point_idx,
						end_point_idx,
						touch_0,
						point_idx,
					)

					finding_touch_1 =
						point_idx != end_point_idx ||
						ctx.program.zone1.touch[start_point_idx] & touch_flag == 0
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
			for i in start_point_idx ..= touch_0 {
				if ctx.program.zone1.touch[i] & touch_flag != 0 {
					interpolate_or_shift(ctx, axis, start_point_idx, end_point_idx, touch_0, i)
					break
				}
			}
		}
	}
}


ins_shp :: proc(ctx: ^Execution_Context) {
	d, _, _ := compute_point_displacement(ctx)
	if ctx.error {
		return
	}

	for _ in 0 ..< ctx.gs.loop {
		point := u32(stack_pop(ctx, 1)[0])
		move_point(ctx, ctx.zp2, point, d, true)
	}
	ctx.gs.loop = 1
}

ins_shc :: proc(ctx: ^Execution_Context) {
	contour := u32(stack_pop(ctx, 1)[0])
	d, ref_zone, ref_p := compute_point_displacement(ctx)
	if ctx.error {
		return
	}
	if ref_zone != ctx.zp2 {
		ref_p = 0xFFFFFFFF
	}

	start := u32(0)
	limit := u32(0)
	if contour != 0 {
		start = zp_get(ctx, ctx.zp2.end_points, contour - 1) + 1
	}
	if ctx.gs.gep2 == 0 {
		limit = u32(len(ctx.zp2.end_points))
	} else {
		limit = zp_get(ctx, ctx.zp2.end_points, contour) + 1
	}

	for i := start; i < limit; i += 1 {
		if i != ref_p {
			move_point(ctx, ctx.zp2, i, d, true)
		}
	}
}

ins_shz :: proc(ctx: ^Execution_Context) {
	contour := u32(stack_pop(ctx, 1)[0])
	d, ref_zone, ref_p := compute_point_displacement(ctx)
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
		limit = zp_get(ctx, ctx.zp2.end_points, contour)
	}

	for i := u32(0); i < limit; i += 1 {
		if i != ref_p {
			move_point(ctx, ctx.zp2, i, d, false)
		}
	}
}


ins_shpix :: proc(ctx: ^Execution_Context) {
	amt := f2dot14_to_f32(i16(stack_pop(ctx, 1)[0]))
	is_twilight_zone := is_twilight_zone(ctx)

	for _ in 0 ..< ctx.gs.loop {
		point_idx := u32(stack_pop(ctx, 1)[0])
		should_move := is_twilight_zone
		if !should_move && ctx.iup_state != TTF_HINTER_TOUCH_XY {
			should_move =
				(ctx.is_compound_glyph && ctx.gs.free_vector.y != 0) ||
				(zp_get(ctx, ctx.zp2.touch, point_idx) & TTF_HINTER_TOUCH_Y != 0)
		}

		if should_move {
			move_point(ctx, ctx.zp2, point_idx, amt, true)
		}
	}
	ctx.gs.loop = 1
}

ins_ip :: proc(ctx: ^Execution_Context) {
	rp1_cur := zp_get(ctx, ctx.zp0.cur, ctx.gs.rp1)
	rp2_cur := zp_get(ctx, ctx.zp1.cur, ctx.gs.rp2)

	rp1_orig, rp2_orig: [2]f32

	is_twilight_zone := is_twilight_zone(ctx)
	if is_twilight_zone {
		rp1_orig = zp_get(ctx, ctx.zp0.orig_scaled, ctx.gs.rp1)
		rp2_orig = zp_get(ctx, ctx.zp1.orig_scaled, ctx.gs.rp2)
	} else {
		rp1_orig = zp_get(ctx, ctx.zp0.orig, ctx.gs.rp1)
		rp2_orig = zp_get(ctx, ctx.zp1.orig, ctx.gs.rp2)
	}

	total_dist_cur := project(ctx, rp2_cur - rp1_cur)
	total_dist_orig := dual_project(ctx, rp2_orig - rp1_orig)

	for _ in 0 ..< ctx.gs.loop {
		point_idx := u32(stack_pop(ctx, 1)[0])

		point_cur := zp_get(ctx, ctx.zp2.cur, point_idx)
		zp_target := is_twilight_zone ? ctx.zp2.orig_scaled : ctx.zp2.orig
		point_orig := zp_get(ctx, zp_target, point_idx)

		dist_cur := project(ctx, point_cur - rp1_cur)
		dist_orig := dual_project(ctx, point_orig - rp1_orig)
		dist_new := f32(0)
		if abs(total_dist_orig) > 0 {
			dist_new = (dist_orig * total_dist_cur) / total_dist_orig
		} else {
			dist_new = dist_orig
		}
		move_point(ctx, ctx.zp2, point_idx, dist_new - dist_cur, true)
	}

	ctx.gs.loop = 1
}

ins_msirp :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)

	distance := f26dot6_to_f32(values[0])
	point := u32(values[1])

	if ctx.gs.gep1 == 0 {
		orig := zp_get(ctx, ctx.zp0.orig, ctx.gs.rp0)
		zp_set(ctx, ctx.zp1.orig, point, orig)
		move_point_orig(ctx, ctx.zp1, point, distance)
		zp_set(ctx, ctx.zp1.cur, point, orig)
	}

	zp0_cur := zp_get(ctx, ctx.zp0.cur, ctx.gs.rp0)
	zp1_cur := zp_get(ctx, ctx.zp1.cur, point)
	distance_proj := project(ctx, zp1_cur - zp0_cur)
	move_point(ctx, ctx.zp1, point, distance - distance_proj, true)

	ctx.gs.rp1 = ctx.gs.rp0
	ctx.gs.rp2 = point

	if u8(ctx.ins) & 0x1 != 0 {
		ctx.gs.rp0 = point
	}
	debug_log(ctx, "    rp0 = %v", ctx.gs.rp0)
	debug_log(ctx, "    rp1 = %v", ctx.gs.rp1)
	debug_log(ctx, "    rp2 = %v", ctx.gs.rp2)
}

ins_alignrp :: proc(ctx: ^Execution_Context) {
	rp0_cur := zp_get(ctx, ctx.zp0.cur, ctx.gs.rp0)
	for _ in 0 ..< ctx.gs.loop {
		point_idx := u32(stack_pop(ctx, 1)[0])
		cur := zp_get(ctx, ctx.zp1.cur, point_idx)
		dist := project(ctx, rp0_cur - cur)
		move_point(ctx, ctx.zp1, point_idx, dist, true)
	}
	ctx.gs.loop = 1
}

ins_rtdg :: proc(ctx: ^Execution_Context) {
	ctx.gs.round_state = .to_double_grid
}

ins_miap :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	cvt_idx := u32(values[0])
	point_idx := u32(values[1])

	new_dist := get_cvt(ctx, cvt_idx)
	cur: [2]f32
	if ctx.gs.gep0 == 0 {
		cur = new_dist * ctx.gs.free_vector
		zp_set(ctx, ctx.zp0.orig_scaled, point_idx, cur)
		zp_set(ctx, ctx.zp0.cur, point_idx, cur)
	} else {
		cur = zp_get(ctx, ctx.zp0.cur, point_idx)
	}

	cur_dist := project(ctx, cur)
	ins := u8(ctx.ins)
	if ins & 0x1 != 0 {
		if abs(new_dist - cur_dist) > ctx.gs.control_value_cutin {
			new_dist = cur_dist
		}
		new_dist = round_according_to_state(ctx, new_dist)
	}
	move_point(ctx, ctx.zp0, point_idx, new_dist - cur_dist, true)

	ctx.gs.rp0 = point_idx
	ctx.gs.rp1 = point_idx
	debug_log(ctx, "    rp0 = %v", ctx.gs.rp0)
	debug_log(ctx, "    rp1 = %v", ctx.gs.rp1)
}

ins_npushb :: proc(ctx: ^Execution_Context) {
	count := u8(instructions_next(ctx))
	for _ in 0 ..< count {
		v := instructions_next(ctx)
		stack_push(ctx, [1]i32{i32(v)})
	}
}

ins_npushw :: proc(ctx: ^Execution_Context) {
	count := u8(instructions_next(ctx))
	for _ in 0 ..< count {
		ms := instructions_next(ctx)
		ls := instructions_next(ctx)
		v := i32(i16(u16(ms) << 8 | u16(ls)))
		stack_push(ctx, [1]i32{v})
	}
}

ins_ws :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	value := values[0]
	idx := u32(values[1])
	set_storage(ctx, idx, value)
}

ins_rs :: proc(ctx: ^Execution_Context) {
	idx := u32(stack_pop(ctx, 1)[0])
	val := get_storage(ctx, idx)
	stack_push(ctx, [1]i32{val})
}

ins_wcvtp :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	pixels := f26dot6_to_f32(values[0])
	idx := u32(values[1])
	set_cvt(ctx, idx, pixels)
}

ins_rcvt :: proc(ctx: ^Execution_Context) {
	idx := u32(stack_pop(ctx, 1)[0])
	pixels := get_cvt(ctx, idx)
	debug_log(ctx, "    cvt value: %v [%v]", pixels, idx)
	stack_push(ctx, [1]i32{f32_to_f26dot6(pixels)})
}

ins_gc :: proc(ctx: ^Execution_Context) {
	idx := u32(stack_pop(ctx, 1)[0])
	ins := u8(ctx.ins)

	val: f32
	if ins & 0x1 != 0 {
		orig_scaled := zp_get(ctx, ctx.zp2.orig_scaled, idx)
		val = dual_project(ctx, orig_scaled)
	} else {
		cur := zp_get(ctx, ctx.zp2.cur, idx)
		val = project(ctx, cur)
	}

	stack_push(ctx, [1]i32{f32_to_f26dot6(val)})
}

ins_scfs :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	k := f26dot6_to_f32(values[0])
	point_idx := u32(values[1])

	projection := project(ctx, zp_get(ctx, ctx.zp2.cur, point_idx))
	move_point(ctx, ctx.zp2, point_idx, projection - k, true)
	if ctx.gs.gep2 == 0 {
		twilight := zp_get(ctx, ctx.zp2.cur, point_idx)
		zp_set(ctx, ctx.zp2.orig_scaled, point_idx, twilight)
	}
}

ins_md :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	point_idx_0 := u32(values[0])
	point_idx_1 := u32(values[1])

	ins := u8(ctx.ins)
	dist: f32
	if ins & 1 != 0 {
		cur_0 := zp_get(ctx, ctx.zp1.cur, point_idx_0)
		cur_1 := zp_get(ctx, ctx.zp0.cur, point_idx_1)
		dist = project(ctx, cur_1 - cur_0)
	} else {
		is_twilight := ctx.gs.gep0 == 0 || ctx.gs.gep1 == 0
		if is_twilight {
			orig_0 := zp_get(ctx, ctx.zp1.orig_scaled, point_idx_0)
			orig_1 := zp_get(ctx, ctx.zp0.orig_scaled, point_idx_1)
			dist = dual_project(ctx, orig_1 - orig_0)
		} else {
			orig_0 := zp_get(ctx, ctx.zp1.orig, point_idx_0)
			orig_1 := zp_get(ctx, ctx.zp0.orig, point_idx_1)
			dist = dual_project(ctx, orig_1 - orig_0) * ctx.program.funits_to_pixels_scale
		}
	}

	stack_push(ctx, [1]i32{f32_to_f26dot6(dist)})
}

ins_mppem :: proc(ctx: ^Execution_Context) {
	stack_push(ctx, [1]i32{i32(ctx.program.ppem)})
}

ins_mps :: proc(ctx: ^Execution_Context) {
	stack_push(ctx, [1]i32{f32_to_f26dot6(ctx.program.point_size)})
}

ins_flipon :: proc(ctx: ^Execution_Context) {
	ctx.gs.auto_flip = true
}

ins_flipoff :: proc(ctx: ^Execution_Context) {
	ctx.gs.auto_flip = false
}

ins_debug :: proc(ctx: ^Execution_Context) {
	stack_pop(ctx, 1)
}

ins_lt :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	stack_push(ctx, [1]i32{e1 < e2 ? 1 : 0})
}

ins_lteq :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	stack_push(ctx, [1]i32{e1 <= e2 ? 1 : 0})
}

ins_gt :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	stack_push(ctx, [1]i32{e1 > e2 ? 1 : 0})
}

ins_gteq :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	stack_push(ctx, [1]i32{e1 >= e2 ? 1 : 0})
}

ins_eq :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	stack_push(ctx, [1]i32{e1 == e2 ? 1 : 0})
}

ins_neq :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	stack_push(ctx, [1]i32{e1 != e2 ? 1 : 0})
}

ins_odd :: proc(ctx: ^Execution_Context) {
	value := f26dot6_to_f32(stack_pop(ctx, 1)[0])
	value = round_according_to_state(ctx, value)
	is_odd := f32_to_f26dot6(value) & 127 == 64
	stack_push(ctx, [1]i32{is_odd ? 1 : 0})
}

ins_even :: proc(ctx: ^Execution_Context) {
	value := f26dot6_to_f32(stack_pop(ctx, 1)[0])
	value = round_according_to_state(ctx, value)
	is_even := f32_to_f26dot6(value) & 127 == 0
	stack_push(ctx, [1]i32{is_even ? 1 : 0})
}

ins_if :: proc(ctx: ^Execution_Context) {
	val := stack_pop(ctx, 1)[0]
	if val != 0 {
		return
	}

	n_ifs := 1
	out := false
	for !out && !ctx.error {
		skip_code(ctx)
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
	instructions_next(ctx)
}

ins_eif :: proc(ctx: ^Execution_Context) {
	// no op
}

ins_and :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	stack_push(ctx, [1]i32{e1 != 0 && e2 != 0 ? 1 : 0})
}

ins_or :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	stack_push(ctx, [1]i32{e1 != 0 || e2 != 0 ? 1 : 0})
}

ins_not :: proc(ctx: ^Execution_Context) {
	val := u32(stack_pop(ctx, 1)[0])
	stack_push(ctx, [1]i32{val == 0 ? 1 : 0})
}

ins_sdb :: proc(ctx: ^Execution_Context) {
	val := u16(stack_pop(ctx, 1)[0])
	ctx.gs.delta_base = val
}

ins_sds :: proc(ctx: ^Execution_Context) {
	val := u32(stack_pop(ctx, 1)[0])
	ctx.gs.delta_shift = val
}

ins_add :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	stack_push(ctx, [1]i32{values[0] + values[1]})
}

ins_sub :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	stack_push(ctx, [1]i32{values[1] - values[0]})
}

ins_div :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	n1 := f26dot6_to_f32(values[0])
	n2 := f26dot6_to_f32(values[1])

	stack_push(ctx, [1]i32{f32_to_f26dot6(n2 / n1)})
}

ins_mul :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	n1 := f26dot6_to_f32(values[0])
	n2 := f26dot6_to_f32(values[1])

	stack_push(ctx, [1]i32{f32_to_f26dot6(n2 * n1)})
}

ins_abs :: proc(ctx: ^Execution_Context) {
	val := stack_pop(ctx, 1)[0]
	stack_push(ctx, [1]i32{abs(val)})
}

ins_neg :: proc(ctx: ^Execution_Context) {
	val := stack_pop(ctx, 1)[0]
	stack_push(ctx, [1]i32{-val})
}

ins_floor :: proc(ctx: ^Execution_Context) {
	val := stack_pop(ctx, 1)[0]
	stack_push(ctx, [1]i32{i32(u32(val) & 0xFFFFFFC0)})
}

ins_ceiling :: proc(ctx: ^Execution_Context) {
	val := stack_pop(ctx, 1)[0]
	stack_push(ctx, [1]i32{i32((u32(val) + 0x3F) & 0xFFFFFFC0)})
}

ins_round :: proc(ctx: ^Execution_Context) {
	val := f26dot6_to_f32(stack_pop(ctx, 1)[0])
	val = round_according_to_state(ctx, val)
	stack_push(ctx, [1]i32{f32_to_f26dot6(val)})
}

ins_nround :: proc(ctx: ^Execution_Context) {
	// NOTE(lucas): we no-op here as we do not have engine compensation
	// TODO(lucas): maybe we want compensation?
}

ins_wcvtf :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	funits := f32(u32(values[0]))
	cvt_idx := u32(values[1])
	set_cvt(ctx, cvt_idx, funits * ctx.program.funits_to_pixels_scale)
}


ins_deltap :: proc(ctx: ^Execution_Context) {
	range: u32 = 0
	#partial switch ctx.ins {
	case .ins_deltap1:
		range = 0
	case .ins_deltap2:
		range = 16
	case .ins_deltap3:
		range = 32
	}

	count := u32(stack_pop(ctx, 1)[0])
	for _ in 0 ..< count {
		values := stack_pop(ctx, 2)
		point_index := u32(values[0])
		exc := u32(values[1])
		if delta, ok := try_get_delta_value(ctx, exc, range); ok {
			touch_state := zp_get(ctx, ctx.zp0.touch, point_index)
			a := ctx.iup_state != TTF_HINTER_TOUCH_XY
			b := ctx.is_compound_glyph && ctx.gs.free_vector.y != 0
			c := touch_state & TTF_HINTER_TOUCH_Y != 0
			can_move := a && b || c
			if can_move {
				move_point(ctx, ctx.zp0, point_index, delta, true)
			}
		}
	}
}

ins_deltac :: proc(ctx: ^Execution_Context) {
	range: u32 = 0
	#partial switch ctx.ins {
	case .ins_deltac1:
		range = 0
	case .ins_deltac2:
		range = 16
	case .ins_deltac3:
		range = 32
	}
	count := u32(stack_pop(ctx, 1)[0])
	for _ in 0 ..< count {
		values := stack_pop(ctx, 2)
		cvt_index := u32(values[0])
		exc := u32(values[1])
		if delta, ok := try_get_delta_value(ctx, exc, range); ok {
			add_cvt(ctx, cvt_index, delta)
		}
	}
}

ins_sround :: proc(ctx: ^Execution_Context) {
	program_error(ctx, "unimplemented instruction sround")
}

ins_s45round :: proc(ctx: ^Execution_Context) {
	program_error(ctx, "unimplemented instruction s45round")
}

ins_jrot :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	val := values[0]
	off := values[1]
	if val != 0 {
		instructions_jump(ctx, off - 1)
	}
}

ins_jrof :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	val := values[0]
	off := values[1]
	if val == 0 {
		instructions_jump(ctx, off - 1)
	}
}

ins_roff :: proc(ctx: ^Execution_Context) {
	ctx.gs.round_state = .off
}

ins_rutg :: proc(ctx: ^Execution_Context) {
	ctx.gs.round_state = .up_to_grid
}

ins_rdtg :: proc(ctx: ^Execution_Context) {
	ctx.gs.round_state = .down_to_grid
}

ins_sangw :: proc(ctx: ^Execution_Context) {
	// NOTE(lucas): not even freetype runs this instruction
}

ins_aa :: proc(ctx: ^Execution_Context) {
	// NOTE(lucas): not even freetype runs this instruction
}

ins_flippt :: proc(ctx: ^Execution_Context) {
	program_error(ctx, "unimplemented instruction flippt")
}

ins_fliprgon :: proc(ctx: ^Execution_Context) {
	program_error(ctx, "unimplemented instruction fliprgon")
}

ins_fliprgoff :: proc(ctx: ^Execution_Context) {
	program_error(ctx, "unimplemented instruction fliprgoff")
}

ins_scanctrl :: proc(ctx: ^Execution_Context) {
	flags := u16(stack_pop(ctx, 1)[0])
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
		if flags & 0x1000 != 0 && !ctx.gs.is_rotated {
			ctx.gs.scan_control = false
		}
		if flags & 0x2000 != 0 && !ctx.gs.is_stretched {
			ctx.gs.scan_control = false
		}
	}
}

ins_sdpvtl :: proc(ctx: ^Execution_Context) {
	ins := u8(ctx.ins)
	values := stack_pop(ctx, 2)
	p1_idx := u32(values[0])
	p2_idx := u32(values[1])

	p1 := zp_get(ctx, ctx.zp2.orig_scaled, p1_idx)
	p2 := zp_get(ctx, ctx.zp1.orig_scaled, p2_idx)

	ctx.gs.dual_vector = p2 - p1
	if abs(ctx.gs.dual_vector.x) < HINTER_EPS && abs(ctx.gs.dual_vector.y) < HINTER_EPS {
		ctx.gs.dual_vector = {1, 0}
		ins = 0
	}

	if ins & 0x1 != 0 {
		ctx.gs.dual_vector.x, ctx.gs.dual_vector.y = -ctx.gs.dual_vector.y, ctx.gs.dual_vector.x
	}
	ctx.gs.dual_vector = linalg.normalize0(ctx.gs.dual_vector)

	p1 = zp_get(ctx, ctx.zp2.cur, p1_idx)
	p2 = zp_get(ctx, ctx.zp1.cur, p2_idx)

	ctx.gs.proj_vector = p2 - p1
	if ins & 0x1 != 0 {
		ctx.gs.proj_vector.x, ctx.gs.proj_vector.y = -ctx.gs.proj_vector.y, ctx.gs.proj_vector.x
	}
	ctx.gs.proj_vector = linalg.normalize0(ctx.gs.proj_vector)
}

ins_getinfo :: proc(ctx: ^Execution_Context) {
	selector := u16(stack_pop(ctx, 1)[0])

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
	if ((selector & 0x00000020 != 0) && !ctx.gs.is_subpixel_rendering) {
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

	debug_log(ctx, "    get info: %v", result)
	stack_push(ctx, [1]i32{result})
}

ins_idef :: proc(ctx: ^Execution_Context) {
	if ctx.stage == .glyph {
		program_error(ctx, "bad stage")
	}
	if ctx.error {
		return
	}
}

ins_roll :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 3)
	stack_push(ctx, [3]i32{values[1], values[0], values[2]})
}

ins_max :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	stack_push(ctx, [1]i32{i32(max(e2, e1))})
}

ins_min :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	e2 := values[0]
	e1 := values[1]
	stack_push(ctx, [1]i32{i32(min(e2, e1))})
}

ins_scantype :: proc(ctx: ^Execution_Context) {
	val := stack_pop(ctx, 1)[0]
	if val >= 0 {
		ctx.gs.scan_type = val & 0xFFFF
	}
}

ins_instctrl :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	k := values[0]
	l := values[1]
	if k < 1 || k > 3 {
		program_error(ctx, "instctrl error")
		return
	}
	kf := i32(1 << u32(k - 1))
	if l != 0 && l != kf {
		program_error(ctx, "instctrl error")
		return
	}

	switch ctx.stage {
	case .glyph:
	case .cvt:
		ctx.gs.instruct_control &= ~u8(kf)
		ctx.gs.instruct_control |= u8(l)
	case .font:
		program_error(ctx, "instctrl error")
	}
}

ins_getvar :: proc(ctx: ^Execution_Context) {
	// NOTE(lucas): apparently this is some weird apple instruction
	program_error(ctx, "unimplemented instruction getvar")
}

ins_getdata :: proc(ctx: ^Execution_Context) {
	// NOTE(lucas): apparently this is some weird apple instruction
	program_error(ctx, "unimplemented instruction getdata")
}

ins_pushb :: proc(ctx: ^Execution_Context) {
	count := (u8(ctx.ins) & 0x7) + 1
	for _ in 0 ..< count {
		v := instructions_next(ctx)
		stack_push(ctx, [1]i32{i32(v)})
	}
}

ins_pushw :: proc(ctx: ^Execution_Context) {
	count := (u8(ctx.ins) & 0x7) + 1
	for _ in 0 ..< count {
		ms := instructions_next(ctx)
		ls := instructions_next(ctx)
		v := i32(i16(u16(ms) << 8 | u16(ls)))
		stack_push(ctx, [1]i32{v})
	}
}

ins_mdrp :: proc(ctx: ^Execution_Context) {
	point_idx := u32(stack_pop(ctx, 1)[0])

	is_twilight_zone := ctx.gs.gep0 == 0 || ctx.gs.gep1 == 0
	rp0_orig, point_orig: [2]f32

	if is_twilight_zone {
		rp0_orig = zp_get(ctx, ctx.zp0.orig_scaled, ctx.gs.rp0)
		point_orig = zp_get(ctx, ctx.zp1.orig_scaled, point_idx)
	} else {
		rp0_orig = zp_get(ctx, ctx.zp0.orig, ctx.gs.rp0)
		point_orig = zp_get(ctx, ctx.zp1.orig, point_idx)
	}

	rp0_cur := zp_get(ctx, ctx.zp0.cur, ctx.gs.rp0)
	point_cur := zp_get(ctx, ctx.zp1.cur, point_idx)

	dist_cur := project(ctx, point_cur - rp0_cur)
	dist_orig := dual_project(ctx, point_orig - rp0_orig)

	if !is_twilight_zone {
		dist_orig = dist_orig * ctx.program.funits_to_pixels_scale
	}

	dist_orig = apply_single_width_cut_in(ctx, dist_orig)
	ins := u8(ctx.ins)
	if ins & 0x04 != 0 {
		dist_orig = round_according_to_state(ctx, dist_orig)
	}

	if ins & 0x08 != 0 {
		dist_orig = apply_min_dist(ctx, dist_orig)
	}
	move_point(ctx, ctx.zp1, point_idx, dist_orig - dist_cur, true)
	ctx.gs.rp1 = ctx.gs.rp0
	ctx.gs.rp2 = point_idx
	if ins & 0x10 != 0 {
		ctx.gs.rp0 = point_idx
	}
	debug_log(ctx, "    rp0 = %v", ctx.gs.rp0)
	debug_log(ctx, "    rp1 = %v", ctx.gs.rp1)
	debug_log(ctx, "    rp2 = %v", ctx.gs.rp2)
}


ins_mirp :: proc(ctx: ^Execution_Context) {
	values := stack_pop(ctx, 2)
	cvt_idx := u32(values[0])
	point_idx := u32(values[1])

	val := get_cvt(ctx, cvt_idx)
	cvt_val := apply_single_width_cut_in(ctx, val)

	rp0_orig := zp_get(ctx, ctx.zp0.orig_scaled, ctx.gs.rp0)
	rp0_cur := zp_get(ctx, ctx.zp0.cur, ctx.gs.rp0)

	point_orig := zp_get(ctx, ctx.zp1.orig_scaled, point_idx)
	point_cur := zp_get(ctx, ctx.zp1.cur, point_idx)
	if ctx.gs.gep1 == 0 {
		point_orig = rp0_orig + cvt_val * ctx.gs.free_vector
		point_cur = point_orig
		zp_set(ctx, ctx.zp1.orig_scaled, point_idx, point_orig)
		zp_set(ctx, ctx.zp1.cur, point_idx, point_cur)
	}

	dist_cur := project(ctx, point_cur - rp0_cur)
	dist_orig := dual_project(ctx, point_orig - rp0_orig)

	if ctx.gs.auto_flip {
		if !same_sign(dist_orig, cvt_val) {
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
		dist_new = round_according_to_state(ctx, cvt_val)
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

	move_point(ctx, ctx.zp1, point_idx, dist_new - dist_cur, true)
	ctx.gs.rp1 = ctx.gs.rp0
	ctx.gs.rp2 = point_idx
	if ins & 0x10 != 0 {
		ctx.gs.rp0 = point_idx
	}
	debug_log(ctx, "    rp0 = %v", ctx.gs.rp0)
	debug_log(ctx, "    rp1 = %v", ctx.gs.rp1)
	debug_log(ctx, "    rp2 = %v", ctx.gs.rp2)
}
