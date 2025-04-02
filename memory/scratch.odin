package runic_memory

import "base:runtime"
import "core:log"
import "core:os"

ARENA_POOL_COUNT :: 4
ARENA_POOL_DEFAULT_SIZE :: 1024 * 1024

Allocator :: runtime.Allocator
Allocator_Error :: runtime.Allocator_Error

@(private)
Arena_Pool :: struct {
    pool: [ARENA_POOL_COUNT]runtime.Arena,
    count: int,
}

@(thread_local, private)
tls_scratch_pool: Arena_Pool

Scratch_Arena :: struct {
    using allocator: Allocator,
    tmp: runtime.Arena_Temp,
}

@(deferred_out=arena_temp_delete)
arena_scratch :: proc(collisions: []Allocator) -> Scratch_Arena {
    assert(len(collisions) < ARENA_POOL_COUNT)
    arena: ^runtime.Arena
    for &a in tls_scratch_pool.pool[:tls_scratch_pool.count] {
        arena = &a
        for c in collisions {
            if c.data == &a {
                arena = nil
            }
        }
        if arena != nil {
            break
        }
    }

    if arena == nil {
        @(cold)
        _allocate_scratch :: #force_no_inline proc() -> ^runtime.Arena {
            if tls_scratch_pool.count >= ARENA_POOL_COUNT {
                fatal_scratch_error()
            }
            a := &tls_scratch_pool.pool[tls_scratch_pool.count]
            tls_scratch_pool.count += 1
            err := runtime.arena_init(a, ARENA_POOL_DEFAULT_SIZE, runtime.heap_allocator())
            if err != nil {
                fatal_scratch_error()
            }
            return a
        }
        arena = _allocate_scratch()
    }

    tmp := runtime.arena_temp_begin(arena)
    return { runtime.arena_allocator(tmp.arena), tmp }
}

arena_temp_delete :: proc(scratch: Scratch_Arena) {
    runtime.arena_temp_end(scratch.tmp)
}

@(deferred_out=arena_temp_delete)
scratch_temp_scope :: proc(arena: Scratch_Arena) -> Scratch_Arena {
    tmp := runtime.arena_temp_begin(arena.tmp.arena)
    return { runtime.arena_allocator(tmp.arena), tmp }
}

fatal_scratch_error :: proc() -> ! {
    log.fatal("Scratch Arena has died :(")
    os.exit(1)
}
