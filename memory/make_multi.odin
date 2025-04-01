package runic_memory

import "base:runtime"
import "base:intrinsics"

@(private="file")
_Make_Multi_Resolved :: struct {
    size: int,
    alignment: int,
}

@(private="file")
_make_multi :: #force_no_inline proc(multi: [$N]_Make_Multi_Resolved, allocator: Allocator) -> (rawptr, [N]rawptr, Allocator_Error) #no_bounds_check {
    size: int
    for m in multi {
        size = (size + m.alignment - 1) & ~(m.alignment - 1)
        size += m.size
    }
    data, err := runtime.make_aligned([]byte, size, multi[0].alignment, allocator)
    if err != nil {
        return nil, {}, err
    }

    base := raw_data(data)
    data_pos := uintptr(base)
    res: [N]rawptr 
    for i in 0..<N {
        m := multi[i]
        data_pos = (data_pos + uintptr(m.alignment) - 1) & ~(uintptr(m.alignment) - 1)
        res[i] = rawptr(data_pos)
        data_pos += uintptr(m.size)
    }

    return base, res, nil
}

Make_Multi :: struct($T:typeid) {
    len: int,
    alignment: int,
}

make_multi_2 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), allocator: Allocator) ->
    (rawptr, T00, T01, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    resolved := [2]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    return base, a_result, b_result, nil
}

make_multi_3 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), allocator: Allocator) ->
    (rawptr, T00, T01, T02, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    resolved := [3]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    return base, a_result, b_result, c_result, nil
}

make_multi_4 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    resolved := [4]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    return base, a_result, b_result, c_result, d_result, nil
}

make_multi_5 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    resolved := [5]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    return base, a_result, b_result, c_result, d_result, e_result, nil
}

make_multi_6 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    resolved := [6]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, nil
}

