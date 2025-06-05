# Runic Font Engine Demo

A text-editor example demonstrating Runic's font shaping and rendering capabilities in a real-world text editor application.

## What This Demonstrates

This editor serves as a practical showcase of **Runic's typography engine**, highlighting its performance, flexibility, and ease of integration in text-intensive applications.

### **Runic's Font Loading & Management**
```odin
// Simple font loading
font, err := ttf.load_font_from_path("../arial.ttf", context.allocator)
font_id, ok := shaper.register_font(engine, font)

// Create rendering face with size
face, ok := renderer.create_font_face(&ogl_renderer, font, 16.0, .None, 96.0)
```

### **Runic's Text Shaping Engine**
```odin
// Efficient viewport-based shaping - only shape visible text
shaped_viewport, ok := shaper.shape_string(engine, font_id, viewport.text)

// Runic handles complex text shaping automatically:
// - UTF-8 multi-byte characters
// - Glyph clustering for cursor positioning
// - OpenType feature application
// - Efficient memory management
```

### **Runic's OpenGL Renderer**
```odin
// Prepare shaped text for GPU (one upload per viewport)
renderer.prepare_shaped_text(&ogl_renderer, face, shaped_viewport)

// Render with zero allocations using buffer slices
line_render_buf := renderer.create_render_buffer(shaped_viewport, start, end)
renderer.render_text_2d(&ogl_renderer, face, &line_render_buf, 
                       screen_width, screen_height, position, color)
```

## Runic Performance Optimizations Showcased

**1. Viewport-Only Processing**: Runic only shapes and renders visible text, scaling to massive documents

**2. Batched Operations**: Single shaping call + single GPU upload per frame, regardless of text complexity

**3. Cluster-Aware Positioning**: Runic provides glyph cluster information for accurate cursor placement in complex scripts

**4. Memory Efficiency**: Zero-allocation rendering paths and efficient buffer management

**5. OpenType Support**: Full OpenType feature support with minimal API complexity

## Building and Running

```bash
# From the editor directory
~/Odin/odin run . 
```

**Requirements:**
- Odin compiler
- OpenGL 3.3+ compatible graphics
- GLFW for windowing
- Font file at `../arial.ttf` (or modify path in source)

## Usage

| Key | Action |
|-----|--------|
| **Arrow Keys** | Move cursor |
| **Ctrl+Up/Down** | Scroll viewport without moving cursor |
| **Home/End** | Move to line start/end |
| **Page Up/Down** | Scroll by screen |
| **Enter** | Insert newline |
| **Backspace/Delete** | Delete characters |
| **Any character** | Insert at cursor |

## Runic Integration Patterns Demonstrated

### **Text Storage + Runic Rendering Separation**
```odin
// Your text storage (gap buffer, rope, etc.)
buffer := gap_buffer.make_gap_buffer(1024)

// Runic handles font rendering completely separately
viewport_text := extract_text_from_storage(buffer)
shaped := shaper.shape_string(engine, font_id, viewport_text)
renderer.render_shaped_text(shaped)
```

### **Efficient Viewport Rendering**
```odin
// Extract only visible text from your data structure
viewport := extract_viewport_text() // Your implementation

// Let Runic shape and render efficiently
shaped_viewport, _ := shaper.shape_string(engine, font_id, viewport.text)
renderer.prepare_shaped_text(&ogl_renderer, face, shaped_viewport)

// Render line by line using Runic's buffer slices
for line_range in line_ranges {
    render_buf := renderer.create_render_buffer(shaped_viewport, start, end)
    renderer.render_text_2d(&ogl_renderer, face, &render_buf, ...)
}
```

### **Cursor Positioning with Runic's Cluster Data**
```odin
// Runic provides cluster information for accurate cursor placement
for glyph, i in shaped_buffer.glyphs {
    if int(glyph.cluster) >= target_rune_position {
        cursor_x += sum_advances_to_glyph(i)
        break
    }
}
```

## Runic's Architecture Benefits Shown

**Modular Design**: Text storage, shaping, and rendering are completely separate - swap out any component

**Performance Focus**: Minimal allocations, efficient data structures, optimized for real-time text editing

**OpenType Compliance**: Proper handling of complex text without requiring typography expertise

**Cross-Platform**: Pure Odin implementation with minimal dependencies

**Memory Safe**: Type-safe APIs prevent common text rendering bugs

## Key Runic APIs Demonstrated

| API Component | Purpose | Example Usage |
|---------------|---------|---------------|
| `ttf.load_font()` | Font loading | `font, err := ttf.load_font_from_path(path)` |
| `shaper.create_engine()` | Text shaping setup | `engine := shaper.create_engine()` |
| `shaper.shape_string()` | Text to glyphs | `shaped, ok := shaper.shape_string(engine, font_id, text)` |
| `renderer.create_font_face()` | GPU font preparation | `face, ok := renderer.create_font_face(&renderer, font, size)` |
| `renderer.prepare_shaped_text()` | GPU upload | `renderer.prepare_shaped_text(&renderer, face, shaped)` |
| `renderer.render_text_2d()` | Final rendering | `renderer.render_text_2d(&renderer, face, buffer, ...)` |

## What This Example Proves

✅ **Runic scales** - Handles large documents by processing only visible text  
✅ **Runic performs** - Single-digit millisecond rendering with proper batching  
✅ **Runic integrates easily** - Clean separation between text storage and rendering  
✅ **Runic handles complexity** - UTF-8, glyph clustering, OpenType features work transparently  
✅ **Runic is practical** - Real text editing scenarios work smoothly  

## Editor Limitations (Not Runic Limitations)

The editor itself has limitations due to implementation time, but these don't reflect Runic's capabilities:

- Single font (Runic supports multiple fonts and fallback)
- Basic layout (Runic can handle complex text layout)
- Latin-focused (Runic supports international scripts)
- No rich text (Runic supports styled text rendering)

**Runic itself is designed for typography applications** - this editor just demonstrates core integration patterns.

## Getting Started with Runic

1. **Study the font loading pattern** in `setup()`
2. **Examine the viewport rendering** in `render_editor()`  
3. **Look at cursor positioning** in `render_cursor_at_position()`
4. **See text editing integration** in the input handlers

