package rune

import ttf "../ttf"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:sync"
import "core:time"
import "core:unicode/utf8"

Font_ID :: distinct uint
Font_Identity :: struct {
	id:     Font_ID,
	font:   ^Font,
	name:   string,
	family: string,
	style:  ttf.Font_Style,
	weight: ttf.Font_Weight,
	width:  ttf.Font_Width,
	slant:  ttf.Font_Slant,
}
Rune :: struct {
	// Font management
	loaded_fonts:     map[Font_ID]Font_Identity,
	_next_font_id:    uint,

	// Shaping cache
	caches:           map[Shaping_Cache_Key]Shaping_Cache,
	// cache_capacity:    int,
	// current_timestamp: u64,

	// Shaping configuration defaults
	default_script:   Script_Tag,
	default_language: Language_Tag,
	default_features: Feature_Set,
	buffer_pool:      [dynamic]^Shaping_Buffer,
	max_buffers:      uint,
	// Performance statistics
	cache_hits:       uint,
	cache_misses:     uint,
	// shaping_count:    uint,

	// Memory management
	allocator:        mem.Allocator,

	// Threading/locking 
	// mutex:            sync.Mutex,
}

// Create a new Rune font engine instance
create_engine :: proc(allocator := context.allocator, max_buffers: uint = 4) -> ^Rune {
	context.allocator = allocator


	r := new(Rune, allocator)
	if r == nil {return nil}

	// Initialize maps
	r.loaded_fonts = make(map[Font_ID]Font_Identity, allocator)
	r.caches = make(map[Shaping_Cache_Key]Shaping_Cache, allocator)

	// Initialize buffer pool
	r.buffer_pool = make([dynamic]^Shaping_Buffer, 0, max_buffers, allocator)
	r.max_buffers = max_buffers
	append(&r.buffer_pool, create_shaping_buffer())

	// Set default values
	r.default_script = .latn
	r.default_language = .dflt
	r.default_features = create_feature_set(.liga, .clig, .kern)

	// Store allocator for future use
	r.allocator = allocator

	return r
}

// Destroy a Rune font engine and free all resources
destroy_engine :: proc(r: ^Rune) {
	if r == nil {return}

	context.allocator = r.allocator

	// Clean up loaded fonts
	for _, identity in r.loaded_fonts {
		ttf.destroy_font(identity.font)
	}
	delete(r.loaded_fonts)

	// Clean up shaping caches
	for _, cache in r.caches {
		if cache.gsub_lookups != nil {delete(cache.gsub_lookups)}
		if cache.gpos_lookups != nil {delete(cache.gpos_lookups)}
	}
	delete(r.caches)

	for buffer in r.buffer_pool {
		destroy_shaping_buffer(buffer)
	}
	delete(r.buffer_pool)

	free(r, r.allocator)
}

get_buffer :: proc(engine: ^Rune) -> ^Shaping_Buffer {
	// Try to get a buffer from the pool
	if len(engine.buffer_pool) > 0 {
		// Pop the last buffer from the pool
		last_idx := len(engine.buffer_pool) - 1
		buffer := engine.buffer_pool[last_idx]
		pop(&engine.buffer_pool)

		// Clear the buffer for reuse
		clear_shaping_buffer(buffer)
		return buffer
	}

	// No buffers in the pool, create a new one
	return create_shaping_buffer()
}
// Return a buffer to the pool
release_buffer :: proc(engine: ^Rune, buffer: ^Shaping_Buffer) {
	if buffer == nil {return}

	// Clear the buffer before returning it to the pool
	clear_shaping_buffer(buffer)

	// If we have room in the pool, add it
	if uint(len(engine.buffer_pool)) < engine.max_buffers {
		append(&engine.buffer_pool, buffer)
	} else {
		// Pool is full, destroy the buffer
		destroy_shaping_buffer(buffer)
	}
}


// Register a loaded font with the engine
register_font :: proc(engine: ^Rune, font: ^Font, name: string = "") -> (id: Font_ID, ok: bool) {
	if engine == nil || font == nil {
		return {}, false
	}

	// Generate a new unique ID
	font_id := Font_ID(engine._next_font_id)
	engine._next_font_id += 1

	// Create identity
	identity := Font_Identity {
		id     = font_id,
		font   = font,
		name   = name,
		family = "", // TODO: Extract from name table
		style  = .Regular, // TODO: Determine from OS/2 table
		weight = .Regular,
		width  = .Normal,
		slant  = .Normal,
	}

	// Register in loaded fonts
	engine.loaded_fonts[font_id] = identity

	return font_id, true
}