make_multi_7 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), g: Make_Multi($T06), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, T06, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05)) &&
          (intrinsics.type_is_slice(T06) || intrinsics.type_is_pointer(T06))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    _T06 :: intrinsics.type_elem_type(T06)
    resolved := [7]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
        { size_of(_T06), g.alignment == 0 ? align_of(_T06) : g.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    when intrinsics.type_is_slice(T06) { assert(g.len >= 0 ); resolved[6].size *= g.len; if (g.len == 0) { resolved[6].alignment = 1 } } else { assert(g.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    g_result: T06 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    when intrinsics.type_is_slice(T06) { g_result = ([^]_T06)(ptrs[6])[:g.len] } else { g_result = (^_T06)(ptrs[6]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, g_result, nil
}

make_multi_8 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), g: Make_Multi($T06), h: Make_Multi($T07), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, T06, T07, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05)) &&
          (intrinsics.type_is_slice(T06) || intrinsics.type_is_pointer(T06)) &&
          (intrinsics.type_is_slice(T07) || intrinsics.type_is_pointer(T07))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    _T06 :: intrinsics.type_elem_type(T06)
    _T07 :: intrinsics.type_elem_type(T07)
    resolved := [8]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
        { size_of(_T06), g.alignment == 0 ? align_of(_T06) : g.alignment },
        { size_of(_T07), h.alignment == 0 ? align_of(_T07) : h.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    when intrinsics.type_is_slice(T06) { assert(g.len >= 0 ); resolved[6].size *= g.len; if (g.len == 0) { resolved[6].alignment = 1 } } else { assert(g.len == 0) }
    when intrinsics.type_is_slice(T07) { assert(h.len >= 0 ); resolved[7].size *= h.len; if (h.len == 0) { resolved[7].alignment = 1 } } else { assert(h.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    g_result: T06 = ---
    h_result: T07 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    when intrinsics.type_is_slice(T06) { g_result = ([^]_T06)(ptrs[6])[:g.len] } else { g_result = (^_T06)(ptrs[6]) }
    when intrinsics.type_is_slice(T07) { h_result = ([^]_T07)(ptrs[7])[:h.len] } else { h_result = (^_T07)(ptrs[7]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, g_result, h_result, nil
}

make_multi_9 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), g: Make_Multi($T06), h: Make_Multi($T07), i: Make_Multi($T08), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, T06, T07, T08, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05)) &&
          (intrinsics.type_is_slice(T06) || intrinsics.type_is_pointer(T06)) &&
          (intrinsics.type_is_slice(T07) || intrinsics.type_is_pointer(T07)) &&
          (intrinsics.type_is_slice(T08) || intrinsics.type_is_pointer(T08))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    _T06 :: intrinsics.type_elem_type(T06)
    _T07 :: intrinsics.type_elem_type(T07)
    _T08 :: intrinsics.type_elem_type(T08)
    resolved := [9]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
        { size_of(_T06), g.alignment == 0 ? align_of(_T06) : g.alignment },
        { size_of(_T07), h.alignment == 0 ? align_of(_T07) : h.alignment },
        { size_of(_T08), i.alignment == 0 ? align_of(_T08) : i.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    when intrinsics.type_is_slice(T06) { assert(g.len >= 0 ); resolved[6].size *= g.len; if (g.len == 0) { resolved[6].alignment = 1 } } else { assert(g.len == 0) }
    when intrinsics.type_is_slice(T07) { assert(h.len >= 0 ); resolved[7].size *= h.len; if (h.len == 0) { resolved[7].alignment = 1 } } else { assert(h.len == 0) }
    when intrinsics.type_is_slice(T08) { assert(i.len >= 0 ); resolved[8].size *= i.len; if (i.len == 0) { resolved[8].alignment = 1 } } else { assert(i.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    g_result: T06 = ---
    h_result: T07 = ---
    i_result: T08 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    when intrinsics.type_is_slice(T06) { g_result = ([^]_T06)(ptrs[6])[:g.len] } else { g_result = (^_T06)(ptrs[6]) }
    when intrinsics.type_is_slice(T07) { h_result = ([^]_T07)(ptrs[7])[:h.len] } else { h_result = (^_T07)(ptrs[7]) }
    when intrinsics.type_is_slice(T08) { i_result = ([^]_T08)(ptrs[8])[:i.len] } else { i_result = (^_T08)(ptrs[8]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, g_result, h_result, i_result, nil
}

make_multi_10 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), g: Make_Multi($T06), h: Make_Multi($T07), i: Make_Multi($T08), j: Make_Multi($T09), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, T06, T07, T08, T09, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05)) &&
          (intrinsics.type_is_slice(T06) || intrinsics.type_is_pointer(T06)) &&
          (intrinsics.type_is_slice(T07) || intrinsics.type_is_pointer(T07)) &&
          (intrinsics.type_is_slice(T08) || intrinsics.type_is_pointer(T08)) &&
          (intrinsics.type_is_slice(T09) || intrinsics.type_is_pointer(T09))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    _T06 :: intrinsics.type_elem_type(T06)
    _T07 :: intrinsics.type_elem_type(T07)
    _T08 :: intrinsics.type_elem_type(T08)
    _T09 :: intrinsics.type_elem_type(T09)
    resolved := [10]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
        { size_of(_T06), g.alignment == 0 ? align_of(_T06) : g.alignment },
        { size_of(_T07), h.alignment == 0 ? align_of(_T07) : h.alignment },
        { size_of(_T08), i.alignment == 0 ? align_of(_T08) : i.alignment },
        { size_of(_T09), j.alignment == 0 ? align_of(_T09) : j.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    when intrinsics.type_is_slice(T06) { assert(g.len >= 0 ); resolved[6].size *= g.len; if (g.len == 0) { resolved[6].alignment = 1 } } else { assert(g.len == 0) }
    when intrinsics.type_is_slice(T07) { assert(h.len >= 0 ); resolved[7].size *= h.len; if (h.len == 0) { resolved[7].alignment = 1 } } else { assert(h.len == 0) }
    when intrinsics.type_is_slice(T08) { assert(i.len >= 0 ); resolved[8].size *= i.len; if (i.len == 0) { resolved[8].alignment = 1 } } else { assert(i.len == 0) }
    when intrinsics.type_is_slice(T09) { assert(j.len >= 0 ); resolved[9].size *= j.len; if (j.len == 0) { resolved[9].alignment = 1 } } else { assert(j.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    g_result: T06 = ---
    h_result: T07 = ---
    i_result: T08 = ---
    j_result: T09 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    when intrinsics.type_is_slice(T06) { g_result = ([^]_T06)(ptrs[6])[:g.len] } else { g_result = (^_T06)(ptrs[6]) }
    when intrinsics.type_is_slice(T07) { h_result = ([^]_T07)(ptrs[7])[:h.len] } else { h_result = (^_T07)(ptrs[7]) }
    when intrinsics.type_is_slice(T08) { i_result = ([^]_T08)(ptrs[8])[:i.len] } else { i_result = (^_T08)(ptrs[8]) }
    when intrinsics.type_is_slice(T09) { j_result = ([^]_T09)(ptrs[9])[:j.len] } else { j_result = (^_T09)(ptrs[9]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, g_result, h_result, i_result, j_result, nil
}

make_multi_11 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), g: Make_Multi($T06), h: Make_Multi($T07), i: Make_Multi($T08), j: Make_Multi($T09), k: Make_Multi($T10), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, T06, T07, T08, T09, T10, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05)) &&
          (intrinsics.type_is_slice(T06) || intrinsics.type_is_pointer(T06)) &&
          (intrinsics.type_is_slice(T07) || intrinsics.type_is_pointer(T07)) &&
          (intrinsics.type_is_slice(T08) || intrinsics.type_is_pointer(T08)) &&
          (intrinsics.type_is_slice(T09) || intrinsics.type_is_pointer(T09)) &&
          (intrinsics.type_is_slice(T10) || intrinsics.type_is_pointer(T10))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    _T06 :: intrinsics.type_elem_type(T06)
    _T07 :: intrinsics.type_elem_type(T07)
    _T08 :: intrinsics.type_elem_type(T08)
    _T09 :: intrinsics.type_elem_type(T09)
    _T10 :: intrinsics.type_elem_type(T10)
    resolved := [11]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
        { size_of(_T06), g.alignment == 0 ? align_of(_T06) : g.alignment },
        { size_of(_T07), h.alignment == 0 ? align_of(_T07) : h.alignment },
        { size_of(_T08), i.alignment == 0 ? align_of(_T08) : i.alignment },
        { size_of(_T09), j.alignment == 0 ? align_of(_T09) : j.alignment },
        { size_of(_T10), k.alignment == 0 ? align_of(_T10) : k.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    when intrinsics.type_is_slice(T06) { assert(g.len >= 0 ); resolved[6].size *= g.len; if (g.len == 0) { resolved[6].alignment = 1 } } else { assert(g.len == 0) }
    when intrinsics.type_is_slice(T07) { assert(h.len >= 0 ); resolved[7].size *= h.len; if (h.len == 0) { resolved[7].alignment = 1 } } else { assert(h.len == 0) }
    when intrinsics.type_is_slice(T08) { assert(i.len >= 0 ); resolved[8].size *= i.len; if (i.len == 0) { resolved[8].alignment = 1 } } else { assert(i.len == 0) }
    when intrinsics.type_is_slice(T09) { assert(j.len >= 0 ); resolved[9].size *= j.len; if (j.len == 0) { resolved[9].alignment = 1 } } else { assert(j.len == 0) }
    when intrinsics.type_is_slice(T10) { assert(k.len >= 0 ); resolved[10].size *= k.len; if (k.len == 0) { resolved[10].alignment = 1 } } else { assert(k.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    g_result: T06 = ---
    h_result: T07 = ---
    i_result: T08 = ---
    j_result: T09 = ---
    k_result: T10 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    when intrinsics.type_is_slice(T06) { g_result = ([^]_T06)(ptrs[6])[:g.len] } else { g_result = (^_T06)(ptrs[6]) }
    when intrinsics.type_is_slice(T07) { h_result = ([^]_T07)(ptrs[7])[:h.len] } else { h_result = (^_T07)(ptrs[7]) }
    when intrinsics.type_is_slice(T08) { i_result = ([^]_T08)(ptrs[8])[:i.len] } else { i_result = (^_T08)(ptrs[8]) }
    when intrinsics.type_is_slice(T09) { j_result = ([^]_T09)(ptrs[9])[:j.len] } else { j_result = (^_T09)(ptrs[9]) }
    when intrinsics.type_is_slice(T10) { k_result = ([^]_T10)(ptrs[10])[:k.len] } else { k_result = (^_T10)(ptrs[10]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, g_result, h_result, i_result, j_result, k_result, nil
}

make_multi_12 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), g: Make_Multi($T06), h: Make_Multi($T07), i: Make_Multi($T08), j: Make_Multi($T09), k: Make_Multi($T10), l: Make_Multi($T11), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, T06, T07, T08, T09, T10, T11, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05)) &&
          (intrinsics.type_is_slice(T06) || intrinsics.type_is_pointer(T06)) &&
          (intrinsics.type_is_slice(T07) || intrinsics.type_is_pointer(T07)) &&
          (intrinsics.type_is_slice(T08) || intrinsics.type_is_pointer(T08)) &&
          (intrinsics.type_is_slice(T09) || intrinsics.type_is_pointer(T09)) &&
          (intrinsics.type_is_slice(T10) || intrinsics.type_is_pointer(T10)) &&
          (intrinsics.type_is_slice(T11) || intrinsics.type_is_pointer(T11))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    _T06 :: intrinsics.type_elem_type(T06)
    _T07 :: intrinsics.type_elem_type(T07)
    _T08 :: intrinsics.type_elem_type(T08)
    _T09 :: intrinsics.type_elem_type(T09)
    _T10 :: intrinsics.type_elem_type(T10)
    _T11 :: intrinsics.type_elem_type(T11)
    resolved := [12]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
        { size_of(_T06), g.alignment == 0 ? align_of(_T06) : g.alignment },
        { size_of(_T07), h.alignment == 0 ? align_of(_T07) : h.alignment },
        { size_of(_T08), i.alignment == 0 ? align_of(_T08) : i.alignment },
        { size_of(_T09), j.alignment == 0 ? align_of(_T09) : j.alignment },
        { size_of(_T10), k.alignment == 0 ? align_of(_T10) : k.alignment },
        { size_of(_T11), l.alignment == 0 ? align_of(_T11) : l.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    when intrinsics.type_is_slice(T06) { assert(g.len >= 0 ); resolved[6].size *= g.len; if (g.len == 0) { resolved[6].alignment = 1 } } else { assert(g.len == 0) }
    when intrinsics.type_is_slice(T07) { assert(h.len >= 0 ); resolved[7].size *= h.len; if (h.len == 0) { resolved[7].alignment = 1 } } else { assert(h.len == 0) }
    when intrinsics.type_is_slice(T08) { assert(i.len >= 0 ); resolved[8].size *= i.len; if (i.len == 0) { resolved[8].alignment = 1 } } else { assert(i.len == 0) }
    when intrinsics.type_is_slice(T09) { assert(j.len >= 0 ); resolved[9].size *= j.len; if (j.len == 0) { resolved[9].alignment = 1 } } else { assert(j.len == 0) }
    when intrinsics.type_is_slice(T10) { assert(k.len >= 0 ); resolved[10].size *= k.len; if (k.len == 0) { resolved[10].alignment = 1 } } else { assert(k.len == 0) }
    when intrinsics.type_is_slice(T11) { assert(l.len >= 0 ); resolved[11].size *= l.len; if (l.len == 0) { resolved[11].alignment = 1 } } else { assert(l.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    g_result: T06 = ---
    h_result: T07 = ---
    i_result: T08 = ---
    j_result: T09 = ---
    k_result: T10 = ---
    l_result: T11 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    when intrinsics.type_is_slice(T06) { g_result = ([^]_T06)(ptrs[6])[:g.len] } else { g_result = (^_T06)(ptrs[6]) }
    when intrinsics.type_is_slice(T07) { h_result = ([^]_T07)(ptrs[7])[:h.len] } else { h_result = (^_T07)(ptrs[7]) }
    when intrinsics.type_is_slice(T08) { i_result = ([^]_T08)(ptrs[8])[:i.len] } else { i_result = (^_T08)(ptrs[8]) }
    when intrinsics.type_is_slice(T09) { j_result = ([^]_T09)(ptrs[9])[:j.len] } else { j_result = (^_T09)(ptrs[9]) }
    when intrinsics.type_is_slice(T10) { k_result = ([^]_T10)(ptrs[10])[:k.len] } else { k_result = (^_T10)(ptrs[10]) }
    when intrinsics.type_is_slice(T11) { l_result = ([^]_T11)(ptrs[11])[:l.len] } else { l_result = (^_T11)(ptrs[11]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, g_result, h_result, i_result, j_result, k_result, l_result, nil
}

make_multi_13 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), g: Make_Multi($T06), h: Make_Multi($T07), i: Make_Multi($T08), j: Make_Multi($T09), k: Make_Multi($T10), l: Make_Multi($T11), m: Make_Multi($T12), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, T06, T07, T08, T09, T10, T11, T12, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05)) &&
          (intrinsics.type_is_slice(T06) || intrinsics.type_is_pointer(T06)) &&
          (intrinsics.type_is_slice(T07) || intrinsics.type_is_pointer(T07)) &&
          (intrinsics.type_is_slice(T08) || intrinsics.type_is_pointer(T08)) &&
          (intrinsics.type_is_slice(T09) || intrinsics.type_is_pointer(T09)) &&
          (intrinsics.type_is_slice(T10) || intrinsics.type_is_pointer(T10)) &&
          (intrinsics.type_is_slice(T11) || intrinsics.type_is_pointer(T11)) &&
          (intrinsics.type_is_slice(T12) || intrinsics.type_is_pointer(T12))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    _T06 :: intrinsics.type_elem_type(T06)
    _T07 :: intrinsics.type_elem_type(T07)
    _T08 :: intrinsics.type_elem_type(T08)
    _T09 :: intrinsics.type_elem_type(T09)
    _T10 :: intrinsics.type_elem_type(T10)
    _T11 :: intrinsics.type_elem_type(T11)
    _T12 :: intrinsics.type_elem_type(T12)
    resolved := [13]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
        { size_of(_T06), g.alignment == 0 ? align_of(_T06) : g.alignment },
        { size_of(_T07), h.alignment == 0 ? align_of(_T07) : h.alignment },
        { size_of(_T08), i.alignment == 0 ? align_of(_T08) : i.alignment },
        { size_of(_T09), j.alignment == 0 ? align_of(_T09) : j.alignment },
        { size_of(_T10), k.alignment == 0 ? align_of(_T10) : k.alignment },
        { size_of(_T11), l.alignment == 0 ? align_of(_T11) : l.alignment },
        { size_of(_T12), m.alignment == 0 ? align_of(_T12) : m.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    when intrinsics.type_is_slice(T06) { assert(g.len >= 0 ); resolved[6].size *= g.len; if (g.len == 0) { resolved[6].alignment = 1 } } else { assert(g.len == 0) }
    when intrinsics.type_is_slice(T07) { assert(h.len >= 0 ); resolved[7].size *= h.len; if (h.len == 0) { resolved[7].alignment = 1 } } else { assert(h.len == 0) }
    when intrinsics.type_is_slice(T08) { assert(i.len >= 0 ); resolved[8].size *= i.len; if (i.len == 0) { resolved[8].alignment = 1 } } else { assert(i.len == 0) }
    when intrinsics.type_is_slice(T09) { assert(j.len >= 0 ); resolved[9].size *= j.len; if (j.len == 0) { resolved[9].alignment = 1 } } else { assert(j.len == 0) }
    when intrinsics.type_is_slice(T10) { assert(k.len >= 0 ); resolved[10].size *= k.len; if (k.len == 0) { resolved[10].alignment = 1 } } else { assert(k.len == 0) }
    when intrinsics.type_is_slice(T11) { assert(l.len >= 0 ); resolved[11].size *= l.len; if (l.len == 0) { resolved[11].alignment = 1 } } else { assert(l.len == 0) }
    when intrinsics.type_is_slice(T12) { assert(m.len >= 0 ); resolved[12].size *= m.len; if (m.len == 0) { resolved[12].alignment = 1 } } else { assert(m.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    g_result: T06 = ---
    h_result: T07 = ---
    i_result: T08 = ---
    j_result: T09 = ---
    k_result: T10 = ---
    l_result: T11 = ---
    m_result: T12 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    when intrinsics.type_is_slice(T06) { g_result = ([^]_T06)(ptrs[6])[:g.len] } else { g_result = (^_T06)(ptrs[6]) }
    when intrinsics.type_is_slice(T07) { h_result = ([^]_T07)(ptrs[7])[:h.len] } else { h_result = (^_T07)(ptrs[7]) }
    when intrinsics.type_is_slice(T08) { i_result = ([^]_T08)(ptrs[8])[:i.len] } else { i_result = (^_T08)(ptrs[8]) }
    when intrinsics.type_is_slice(T09) { j_result = ([^]_T09)(ptrs[9])[:j.len] } else { j_result = (^_T09)(ptrs[9]) }
    when intrinsics.type_is_slice(T10) { k_result = ([^]_T10)(ptrs[10])[:k.len] } else { k_result = (^_T10)(ptrs[10]) }
    when intrinsics.type_is_slice(T11) { l_result = ([^]_T11)(ptrs[11])[:l.len] } else { l_result = (^_T11)(ptrs[11]) }
    when intrinsics.type_is_slice(T12) { m_result = ([^]_T12)(ptrs[12])[:m.len] } else { m_result = (^_T12)(ptrs[12]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, g_result, h_result, i_result, j_result, k_result, l_result, m_result, nil
}

make_multi_14 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), g: Make_Multi($T06), h: Make_Multi($T07), i: Make_Multi($T08), j: Make_Multi($T09), k: Make_Multi($T10), l: Make_Multi($T11), m: Make_Multi($T12), n: Make_Multi($T13), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, T06, T07, T08, T09, T10, T11, T12, T13, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05)) &&
          (intrinsics.type_is_slice(T06) || intrinsics.type_is_pointer(T06)) &&
          (intrinsics.type_is_slice(T07) || intrinsics.type_is_pointer(T07)) &&
          (intrinsics.type_is_slice(T08) || intrinsics.type_is_pointer(T08)) &&
          (intrinsics.type_is_slice(T09) || intrinsics.type_is_pointer(T09)) &&
          (intrinsics.type_is_slice(T10) || intrinsics.type_is_pointer(T10)) &&
          (intrinsics.type_is_slice(T11) || intrinsics.type_is_pointer(T11)) &&
          (intrinsics.type_is_slice(T12) || intrinsics.type_is_pointer(T12)) &&
          (intrinsics.type_is_slice(T13) || intrinsics.type_is_pointer(T13))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    _T06 :: intrinsics.type_elem_type(T06)
    _T07 :: intrinsics.type_elem_type(T07)
    _T08 :: intrinsics.type_elem_type(T08)
    _T09 :: intrinsics.type_elem_type(T09)
    _T10 :: intrinsics.type_elem_type(T10)
    _T11 :: intrinsics.type_elem_type(T11)
    _T12 :: intrinsics.type_elem_type(T12)
    _T13 :: intrinsics.type_elem_type(T13)
    resolved := [14]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
        { size_of(_T06), g.alignment == 0 ? align_of(_T06) : g.alignment },
        { size_of(_T07), h.alignment == 0 ? align_of(_T07) : h.alignment },
        { size_of(_T08), i.alignment == 0 ? align_of(_T08) : i.alignment },
        { size_of(_T09), j.alignment == 0 ? align_of(_T09) : j.alignment },
        { size_of(_T10), k.alignment == 0 ? align_of(_T10) : k.alignment },
        { size_of(_T11), l.alignment == 0 ? align_of(_T11) : l.alignment },
        { size_of(_T12), m.alignment == 0 ? align_of(_T12) : m.alignment },
        { size_of(_T13), n.alignment == 0 ? align_of(_T13) : n.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    when intrinsics.type_is_slice(T06) { assert(g.len >= 0 ); resolved[6].size *= g.len; if (g.len == 0) { resolved[6].alignment = 1 } } else { assert(g.len == 0) }
    when intrinsics.type_is_slice(T07) { assert(h.len >= 0 ); resolved[7].size *= h.len; if (h.len == 0) { resolved[7].alignment = 1 } } else { assert(h.len == 0) }
    when intrinsics.type_is_slice(T08) { assert(i.len >= 0 ); resolved[8].size *= i.len; if (i.len == 0) { resolved[8].alignment = 1 } } else { assert(i.len == 0) }
    when intrinsics.type_is_slice(T09) { assert(j.len >= 0 ); resolved[9].size *= j.len; if (j.len == 0) { resolved[9].alignment = 1 } } else { assert(j.len == 0) }
    when intrinsics.type_is_slice(T10) { assert(k.len >= 0 ); resolved[10].size *= k.len; if (k.len == 0) { resolved[10].alignment = 1 } } else { assert(k.len == 0) }
    when intrinsics.type_is_slice(T11) { assert(l.len >= 0 ); resolved[11].size *= l.len; if (l.len == 0) { resolved[11].alignment = 1 } } else { assert(l.len == 0) }
    when intrinsics.type_is_slice(T12) { assert(m.len >= 0 ); resolved[12].size *= m.len; if (m.len == 0) { resolved[12].alignment = 1 } } else { assert(m.len == 0) }
    when intrinsics.type_is_slice(T13) { assert(n.len >= 0 ); resolved[13].size *= n.len; if (n.len == 0) { resolved[13].alignment = 1 } } else { assert(n.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    g_result: T06 = ---
    h_result: T07 = ---
    i_result: T08 = ---
    j_result: T09 = ---
    k_result: T10 = ---
    l_result: T11 = ---
    m_result: T12 = ---
    n_result: T13 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    when intrinsics.type_is_slice(T06) { g_result = ([^]_T06)(ptrs[6])[:g.len] } else { g_result = (^_T06)(ptrs[6]) }
    when intrinsics.type_is_slice(T07) { h_result = ([^]_T07)(ptrs[7])[:h.len] } else { h_result = (^_T07)(ptrs[7]) }
    when intrinsics.type_is_slice(T08) { i_result = ([^]_T08)(ptrs[8])[:i.len] } else { i_result = (^_T08)(ptrs[8]) }
    when intrinsics.type_is_slice(T09) { j_result = ([^]_T09)(ptrs[9])[:j.len] } else { j_result = (^_T09)(ptrs[9]) }
    when intrinsics.type_is_slice(T10) { k_result = ([^]_T10)(ptrs[10])[:k.len] } else { k_result = (^_T10)(ptrs[10]) }
    when intrinsics.type_is_slice(T11) { l_result = ([^]_T11)(ptrs[11])[:l.len] } else { l_result = (^_T11)(ptrs[11]) }
    when intrinsics.type_is_slice(T12) { m_result = ([^]_T12)(ptrs[12])[:m.len] } else { m_result = (^_T12)(ptrs[12]) }
    when intrinsics.type_is_slice(T13) { n_result = ([^]_T13)(ptrs[13])[:n.len] } else { n_result = (^_T13)(ptrs[13]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, g_result, h_result, i_result, j_result, k_result, l_result, m_result, n_result, nil
}

make_multi_15 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), g: Make_Multi($T06), h: Make_Multi($T07), i: Make_Multi($T08), j: Make_Multi($T09), k: Make_Multi($T10), l: Make_Multi($T11), m: Make_Multi($T12), n: Make_Multi($T13), o: Make_Multi($T14), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, T06, T07, T08, T09, T10, T11, T12, T13, T14, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05)) &&
          (intrinsics.type_is_slice(T06) || intrinsics.type_is_pointer(T06)) &&
          (intrinsics.type_is_slice(T07) || intrinsics.type_is_pointer(T07)) &&
          (intrinsics.type_is_slice(T08) || intrinsics.type_is_pointer(T08)) &&
          (intrinsics.type_is_slice(T09) || intrinsics.type_is_pointer(T09)) &&
          (intrinsics.type_is_slice(T10) || intrinsics.type_is_pointer(T10)) &&
          (intrinsics.type_is_slice(T11) || intrinsics.type_is_pointer(T11)) &&
          (intrinsics.type_is_slice(T12) || intrinsics.type_is_pointer(T12)) &&
          (intrinsics.type_is_slice(T13) || intrinsics.type_is_pointer(T13)) &&
          (intrinsics.type_is_slice(T14) || intrinsics.type_is_pointer(T14))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    _T06 :: intrinsics.type_elem_type(T06)
    _T07 :: intrinsics.type_elem_type(T07)
    _T08 :: intrinsics.type_elem_type(T08)
    _T09 :: intrinsics.type_elem_type(T09)
    _T10 :: intrinsics.type_elem_type(T10)
    _T11 :: intrinsics.type_elem_type(T11)
    _T12 :: intrinsics.type_elem_type(T12)
    _T13 :: intrinsics.type_elem_type(T13)
    _T14 :: intrinsics.type_elem_type(T14)
    resolved := [15]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
        { size_of(_T06), g.alignment == 0 ? align_of(_T06) : g.alignment },
        { size_of(_T07), h.alignment == 0 ? align_of(_T07) : h.alignment },
        { size_of(_T08), i.alignment == 0 ? align_of(_T08) : i.alignment },
        { size_of(_T09), j.alignment == 0 ? align_of(_T09) : j.alignment },
        { size_of(_T10), k.alignment == 0 ? align_of(_T10) : k.alignment },
        { size_of(_T11), l.alignment == 0 ? align_of(_T11) : l.alignment },
        { size_of(_T12), m.alignment == 0 ? align_of(_T12) : m.alignment },
        { size_of(_T13), n.alignment == 0 ? align_of(_T13) : n.alignment },
        { size_of(_T14), o.alignment == 0 ? align_of(_T14) : o.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    when intrinsics.type_is_slice(T06) { assert(g.len >= 0 ); resolved[6].size *= g.len; if (g.len == 0) { resolved[6].alignment = 1 } } else { assert(g.len == 0) }
    when intrinsics.type_is_slice(T07) { assert(h.len >= 0 ); resolved[7].size *= h.len; if (h.len == 0) { resolved[7].alignment = 1 } } else { assert(h.len == 0) }
    when intrinsics.type_is_slice(T08) { assert(i.len >= 0 ); resolved[8].size *= i.len; if (i.len == 0) { resolved[8].alignment = 1 } } else { assert(i.len == 0) }
    when intrinsics.type_is_slice(T09) { assert(j.len >= 0 ); resolved[9].size *= j.len; if (j.len == 0) { resolved[9].alignment = 1 } } else { assert(j.len == 0) }
    when intrinsics.type_is_slice(T10) { assert(k.len >= 0 ); resolved[10].size *= k.len; if (k.len == 0) { resolved[10].alignment = 1 } } else { assert(k.len == 0) }
    when intrinsics.type_is_slice(T11) { assert(l.len >= 0 ); resolved[11].size *= l.len; if (l.len == 0) { resolved[11].alignment = 1 } } else { assert(l.len == 0) }
    when intrinsics.type_is_slice(T12) { assert(m.len >= 0 ); resolved[12].size *= m.len; if (m.len == 0) { resolved[12].alignment = 1 } } else { assert(m.len == 0) }
    when intrinsics.type_is_slice(T13) { assert(n.len >= 0 ); resolved[13].size *= n.len; if (n.len == 0) { resolved[13].alignment = 1 } } else { assert(n.len == 0) }
    when intrinsics.type_is_slice(T14) { assert(o.len >= 0 ); resolved[14].size *= o.len; if (o.len == 0) { resolved[14].alignment = 1 } } else { assert(o.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    g_result: T06 = ---
    h_result: T07 = ---
    i_result: T08 = ---
    j_result: T09 = ---
    k_result: T10 = ---
    l_result: T11 = ---
    m_result: T12 = ---
    n_result: T13 = ---
    o_result: T14 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    when intrinsics.type_is_slice(T06) { g_result = ([^]_T06)(ptrs[6])[:g.len] } else { g_result = (^_T06)(ptrs[6]) }
    when intrinsics.type_is_slice(T07) { h_result = ([^]_T07)(ptrs[7])[:h.len] } else { h_result = (^_T07)(ptrs[7]) }
    when intrinsics.type_is_slice(T08) { i_result = ([^]_T08)(ptrs[8])[:i.len] } else { i_result = (^_T08)(ptrs[8]) }
    when intrinsics.type_is_slice(T09) { j_result = ([^]_T09)(ptrs[9])[:j.len] } else { j_result = (^_T09)(ptrs[9]) }
    when intrinsics.type_is_slice(T10) { k_result = ([^]_T10)(ptrs[10])[:k.len] } else { k_result = (^_T10)(ptrs[10]) }
    when intrinsics.type_is_slice(T11) { l_result = ([^]_T11)(ptrs[11])[:l.len] } else { l_result = (^_T11)(ptrs[11]) }
    when intrinsics.type_is_slice(T12) { m_result = ([^]_T12)(ptrs[12])[:m.len] } else { m_result = (^_T12)(ptrs[12]) }
    when intrinsics.type_is_slice(T13) { n_result = ([^]_T13)(ptrs[13])[:n.len] } else { n_result = (^_T13)(ptrs[13]) }
    when intrinsics.type_is_slice(T14) { o_result = ([^]_T14)(ptrs[14])[:o.len] } else { o_result = (^_T14)(ptrs[14]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, g_result, h_result, i_result, j_result, k_result, l_result, m_result, n_result, o_result, nil
}

make_multi_16 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), g: Make_Multi($T06), h: Make_Multi($T07), i: Make_Multi($T08), j: Make_Multi($T09), k: Make_Multi($T10), l: Make_Multi($T11), m: Make_Multi($T12), n: Make_Multi($T13), o: Make_Multi($T14), p: Make_Multi($T15), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, T06, T07, T08, T09, T10, T11, T12, T13, T14, T15, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05)) &&
          (intrinsics.type_is_slice(T06) || intrinsics.type_is_pointer(T06)) &&
          (intrinsics.type_is_slice(T07) || intrinsics.type_is_pointer(T07)) &&
          (intrinsics.type_is_slice(T08) || intrinsics.type_is_pointer(T08)) &&
          (intrinsics.type_is_slice(T09) || intrinsics.type_is_pointer(T09)) &&
          (intrinsics.type_is_slice(T10) || intrinsics.type_is_pointer(T10)) &&
          (intrinsics.type_is_slice(T11) || intrinsics.type_is_pointer(T11)) &&
          (intrinsics.type_is_slice(T12) || intrinsics.type_is_pointer(T12)) &&
          (intrinsics.type_is_slice(T13) || intrinsics.type_is_pointer(T13)) &&
          (intrinsics.type_is_slice(T14) || intrinsics.type_is_pointer(T14)) &&
          (intrinsics.type_is_slice(T15) || intrinsics.type_is_pointer(T15))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    _T06 :: intrinsics.type_elem_type(T06)
    _T07 :: intrinsics.type_elem_type(T07)
    _T08 :: intrinsics.type_elem_type(T08)
    _T09 :: intrinsics.type_elem_type(T09)
    _T10 :: intrinsics.type_elem_type(T10)
    _T11 :: intrinsics.type_elem_type(T11)
    _T12 :: intrinsics.type_elem_type(T12)
    _T13 :: intrinsics.type_elem_type(T13)
    _T14 :: intrinsics.type_elem_type(T14)
    _T15 :: intrinsics.type_elem_type(T15)
    resolved := [16]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
        { size_of(_T06), g.alignment == 0 ? align_of(_T06) : g.alignment },
        { size_of(_T07), h.alignment == 0 ? align_of(_T07) : h.alignment },
        { size_of(_T08), i.alignment == 0 ? align_of(_T08) : i.alignment },
        { size_of(_T09), j.alignment == 0 ? align_of(_T09) : j.alignment },
        { size_of(_T10), k.alignment == 0 ? align_of(_T10) : k.alignment },
        { size_of(_T11), l.alignment == 0 ? align_of(_T11) : l.alignment },
        { size_of(_T12), m.alignment == 0 ? align_of(_T12) : m.alignment },
        { size_of(_T13), n.alignment == 0 ? align_of(_T13) : n.alignment },
        { size_of(_T14), o.alignment == 0 ? align_of(_T14) : o.alignment },
        { size_of(_T15), p.alignment == 0 ? align_of(_T15) : p.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    when intrinsics.type_is_slice(T06) { assert(g.len >= 0 ); resolved[6].size *= g.len; if (g.len == 0) { resolved[6].alignment = 1 } } else { assert(g.len == 0) }
    when intrinsics.type_is_slice(T07) { assert(h.len >= 0 ); resolved[7].size *= h.len; if (h.len == 0) { resolved[7].alignment = 1 } } else { assert(h.len == 0) }
    when intrinsics.type_is_slice(T08) { assert(i.len >= 0 ); resolved[8].size *= i.len; if (i.len == 0) { resolved[8].alignment = 1 } } else { assert(i.len == 0) }
    when intrinsics.type_is_slice(T09) { assert(j.len >= 0 ); resolved[9].size *= j.len; if (j.len == 0) { resolved[9].alignment = 1 } } else { assert(j.len == 0) }
    when intrinsics.type_is_slice(T10) { assert(k.len >= 0 ); resolved[10].size *= k.len; if (k.len == 0) { resolved[10].alignment = 1 } } else { assert(k.len == 0) }
    when intrinsics.type_is_slice(T11) { assert(l.len >= 0 ); resolved[11].size *= l.len; if (l.len == 0) { resolved[11].alignment = 1 } } else { assert(l.len == 0) }
    when intrinsics.type_is_slice(T12) { assert(m.len >= 0 ); resolved[12].size *= m.len; if (m.len == 0) { resolved[12].alignment = 1 } } else { assert(m.len == 0) }
    when intrinsics.type_is_slice(T13) { assert(n.len >= 0 ); resolved[13].size *= n.len; if (n.len == 0) { resolved[13].alignment = 1 } } else { assert(n.len == 0) }
    when intrinsics.type_is_slice(T14) { assert(o.len >= 0 ); resolved[14].size *= o.len; if (o.len == 0) { resolved[14].alignment = 1 } } else { assert(o.len == 0) }
    when intrinsics.type_is_slice(T15) { assert(p.len >= 0 ); resolved[15].size *= p.len; if (p.len == 0) { resolved[15].alignment = 1 } } else { assert(p.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    g_result: T06 = ---
    h_result: T07 = ---
    i_result: T08 = ---
    j_result: T09 = ---
    k_result: T10 = ---
    l_result: T11 = ---
    m_result: T12 = ---
    n_result: T13 = ---
    o_result: T14 = ---
    p_result: T15 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    when intrinsics.type_is_slice(T06) { g_result = ([^]_T06)(ptrs[6])[:g.len] } else { g_result = (^_T06)(ptrs[6]) }
    when intrinsics.type_is_slice(T07) { h_result = ([^]_T07)(ptrs[7])[:h.len] } else { h_result = (^_T07)(ptrs[7]) }
    when intrinsics.type_is_slice(T08) { i_result = ([^]_T08)(ptrs[8])[:i.len] } else { i_result = (^_T08)(ptrs[8]) }
    when intrinsics.type_is_slice(T09) { j_result = ([^]_T09)(ptrs[9])[:j.len] } else { j_result = (^_T09)(ptrs[9]) }
    when intrinsics.type_is_slice(T10) { k_result = ([^]_T10)(ptrs[10])[:k.len] } else { k_result = (^_T10)(ptrs[10]) }
    when intrinsics.type_is_slice(T11) { l_result = ([^]_T11)(ptrs[11])[:l.len] } else { l_result = (^_T11)(ptrs[11]) }
    when intrinsics.type_is_slice(T12) { m_result = ([^]_T12)(ptrs[12])[:m.len] } else { m_result = (^_T12)(ptrs[12]) }
    when intrinsics.type_is_slice(T13) { n_result = ([^]_T13)(ptrs[13])[:n.len] } else { n_result = (^_T13)(ptrs[13]) }
    when intrinsics.type_is_slice(T14) { o_result = ([^]_T14)(ptrs[14])[:o.len] } else { o_result = (^_T14)(ptrs[14]) }
    when intrinsics.type_is_slice(T15) { p_result = ([^]_T15)(ptrs[15])[:p.len] } else { p_result = (^_T15)(ptrs[15]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, g_result, h_result, i_result, j_result, k_result, l_result, m_result, n_result, o_result, p_result, nil
}

make_multi_17 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), g: Make_Multi($T06), h: Make_Multi($T07), i: Make_Multi($T08), j: Make_Multi($T09), k: Make_Multi($T10), l: Make_Multi($T11), m: Make_Multi($T12), n: Make_Multi($T13), o: Make_Multi($T14), p: Make_Multi($T15), q: Make_Multi($T16), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, T06, T07, T08, T09, T10, T11, T12, T13, T14, T15, T16, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05)) &&
          (intrinsics.type_is_slice(T06) || intrinsics.type_is_pointer(T06)) &&
          (intrinsics.type_is_slice(T07) || intrinsics.type_is_pointer(T07)) &&
          (intrinsics.type_is_slice(T08) || intrinsics.type_is_pointer(T08)) &&
          (intrinsics.type_is_slice(T09) || intrinsics.type_is_pointer(T09)) &&
          (intrinsics.type_is_slice(T10) || intrinsics.type_is_pointer(T10)) &&
          (intrinsics.type_is_slice(T11) || intrinsics.type_is_pointer(T11)) &&
          (intrinsics.type_is_slice(T12) || intrinsics.type_is_pointer(T12)) &&
          (intrinsics.type_is_slice(T13) || intrinsics.type_is_pointer(T13)) &&
          (intrinsics.type_is_slice(T14) || intrinsics.type_is_pointer(T14)) &&
          (intrinsics.type_is_slice(T15) || intrinsics.type_is_pointer(T15)) &&
          (intrinsics.type_is_slice(T16) || intrinsics.type_is_pointer(T16))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    _T06 :: intrinsics.type_elem_type(T06)
    _T07 :: intrinsics.type_elem_type(T07)
    _T08 :: intrinsics.type_elem_type(T08)
    _T09 :: intrinsics.type_elem_type(T09)
    _T10 :: intrinsics.type_elem_type(T10)
    _T11 :: intrinsics.type_elem_type(T11)
    _T12 :: intrinsics.type_elem_type(T12)
    _T13 :: intrinsics.type_elem_type(T13)
    _T14 :: intrinsics.type_elem_type(T14)
    _T15 :: intrinsics.type_elem_type(T15)
    _T16 :: intrinsics.type_elem_type(T16)
    resolved := [17]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
        { size_of(_T06), g.alignment == 0 ? align_of(_T06) : g.alignment },
        { size_of(_T07), h.alignment == 0 ? align_of(_T07) : h.alignment },
        { size_of(_T08), i.alignment == 0 ? align_of(_T08) : i.alignment },
        { size_of(_T09), j.alignment == 0 ? align_of(_T09) : j.alignment },
        { size_of(_T10), k.alignment == 0 ? align_of(_T10) : k.alignment },
        { size_of(_T11), l.alignment == 0 ? align_of(_T11) : l.alignment },
        { size_of(_T12), m.alignment == 0 ? align_of(_T12) : m.alignment },
        { size_of(_T13), n.alignment == 0 ? align_of(_T13) : n.alignment },
        { size_of(_T14), o.alignment == 0 ? align_of(_T14) : o.alignment },
        { size_of(_T15), p.alignment == 0 ? align_of(_T15) : p.alignment },
        { size_of(_T16), q.alignment == 0 ? align_of(_T16) : q.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    when intrinsics.type_is_slice(T06) { assert(g.len >= 0 ); resolved[6].size *= g.len; if (g.len == 0) { resolved[6].alignment = 1 } } else { assert(g.len == 0) }
    when intrinsics.type_is_slice(T07) { assert(h.len >= 0 ); resolved[7].size *= h.len; if (h.len == 0) { resolved[7].alignment = 1 } } else { assert(h.len == 0) }
    when intrinsics.type_is_slice(T08) { assert(i.len >= 0 ); resolved[8].size *= i.len; if (i.len == 0) { resolved[8].alignment = 1 } } else { assert(i.len == 0) }
    when intrinsics.type_is_slice(T09) { assert(j.len >= 0 ); resolved[9].size *= j.len; if (j.len == 0) { resolved[9].alignment = 1 } } else { assert(j.len == 0) }
    when intrinsics.type_is_slice(T10) { assert(k.len >= 0 ); resolved[10].size *= k.len; if (k.len == 0) { resolved[10].alignment = 1 } } else { assert(k.len == 0) }
    when intrinsics.type_is_slice(T11) { assert(l.len >= 0 ); resolved[11].size *= l.len; if (l.len == 0) { resolved[11].alignment = 1 } } else { assert(l.len == 0) }
    when intrinsics.type_is_slice(T12) { assert(m.len >= 0 ); resolved[12].size *= m.len; if (m.len == 0) { resolved[12].alignment = 1 } } else { assert(m.len == 0) }
    when intrinsics.type_is_slice(T13) { assert(n.len >= 0 ); resolved[13].size *= n.len; if (n.len == 0) { resolved[13].alignment = 1 } } else { assert(n.len == 0) }
    when intrinsics.type_is_slice(T14) { assert(o.len >= 0 ); resolved[14].size *= o.len; if (o.len == 0) { resolved[14].alignment = 1 } } else { assert(o.len == 0) }
    when intrinsics.type_is_slice(T15) { assert(p.len >= 0 ); resolved[15].size *= p.len; if (p.len == 0) { resolved[15].alignment = 1 } } else { assert(p.len == 0) }
    when intrinsics.type_is_slice(T16) { assert(q.len >= 0 ); resolved[16].size *= q.len; if (q.len == 0) { resolved[16].alignment = 1 } } else { assert(q.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    g_result: T06 = ---
    h_result: T07 = ---
    i_result: T08 = ---
    j_result: T09 = ---
    k_result: T10 = ---
    l_result: T11 = ---
    m_result: T12 = ---
    n_result: T13 = ---
    o_result: T14 = ---
    p_result: T15 = ---
    q_result: T16 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    when intrinsics.type_is_slice(T06) { g_result = ([^]_T06)(ptrs[6])[:g.len] } else { g_result = (^_T06)(ptrs[6]) }
    when intrinsics.type_is_slice(T07) { h_result = ([^]_T07)(ptrs[7])[:h.len] } else { h_result = (^_T07)(ptrs[7]) }
    when intrinsics.type_is_slice(T08) { i_result = ([^]_T08)(ptrs[8])[:i.len] } else { i_result = (^_T08)(ptrs[8]) }
    when intrinsics.type_is_slice(T09) { j_result = ([^]_T09)(ptrs[9])[:j.len] } else { j_result = (^_T09)(ptrs[9]) }
    when intrinsics.type_is_slice(T10) { k_result = ([^]_T10)(ptrs[10])[:k.len] } else { k_result = (^_T10)(ptrs[10]) }
    when intrinsics.type_is_slice(T11) { l_result = ([^]_T11)(ptrs[11])[:l.len] } else { l_result = (^_T11)(ptrs[11]) }
    when intrinsics.type_is_slice(T12) { m_result = ([^]_T12)(ptrs[12])[:m.len] } else { m_result = (^_T12)(ptrs[12]) }
    when intrinsics.type_is_slice(T13) { n_result = ([^]_T13)(ptrs[13])[:n.len] } else { n_result = (^_T13)(ptrs[13]) }
    when intrinsics.type_is_slice(T14) { o_result = ([^]_T14)(ptrs[14])[:o.len] } else { o_result = (^_T14)(ptrs[14]) }
    when intrinsics.type_is_slice(T15) { p_result = ([^]_T15)(ptrs[15])[:p.len] } else { p_result = (^_T15)(ptrs[15]) }
    when intrinsics.type_is_slice(T16) { q_result = ([^]_T16)(ptrs[16])[:q.len] } else { q_result = (^_T16)(ptrs[16]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, g_result, h_result, i_result, j_result, k_result, l_result, m_result, n_result, o_result, p_result, q_result, nil
}

make_multi_18 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), g: Make_Multi($T06), h: Make_Multi($T07), i: Make_Multi($T08), j: Make_Multi($T09), k: Make_Multi($T10), l: Make_Multi($T11), m: Make_Multi($T12), n: Make_Multi($T13), o: Make_Multi($T14), p: Make_Multi($T15), q: Make_Multi($T16), r: Make_Multi($T17), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, T06, T07, T08, T09, T10, T11, T12, T13, T14, T15, T16, T17, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05)) &&
          (intrinsics.type_is_slice(T06) || intrinsics.type_is_pointer(T06)) &&
          (intrinsics.type_is_slice(T07) || intrinsics.type_is_pointer(T07)) &&
          (intrinsics.type_is_slice(T08) || intrinsics.type_is_pointer(T08)) &&
          (intrinsics.type_is_slice(T09) || intrinsics.type_is_pointer(T09)) &&
          (intrinsics.type_is_slice(T10) || intrinsics.type_is_pointer(T10)) &&
          (intrinsics.type_is_slice(T11) || intrinsics.type_is_pointer(T11)) &&
          (intrinsics.type_is_slice(T12) || intrinsics.type_is_pointer(T12)) &&
          (intrinsics.type_is_slice(T13) || intrinsics.type_is_pointer(T13)) &&
          (intrinsics.type_is_slice(T14) || intrinsics.type_is_pointer(T14)) &&
          (intrinsics.type_is_slice(T15) || intrinsics.type_is_pointer(T15)) &&
          (intrinsics.type_is_slice(T16) || intrinsics.type_is_pointer(T16)) &&
          (intrinsics.type_is_slice(T17) || intrinsics.type_is_pointer(T17))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    _T06 :: intrinsics.type_elem_type(T06)
    _T07 :: intrinsics.type_elem_type(T07)
    _T08 :: intrinsics.type_elem_type(T08)
    _T09 :: intrinsics.type_elem_type(T09)
    _T10 :: intrinsics.type_elem_type(T10)
    _T11 :: intrinsics.type_elem_type(T11)
    _T12 :: intrinsics.type_elem_type(T12)
    _T13 :: intrinsics.type_elem_type(T13)
    _T14 :: intrinsics.type_elem_type(T14)
    _T15 :: intrinsics.type_elem_type(T15)
    _T16 :: intrinsics.type_elem_type(T16)
    _T17 :: intrinsics.type_elem_type(T17)
    resolved := [18]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
        { size_of(_T06), g.alignment == 0 ? align_of(_T06) : g.alignment },
        { size_of(_T07), h.alignment == 0 ? align_of(_T07) : h.alignment },
        { size_of(_T08), i.alignment == 0 ? align_of(_T08) : i.alignment },
        { size_of(_T09), j.alignment == 0 ? align_of(_T09) : j.alignment },
        { size_of(_T10), k.alignment == 0 ? align_of(_T10) : k.alignment },
        { size_of(_T11), l.alignment == 0 ? align_of(_T11) : l.alignment },
        { size_of(_T12), m.alignment == 0 ? align_of(_T12) : m.alignment },
        { size_of(_T13), n.alignment == 0 ? align_of(_T13) : n.alignment },
        { size_of(_T14), o.alignment == 0 ? align_of(_T14) : o.alignment },
        { size_of(_T15), p.alignment == 0 ? align_of(_T15) : p.alignment },
        { size_of(_T16), q.alignment == 0 ? align_of(_T16) : q.alignment },
        { size_of(_T17), r.alignment == 0 ? align_of(_T17) : r.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    when intrinsics.type_is_slice(T06) { assert(g.len >= 0 ); resolved[6].size *= g.len; if (g.len == 0) { resolved[6].alignment = 1 } } else { assert(g.len == 0) }
    when intrinsics.type_is_slice(T07) { assert(h.len >= 0 ); resolved[7].size *= h.len; if (h.len == 0) { resolved[7].alignment = 1 } } else { assert(h.len == 0) }
    when intrinsics.type_is_slice(T08) { assert(i.len >= 0 ); resolved[8].size *= i.len; if (i.len == 0) { resolved[8].alignment = 1 } } else { assert(i.len == 0) }
    when intrinsics.type_is_slice(T09) { assert(j.len >= 0 ); resolved[9].size *= j.len; if (j.len == 0) { resolved[9].alignment = 1 } } else { assert(j.len == 0) }
    when intrinsics.type_is_slice(T10) { assert(k.len >= 0 ); resolved[10].size *= k.len; if (k.len == 0) { resolved[10].alignment = 1 } } else { assert(k.len == 0) }
    when intrinsics.type_is_slice(T11) { assert(l.len >= 0 ); resolved[11].size *= l.len; if (l.len == 0) { resolved[11].alignment = 1 } } else { assert(l.len == 0) }
    when intrinsics.type_is_slice(T12) { assert(m.len >= 0 ); resolved[12].size *= m.len; if (m.len == 0) { resolved[12].alignment = 1 } } else { assert(m.len == 0) }
    when intrinsics.type_is_slice(T13) { assert(n.len >= 0 ); resolved[13].size *= n.len; if (n.len == 0) { resolved[13].alignment = 1 } } else { assert(n.len == 0) }
    when intrinsics.type_is_slice(T14) { assert(o.len >= 0 ); resolved[14].size *= o.len; if (o.len == 0) { resolved[14].alignment = 1 } } else { assert(o.len == 0) }
    when intrinsics.type_is_slice(T15) { assert(p.len >= 0 ); resolved[15].size *= p.len; if (p.len == 0) { resolved[15].alignment = 1 } } else { assert(p.len == 0) }
    when intrinsics.type_is_slice(T16) { assert(q.len >= 0 ); resolved[16].size *= q.len; if (q.len == 0) { resolved[16].alignment = 1 } } else { assert(q.len == 0) }
    when intrinsics.type_is_slice(T17) { assert(r.len >= 0 ); resolved[17].size *= r.len; if (r.len == 0) { resolved[17].alignment = 1 } } else { assert(r.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    g_result: T06 = ---
    h_result: T07 = ---
    i_result: T08 = ---
    j_result: T09 = ---
    k_result: T10 = ---
    l_result: T11 = ---
    m_result: T12 = ---
    n_result: T13 = ---
    o_result: T14 = ---
    p_result: T15 = ---
    q_result: T16 = ---
    r_result: T17 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    when intrinsics.type_is_slice(T06) { g_result = ([^]_T06)(ptrs[6])[:g.len] } else { g_result = (^_T06)(ptrs[6]) }
    when intrinsics.type_is_slice(T07) { h_result = ([^]_T07)(ptrs[7])[:h.len] } else { h_result = (^_T07)(ptrs[7]) }
    when intrinsics.type_is_slice(T08) { i_result = ([^]_T08)(ptrs[8])[:i.len] } else { i_result = (^_T08)(ptrs[8]) }
    when intrinsics.type_is_slice(T09) { j_result = ([^]_T09)(ptrs[9])[:j.len] } else { j_result = (^_T09)(ptrs[9]) }
    when intrinsics.type_is_slice(T10) { k_result = ([^]_T10)(ptrs[10])[:k.len] } else { k_result = (^_T10)(ptrs[10]) }
    when intrinsics.type_is_slice(T11) { l_result = ([^]_T11)(ptrs[11])[:l.len] } else { l_result = (^_T11)(ptrs[11]) }
    when intrinsics.type_is_slice(T12) { m_result = ([^]_T12)(ptrs[12])[:m.len] } else { m_result = (^_T12)(ptrs[12]) }
    when intrinsics.type_is_slice(T13) { n_result = ([^]_T13)(ptrs[13])[:n.len] } else { n_result = (^_T13)(ptrs[13]) }
    when intrinsics.type_is_slice(T14) { o_result = ([^]_T14)(ptrs[14])[:o.len] } else { o_result = (^_T14)(ptrs[14]) }
    when intrinsics.type_is_slice(T15) { p_result = ([^]_T15)(ptrs[15])[:p.len] } else { p_result = (^_T15)(ptrs[15]) }
    when intrinsics.type_is_slice(T16) { q_result = ([^]_T16)(ptrs[16])[:q.len] } else { q_result = (^_T16)(ptrs[16]) }
    when intrinsics.type_is_slice(T17) { r_result = ([^]_T17)(ptrs[17])[:r.len] } else { r_result = (^_T17)(ptrs[17]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, g_result, h_result, i_result, j_result, k_result, l_result, m_result, n_result, o_result, p_result, q_result, r_result, nil
}

make_multi_19 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), g: Make_Multi($T06), h: Make_Multi($T07), i: Make_Multi($T08), j: Make_Multi($T09), k: Make_Multi($T10), l: Make_Multi($T11), m: Make_Multi($T12), n: Make_Multi($T13), o: Make_Multi($T14), p: Make_Multi($T15), q: Make_Multi($T16), r: Make_Multi($T17), s: Make_Multi($T18), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, T06, T07, T08, T09, T10, T11, T12, T13, T14, T15, T16, T17, T18, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05)) &&
          (intrinsics.type_is_slice(T06) || intrinsics.type_is_pointer(T06)) &&
          (intrinsics.type_is_slice(T07) || intrinsics.type_is_pointer(T07)) &&
          (intrinsics.type_is_slice(T08) || intrinsics.type_is_pointer(T08)) &&
          (intrinsics.type_is_slice(T09) || intrinsics.type_is_pointer(T09)) &&
          (intrinsics.type_is_slice(T10) || intrinsics.type_is_pointer(T10)) &&
          (intrinsics.type_is_slice(T11) || intrinsics.type_is_pointer(T11)) &&
          (intrinsics.type_is_slice(T12) || intrinsics.type_is_pointer(T12)) &&
          (intrinsics.type_is_slice(T13) || intrinsics.type_is_pointer(T13)) &&
          (intrinsics.type_is_slice(T14) || intrinsics.type_is_pointer(T14)) &&
          (intrinsics.type_is_slice(T15) || intrinsics.type_is_pointer(T15)) &&
          (intrinsics.type_is_slice(T16) || intrinsics.type_is_pointer(T16)) &&
          (intrinsics.type_is_slice(T17) || intrinsics.type_is_pointer(T17)) &&
          (intrinsics.type_is_slice(T18) || intrinsics.type_is_pointer(T18))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    _T06 :: intrinsics.type_elem_type(T06)
    _T07 :: intrinsics.type_elem_type(T07)
    _T08 :: intrinsics.type_elem_type(T08)
    _T09 :: intrinsics.type_elem_type(T09)
    _T10 :: intrinsics.type_elem_type(T10)
    _T11 :: intrinsics.type_elem_type(T11)
    _T12 :: intrinsics.type_elem_type(T12)
    _T13 :: intrinsics.type_elem_type(T13)
    _T14 :: intrinsics.type_elem_type(T14)
    _T15 :: intrinsics.type_elem_type(T15)
    _T16 :: intrinsics.type_elem_type(T16)
    _T17 :: intrinsics.type_elem_type(T17)
    _T18 :: intrinsics.type_elem_type(T18)
    resolved := [19]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
        { size_of(_T06), g.alignment == 0 ? align_of(_T06) : g.alignment },
        { size_of(_T07), h.alignment == 0 ? align_of(_T07) : h.alignment },
        { size_of(_T08), i.alignment == 0 ? align_of(_T08) : i.alignment },
        { size_of(_T09), j.alignment == 0 ? align_of(_T09) : j.alignment },
        { size_of(_T10), k.alignment == 0 ? align_of(_T10) : k.alignment },
        { size_of(_T11), l.alignment == 0 ? align_of(_T11) : l.alignment },
        { size_of(_T12), m.alignment == 0 ? align_of(_T12) : m.alignment },
        { size_of(_T13), n.alignment == 0 ? align_of(_T13) : n.alignment },
        { size_of(_T14), o.alignment == 0 ? align_of(_T14) : o.alignment },
        { size_of(_T15), p.alignment == 0 ? align_of(_T15) : p.alignment },
        { size_of(_T16), q.alignment == 0 ? align_of(_T16) : q.alignment },
        { size_of(_T17), r.alignment == 0 ? align_of(_T17) : r.alignment },
        { size_of(_T18), s.alignment == 0 ? align_of(_T18) : s.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    when intrinsics.type_is_slice(T06) { assert(g.len >= 0 ); resolved[6].size *= g.len; if (g.len == 0) { resolved[6].alignment = 1 } } else { assert(g.len == 0) }
    when intrinsics.type_is_slice(T07) { assert(h.len >= 0 ); resolved[7].size *= h.len; if (h.len == 0) { resolved[7].alignment = 1 } } else { assert(h.len == 0) }
    when intrinsics.type_is_slice(T08) { assert(i.len >= 0 ); resolved[8].size *= i.len; if (i.len == 0) { resolved[8].alignment = 1 } } else { assert(i.len == 0) }
    when intrinsics.type_is_slice(T09) { assert(j.len >= 0 ); resolved[9].size *= j.len; if (j.len == 0) { resolved[9].alignment = 1 } } else { assert(j.len == 0) }
    when intrinsics.type_is_slice(T10) { assert(k.len >= 0 ); resolved[10].size *= k.len; if (k.len == 0) { resolved[10].alignment = 1 } } else { assert(k.len == 0) }
    when intrinsics.type_is_slice(T11) { assert(l.len >= 0 ); resolved[11].size *= l.len; if (l.len == 0) { resolved[11].alignment = 1 } } else { assert(l.len == 0) }
    when intrinsics.type_is_slice(T12) { assert(m.len >= 0 ); resolved[12].size *= m.len; if (m.len == 0) { resolved[12].alignment = 1 } } else { assert(m.len == 0) }
    when intrinsics.type_is_slice(T13) { assert(n.len >= 0 ); resolved[13].size *= n.len; if (n.len == 0) { resolved[13].alignment = 1 } } else { assert(n.len == 0) }
    when intrinsics.type_is_slice(T14) { assert(o.len >= 0 ); resolved[14].size *= o.len; if (o.len == 0) { resolved[14].alignment = 1 } } else { assert(o.len == 0) }
    when intrinsics.type_is_slice(T15) { assert(p.len >= 0 ); resolved[15].size *= p.len; if (p.len == 0) { resolved[15].alignment = 1 } } else { assert(p.len == 0) }
    when intrinsics.type_is_slice(T16) { assert(q.len >= 0 ); resolved[16].size *= q.len; if (q.len == 0) { resolved[16].alignment = 1 } } else { assert(q.len == 0) }
    when intrinsics.type_is_slice(T17) { assert(r.len >= 0 ); resolved[17].size *= r.len; if (r.len == 0) { resolved[17].alignment = 1 } } else { assert(r.len == 0) }
    when intrinsics.type_is_slice(T18) { assert(s.len >= 0 ); resolved[18].size *= s.len; if (s.len == 0) { resolved[18].alignment = 1 } } else { assert(s.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    g_result: T06 = ---
    h_result: T07 = ---
    i_result: T08 = ---
    j_result: T09 = ---
    k_result: T10 = ---
    l_result: T11 = ---
    m_result: T12 = ---
    n_result: T13 = ---
    o_result: T14 = ---
    p_result: T15 = ---
    q_result: T16 = ---
    r_result: T17 = ---
    s_result: T18 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    when intrinsics.type_is_slice(T06) { g_result = ([^]_T06)(ptrs[6])[:g.len] } else { g_result = (^_T06)(ptrs[6]) }
    when intrinsics.type_is_slice(T07) { h_result = ([^]_T07)(ptrs[7])[:h.len] } else { h_result = (^_T07)(ptrs[7]) }
    when intrinsics.type_is_slice(T08) { i_result = ([^]_T08)(ptrs[8])[:i.len] } else { i_result = (^_T08)(ptrs[8]) }
    when intrinsics.type_is_slice(T09) { j_result = ([^]_T09)(ptrs[9])[:j.len] } else { j_result = (^_T09)(ptrs[9]) }
    when intrinsics.type_is_slice(T10) { k_result = ([^]_T10)(ptrs[10])[:k.len] } else { k_result = (^_T10)(ptrs[10]) }
    when intrinsics.type_is_slice(T11) { l_result = ([^]_T11)(ptrs[11])[:l.len] } else { l_result = (^_T11)(ptrs[11]) }
    when intrinsics.type_is_slice(T12) { m_result = ([^]_T12)(ptrs[12])[:m.len] } else { m_result = (^_T12)(ptrs[12]) }
    when intrinsics.type_is_slice(T13) { n_result = ([^]_T13)(ptrs[13])[:n.len] } else { n_result = (^_T13)(ptrs[13]) }
    when intrinsics.type_is_slice(T14) { o_result = ([^]_T14)(ptrs[14])[:o.len] } else { o_result = (^_T14)(ptrs[14]) }
    when intrinsics.type_is_slice(T15) { p_result = ([^]_T15)(ptrs[15])[:p.len] } else { p_result = (^_T15)(ptrs[15]) }
    when intrinsics.type_is_slice(T16) { q_result = ([^]_T16)(ptrs[16])[:q.len] } else { q_result = (^_T16)(ptrs[16]) }
    when intrinsics.type_is_slice(T17) { r_result = ([^]_T17)(ptrs[17])[:r.len] } else { r_result = (^_T17)(ptrs[17]) }
    when intrinsics.type_is_slice(T18) { s_result = ([^]_T18)(ptrs[18])[:s.len] } else { s_result = (^_T18)(ptrs[18]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, g_result, h_result, i_result, j_result, k_result, l_result, m_result, n_result, o_result, p_result, q_result, r_result, s_result, nil
}

make_multi_20 :: proc(a: Make_Multi($T00), b: Make_Multi($T01), c: Make_Multi($T02), d: Make_Multi($T03), e: Make_Multi($T04), f: Make_Multi($T05), g: Make_Multi($T06), h: Make_Multi($T07), i: Make_Multi($T08), j: Make_Multi($T09), k: Make_Multi($T10), l: Make_Multi($T11), m: Make_Multi($T12), n: Make_Multi($T13), o: Make_Multi($T14), p: Make_Multi($T15), q: Make_Multi($T16), r: Make_Multi($T17), s: Make_Multi($T18), t: Make_Multi($T19), allocator: Allocator) ->
    (rawptr, T00, T01, T02, T03, T04, T05, T06, T07, T08, T09, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, Allocator_Error)
    where (intrinsics.type_is_slice(T00) || intrinsics.type_is_pointer(T00)) &&
          (intrinsics.type_is_slice(T01) || intrinsics.type_is_pointer(T01)) &&
          (intrinsics.type_is_slice(T02) || intrinsics.type_is_pointer(T02)) &&
          (intrinsics.type_is_slice(T03) || intrinsics.type_is_pointer(T03)) &&
          (intrinsics.type_is_slice(T04) || intrinsics.type_is_pointer(T04)) &&
          (intrinsics.type_is_slice(T05) || intrinsics.type_is_pointer(T05)) &&
          (intrinsics.type_is_slice(T06) || intrinsics.type_is_pointer(T06)) &&
          (intrinsics.type_is_slice(T07) || intrinsics.type_is_pointer(T07)) &&
          (intrinsics.type_is_slice(T08) || intrinsics.type_is_pointer(T08)) &&
          (intrinsics.type_is_slice(T09) || intrinsics.type_is_pointer(T09)) &&
          (intrinsics.type_is_slice(T10) || intrinsics.type_is_pointer(T10)) &&
          (intrinsics.type_is_slice(T11) || intrinsics.type_is_pointer(T11)) &&
          (intrinsics.type_is_slice(T12) || intrinsics.type_is_pointer(T12)) &&
          (intrinsics.type_is_slice(T13) || intrinsics.type_is_pointer(T13)) &&
          (intrinsics.type_is_slice(T14) || intrinsics.type_is_pointer(T14)) &&
          (intrinsics.type_is_slice(T15) || intrinsics.type_is_pointer(T15)) &&
          (intrinsics.type_is_slice(T16) || intrinsics.type_is_pointer(T16)) &&
          (intrinsics.type_is_slice(T17) || intrinsics.type_is_pointer(T17)) &&
          (intrinsics.type_is_slice(T18) || intrinsics.type_is_pointer(T18)) &&
          (intrinsics.type_is_slice(T19) || intrinsics.type_is_pointer(T19))
{
    _T00 :: intrinsics.type_elem_type(T00)
    _T01 :: intrinsics.type_elem_type(T01)
    _T02 :: intrinsics.type_elem_type(T02)
    _T03 :: intrinsics.type_elem_type(T03)
    _T04 :: intrinsics.type_elem_type(T04)
    _T05 :: intrinsics.type_elem_type(T05)
    _T06 :: intrinsics.type_elem_type(T06)
    _T07 :: intrinsics.type_elem_type(T07)
    _T08 :: intrinsics.type_elem_type(T08)
    _T09 :: intrinsics.type_elem_type(T09)
    _T10 :: intrinsics.type_elem_type(T10)
    _T11 :: intrinsics.type_elem_type(T11)
    _T12 :: intrinsics.type_elem_type(T12)
    _T13 :: intrinsics.type_elem_type(T13)
    _T14 :: intrinsics.type_elem_type(T14)
    _T15 :: intrinsics.type_elem_type(T15)
    _T16 :: intrinsics.type_elem_type(T16)
    _T17 :: intrinsics.type_elem_type(T17)
    _T18 :: intrinsics.type_elem_type(T18)
    _T19 :: intrinsics.type_elem_type(T19)
    resolved := [20]_Make_Multi_Resolved {
        { size_of(_T00), a.alignment == 0 ? align_of(_T00) : a.alignment },
        { size_of(_T01), b.alignment == 0 ? align_of(_T01) : b.alignment },
        { size_of(_T02), c.alignment == 0 ? align_of(_T02) : c.alignment },
        { size_of(_T03), d.alignment == 0 ? align_of(_T03) : d.alignment },
        { size_of(_T04), e.alignment == 0 ? align_of(_T04) : e.alignment },
        { size_of(_T05), f.alignment == 0 ? align_of(_T05) : f.alignment },
        { size_of(_T06), g.alignment == 0 ? align_of(_T06) : g.alignment },
        { size_of(_T07), h.alignment == 0 ? align_of(_T07) : h.alignment },
        { size_of(_T08), i.alignment == 0 ? align_of(_T08) : i.alignment },
        { size_of(_T09), j.alignment == 0 ? align_of(_T09) : j.alignment },
        { size_of(_T10), k.alignment == 0 ? align_of(_T10) : k.alignment },
        { size_of(_T11), l.alignment == 0 ? align_of(_T11) : l.alignment },
        { size_of(_T12), m.alignment == 0 ? align_of(_T12) : m.alignment },
        { size_of(_T13), n.alignment == 0 ? align_of(_T13) : n.alignment },
        { size_of(_T14), o.alignment == 0 ? align_of(_T14) : o.alignment },
        { size_of(_T15), p.alignment == 0 ? align_of(_T15) : p.alignment },
        { size_of(_T16), q.alignment == 0 ? align_of(_T16) : q.alignment },
        { size_of(_T17), r.alignment == 0 ? align_of(_T17) : r.alignment },
        { size_of(_T18), s.alignment == 0 ? align_of(_T18) : s.alignment },
        { size_of(_T19), t.alignment == 0 ? align_of(_T19) : t.alignment },
    }
    when intrinsics.type_is_slice(T00) { assert(a.len >= 0 ); resolved[0].size *= a.len; if (a.len == 0) { resolved[0].alignment = 1 } } else { assert(a.len == 0) }
    when intrinsics.type_is_slice(T01) { assert(b.len >= 0 ); resolved[1].size *= b.len; if (b.len == 0) { resolved[1].alignment = 1 } } else { assert(b.len == 0) }
    when intrinsics.type_is_slice(T02) { assert(c.len >= 0 ); resolved[2].size *= c.len; if (c.len == 0) { resolved[2].alignment = 1 } } else { assert(c.len == 0) }
    when intrinsics.type_is_slice(T03) { assert(d.len >= 0 ); resolved[3].size *= d.len; if (d.len == 0) { resolved[3].alignment = 1 } } else { assert(d.len == 0) }
    when intrinsics.type_is_slice(T04) { assert(e.len >= 0 ); resolved[4].size *= e.len; if (e.len == 0) { resolved[4].alignment = 1 } } else { assert(e.len == 0) }
    when intrinsics.type_is_slice(T05) { assert(f.len >= 0 ); resolved[5].size *= f.len; if (f.len == 0) { resolved[5].alignment = 1 } } else { assert(f.len == 0) }
    when intrinsics.type_is_slice(T06) { assert(g.len >= 0 ); resolved[6].size *= g.len; if (g.len == 0) { resolved[6].alignment = 1 } } else { assert(g.len == 0) }
    when intrinsics.type_is_slice(T07) { assert(h.len >= 0 ); resolved[7].size *= h.len; if (h.len == 0) { resolved[7].alignment = 1 } } else { assert(h.len == 0) }
    when intrinsics.type_is_slice(T08) { assert(i.len >= 0 ); resolved[8].size *= i.len; if (i.len == 0) { resolved[8].alignment = 1 } } else { assert(i.len == 0) }
    when intrinsics.type_is_slice(T09) { assert(j.len >= 0 ); resolved[9].size *= j.len; if (j.len == 0) { resolved[9].alignment = 1 } } else { assert(j.len == 0) }
    when intrinsics.type_is_slice(T10) { assert(k.len >= 0 ); resolved[10].size *= k.len; if (k.len == 0) { resolved[10].alignment = 1 } } else { assert(k.len == 0) }
    when intrinsics.type_is_slice(T11) { assert(l.len >= 0 ); resolved[11].size *= l.len; if (l.len == 0) { resolved[11].alignment = 1 } } else { assert(l.len == 0) }
    when intrinsics.type_is_slice(T12) { assert(m.len >= 0 ); resolved[12].size *= m.len; if (m.len == 0) { resolved[12].alignment = 1 } } else { assert(m.len == 0) }
    when intrinsics.type_is_slice(T13) { assert(n.len >= 0 ); resolved[13].size *= n.len; if (n.len == 0) { resolved[13].alignment = 1 } } else { assert(n.len == 0) }
    when intrinsics.type_is_slice(T14) { assert(o.len >= 0 ); resolved[14].size *= o.len; if (o.len == 0) { resolved[14].alignment = 1 } } else { assert(o.len == 0) }
    when intrinsics.type_is_slice(T15) { assert(p.len >= 0 ); resolved[15].size *= p.len; if (p.len == 0) { resolved[15].alignment = 1 } } else { assert(p.len == 0) }
    when intrinsics.type_is_slice(T16) { assert(q.len >= 0 ); resolved[16].size *= q.len; if (q.len == 0) { resolved[16].alignment = 1 } } else { assert(q.len == 0) }
    when intrinsics.type_is_slice(T17) { assert(r.len >= 0 ); resolved[17].size *= r.len; if (r.len == 0) { resolved[17].alignment = 1 } } else { assert(r.len == 0) }
    when intrinsics.type_is_slice(T18) { assert(s.len >= 0 ); resolved[18].size *= s.len; if (s.len == 0) { resolved[18].alignment = 1 } } else { assert(s.len == 0) }
    when intrinsics.type_is_slice(T19) { assert(t.len >= 0 ); resolved[19].size *= t.len; if (t.len == 0) { resolved[19].alignment = 1 } } else { assert(t.len == 0) }
    base, ptrs, err := _make_multi(resolved, allocator)
    if err != nil {
        return nil, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, err
    }
    a_result: T00 = ---
    b_result: T01 = ---
    c_result: T02 = ---
    d_result: T03 = ---
    e_result: T04 = ---
    f_result: T05 = ---
    g_result: T06 = ---
    h_result: T07 = ---
    i_result: T08 = ---
    j_result: T09 = ---
    k_result: T10 = ---
    l_result: T11 = ---
    m_result: T12 = ---
    n_result: T13 = ---
    o_result: T14 = ---
    p_result: T15 = ---
    q_result: T16 = ---
    r_result: T17 = ---
    s_result: T18 = ---
    t_result: T19 = ---
    when intrinsics.type_is_slice(T00) { a_result = ([^]_T00)(ptrs[0])[:a.len] } else { a_result = (^_T00)(ptrs[0]) }
    when intrinsics.type_is_slice(T01) { b_result = ([^]_T01)(ptrs[1])[:b.len] } else { b_result = (^_T01)(ptrs[1]) }
    when intrinsics.type_is_slice(T02) { c_result = ([^]_T02)(ptrs[2])[:c.len] } else { c_result = (^_T02)(ptrs[2]) }
    when intrinsics.type_is_slice(T03) { d_result = ([^]_T03)(ptrs[3])[:d.len] } else { d_result = (^_T03)(ptrs[3]) }
    when intrinsics.type_is_slice(T04) { e_result = ([^]_T04)(ptrs[4])[:e.len] } else { e_result = (^_T04)(ptrs[4]) }
    when intrinsics.type_is_slice(T05) { f_result = ([^]_T05)(ptrs[5])[:f.len] } else { f_result = (^_T05)(ptrs[5]) }
    when intrinsics.type_is_slice(T06) { g_result = ([^]_T06)(ptrs[6])[:g.len] } else { g_result = (^_T06)(ptrs[6]) }
    when intrinsics.type_is_slice(T07) { h_result = ([^]_T07)(ptrs[7])[:h.len] } else { h_result = (^_T07)(ptrs[7]) }
    when intrinsics.type_is_slice(T08) { i_result = ([^]_T08)(ptrs[8])[:i.len] } else { i_result = (^_T08)(ptrs[8]) }
    when intrinsics.type_is_slice(T09) { j_result = ([^]_T09)(ptrs[9])[:j.len] } else { j_result = (^_T09)(ptrs[9]) }
    when intrinsics.type_is_slice(T10) { k_result = ([^]_T10)(ptrs[10])[:k.len] } else { k_result = (^_T10)(ptrs[10]) }
    when intrinsics.type_is_slice(T11) { l_result = ([^]_T11)(ptrs[11])[:l.len] } else { l_result = (^_T11)(ptrs[11]) }
    when intrinsics.type_is_slice(T12) { m_result = ([^]_T12)(ptrs[12])[:m.len] } else { m_result = (^_T12)(ptrs[12]) }
    when intrinsics.type_is_slice(T13) { n_result = ([^]_T13)(ptrs[13])[:n.len] } else { n_result = (^_T13)(ptrs[13]) }
    when intrinsics.type_is_slice(T14) { o_result = ([^]_T14)(ptrs[14])[:o.len] } else { o_result = (^_T14)(ptrs[14]) }
    when intrinsics.type_is_slice(T15) { p_result = ([^]_T15)(ptrs[15])[:p.len] } else { p_result = (^_T15)(ptrs[15]) }
    when intrinsics.type_is_slice(T16) { q_result = ([^]_T16)(ptrs[16])[:q.len] } else { q_result = (^_T16)(ptrs[16]) }
    when intrinsics.type_is_slice(T17) { r_result = ([^]_T17)(ptrs[17])[:r.len] } else { r_result = (^_T17)(ptrs[17]) }
    when intrinsics.type_is_slice(T18) { s_result = ([^]_T18)(ptrs[18])[:s.len] } else { s_result = (^_T18)(ptrs[18]) }
    when intrinsics.type_is_slice(T19) { t_result = ([^]_T19)(ptrs[19])[:t.len] } else { t_result = (^_T19)(ptrs[19]) }
    return base, a_result, b_result, c_result, d_result, e_result, f_result, g_result, h_result, i_result, j_result, k_result, l_result, m_result, n_result, o_result, p_result, q_result, r_result, s_result, t_result, nil
}

make_multi :: proc {
    make_multi_2,
    make_multi_3,
    make_multi_4,
    make_multi_5,
    make_multi_6,
    make_multi_7,
    make_multi_8,
    make_multi_9,
    make_multi_10,
    make_multi_11,
    make_multi_12,
    make_multi_13,
    make_multi_14,
    make_multi_15,
    make_multi_16,
    make_multi_17,
    make_multi_18,
    make_multi_19,
    make_multi_20,
}
