package ttf

import "core:mem"
import "core:log"
import "base:intrinsics"

Read_Context :: struct {
    ok: bool,
    illegal_read_no_message: bool,
}

Reader :: struct {
    ctx: ^Read_Context,
    data: []byte,
    offset: i64,
}

@(cold)
_read_fail :: proc(r: ^Reader, loc := #caller_location) {
    if r.ctx.ok && ! r.ctx.illegal_read_no_message {
        log.error("[Runic Reader] Illegal read", location = loc)
    }
    r.ctx.ok = false
}

read_bytes_copy :: proc(r: ^Reader, size: i64, ptr: rawptr, loc := #caller_location) -> (bool) #no_bounds_check {
    head, did_overflow := intrinsics.overflow_add(r.offset, size)
    if ! r.ctx.ok || did_overflow || size > i64(max(int)) || head > i64(len(r.data)) || size < 0 {
        _read_fail(r, loc)
        return false
    }
    if ptr != nil && size > 0 {
        mem.copy_non_overlapping(ptr, &r.data[r.offset], int(size))
    }
    r.offset = head
    return true
}

read_bytes_ptr :: proc(r: ^Reader, size: i64, ptr: ^rawptr, loc := #caller_location) -> (bool) #no_bounds_check {
    head, did_overflow := intrinsics.overflow_add(r.offset, size)
    if ! r.ctx.ok || did_overflow || size > i64(max(int)) || head > i64(len(r.data)) || size < 0 {
        _read_fail(r, loc)
        return false
    }
    if ptr != nil && size > 0 {
        ptr^ = &r.data[r.offset]
    }
    r.offset = head
    return true
}

read_t_copy :: proc($T: typeid, r: ^Reader, loc := #caller_location) -> (T, bool) #optional_ok {
    t: T
    ok := read_bytes_copy(r, size_of(T), &t, loc)
    return t, ok
}

read_t_ptr :: proc($T: typeid, r: ^Reader, loc := #caller_location) -> (^T, bool) #optional_ok {
    @static _dummy: T
    t: ^T = &_dummy
    ok := read_bytes_ptr(r, size_of(T), auto_cast &t, loc)
    return t, ok
}

read_t_slice :: proc($T: typeid, r: ^Reader, len: i64, loc := #caller_location) -> ([]T, bool) #optional_ok {
    t: ^T
    ok := read_bytes_ptr(r, size_of(T) * len, auto_cast &t, loc)
    if ok {
        return mem.slice_ptr(t, int(len)), true
    } else {
        return {}, false
    }
}

