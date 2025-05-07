# Runic

A high-performance OpenType font engine written in the Odin programming language. Focused on primarily on Latin scripts (I don't have the time to devote to other scripts at present).

## Overview

Runic is a lightweight OpenType font engine designed for performance and correctness. Taking inspiration from popular libraries like HarfBuzz and ttf-parser, Rune provides a (mostly) comprehensive solution for font loading, text shaping, and glyph rasterization.

## TODO:

Autodetect if font can render a set of text (detect_script + cmap tests) - Find which of loaded fonts is best fit (incl kerning pairs)
feaorumund updated grapheme clustering (in core:text/table)

## Key Features

-   **Pure Odin Implementation** - No dependencies (other than `core`)
-   **OpenType Support** - Handles complex OpenType features including:
    -   Glyph substitution (GSUB) for ligatures, alternates, etc.
    -   Glyph positioning (GPOS) for kerning, mark attachment, etc.
    -   Advanced typographic features like contextual alternates
-   **Comprehensive Text Shaping** - Proper handling of complex scripts including Arabic, Devanagari, and more
-   **Efficient Glyph Rasterization** - Convert outlines to bitmap images with:
    -   Point-first parsing approach for better performance
    -   Support for composite glyphs
    -   Line and quadratic Bezier curve rendering
-   **Modular Design** - Use only the components you need

## Status

The project is work in progress and not stable. Very little testing has been conducted. Subpackage organization is also not stable (e.g. The script and language tags probably need moved from `shaper` to `ttf`). Claude 3.7 was used to help get the project up and running, and that is both a boon (I would not have written this, as I had no prior font experience) and curse; the entire codebase still needs re-reviewed and refactored, which will be an ongoing process.

## Architecture

Runic is divided into several functional components:

## Core Unicode Handling (`unicode` package)

**NOT IMPLEMENTED**: This is a planned subproject. Presently embedded in `ttf`.

-   Unicode character database [UnicodeData.txt](https://www.unicode.org/Public/UNIDATA/UnicodeData.txt)
-   Character properties and classifications
-   Encoding/decoding support
-   Normalization forms
-   Bidirectional algorithm implementation

### Font Parsing (`ttf` package)

-   Font loading and table parsing
-   Minimal/No Allocations; data is represented in file format (eg `u16be`) and accessed via iterators
-   Glyph outlines extraction with an efficient point-first approach
-   Support for both simple and composite glyphs
-   Interfaces/Iterators for the following OpenType Tables:
    -   BASE
    -   cmap
    -   GDEF
    -   glyf
    -   GPOS
    -   GSUB
    -   head
    -   hhea
    -   htmx
    -   kern
    -   loca
    -   MATH
    -   maxp
    -   OS/2
    -   vhea
    -   vtmx

AAT & JSTF aren't in the plan at the moment as they need a state machine to parse, and I don't have the time/interest.

COLR / CPAL & fvar tables are planned, but not implemented. CFF & WOFF I'm on the fence about.

### Text Shaping (`shaper` package)

-   Script and language detection
-   OpenType feature application
-   Glyph substitution and positioning
-   Bidirectional text handling

### Rasterization (`raster` package)

-   Convert glyph outlines to bitmap images
-   Bresenham's line algorithm for efficient line drawing
-   Quadratic Bezier curve rendering
-   BMP output support for visualization and debugging
-   Proper handling of composite glyphs with transformations
-   Debug grid and visualization tools

### Layout (`layout` package)

**NOT IMPLEMENTED**: This is a planned subproject

-   Paragraph layout with line breaking
-   Rich text formatting support
-   Text flow around images and other elements
-   Embeddable in UI systems
-   Metric calculations and layout constraints

## Package Dependencies

The following diagram shows the relationships between the sub-packages:

```text
   `unicode`
       ↑
     `ttf`
       ↑
    `shaper`
     ↑    ↑
`raster` `layout`
```

This hierarchical design allows you to use only the components you need:

-   Use `ttf` alone for simple font inspection or simple metrics extraction
-   Use `shaper` when you need text shaping but will handle rendering yourself
-   Use `raster` when you need glyph rendering but will handle layout yourself
-   Use `layout` with your own rasterizer, or with the provided `raster` package

## Design Principles

1. **Performance First**: Minimize allocations, keep data in binary format until needed
2. **Memory Efficiency**: Read and retain data in big-endian format until just before returning to the client
3. **Type Safety**: Leverage Odin's type system for safer code
4. **Correctness**: Thoroughly tested against the OpenType specification
5. **Modularity**: Packages can be used independently or together

## Usage Examples

### Basic Font Loading

```odin
import "ttf"

main :: proc() {
    font, err := ttf.load_font("path/to/font.ttf")
    if err != .None {
        // Handle error
    }
    defer ttf.destroy_font(&font)

    // Work with the font...
}
```

### Text Shaping

```odin
import "shaper"
import "ttf"

main :: proc() {
    // Initialize the engine
    engine := shaper.create_engine()
    defer shaper.destroy_engine(engine)

    // Load and register a font
    font, _ := ttf.load_font("path/to/font.ttf")
    defer ttf.destroy_font(&font)

    font_id, _ := shaper.register_font(engine, &font)

    // Enable OpenType features
    features := shaper.create_feature_set(.liga, .dlig, .kern)

    // Shape text
    buffer, ok := shaper.shape_text_with_font(
        engine,
        font_id,
        "Affinity for font shaping in Odin",
        .latn,  // Latin script
        .ENG,   // English language
        features
    )
    defer shaper.release_buffer(engine, buffer)

    // Use the shaped glyphs...
}
```

### Glyph Rasterization

```odin
import "raster"
import "ttf"

main :: proc() {
    font, _ := ttf.load_font("path/to/font.ttf")
    defer ttf.destroy_font(&font)

    // Get a glyph ID (e.g., for the letter 'A')
    glyph_id, _ := ttf.get_glyph_from_cmap(&font, 'A')

    // Create a bitmap for rendering
    bitmap := raster.create_bitmap(64, 64)
    defer delete(bitmap.data)

    // Add debug grid for visualization
    raster.draw_debug_grid(&bitmap)

    // Render the glyph to the bitmap
    raster.rasterize_glyph(&font, glyph_id, &bitmap, 32)

    // Save the bitmap to a file
    raster.save_bitmap_to_bmp(&bitmap, "glyph_A.bmp")
}
```

### Handling Composite Glyphs

```odin
import "raster"
import "ttf"

main :: proc() {
    font, _ := ttf.load_font("path/to/font.ttf")
    defer ttf.destroy_font(&font)

    // Get a composite glyph like 'í' (i with acute accent)
    glyph_id, found := ttf.get_glyph_from_cmap(&font, 'í')
    if !found {
        return
    }

    // Create a bitmap for rendering
    bitmap := raster.create_bitmap(100, 100)
    defer delete(bitmap.data)

    // Render the composite glyph
    raster.rasterize_glyph(&font, glyph_id, &bitmap, 48)

    // Save the bitmap to a file
    raster.save_bitmap_to_bmp(&bitmap, "composite_glyph.bmp")
}
```

## Implementation Details

-   **Binary Data Handling**: Native OpenType data is stored in big-endian format. Rune tries to store data in the same format until the last minute. Some will directly return `be` types.
-   **Type Safety**: Distinct types are used to prevent logical errors (e.g., `Glyph` vs `Raw_Glyph`).
-   **Glyph Outlines**: The engine now uses a point-first approach for parsing glyph outlines, collecting all points before creating segments. This simplifies handling of composite glyphs, but is probably not the most performant.
-   **Rendering**: The rasterizer supports both line segments and quadratic Bezier curves, properly handling transformations for composite glyphs.

## Building and Testing

```bash
# Run the demo
odin run ./raster_demo.odin
```

## License

This project is licensed under the BSD-3 License - see the LICENSE file for details.

## Contributing

Please feel free to submit a Pull Request. Testing needs fleshed out; and general refactoring work needs done, along with the planned but not implemented packages.

All submitted code will be assigned the project's license.

## Acknowledgments

-   HarfBuzz for algorithm inspiration
-   ttf-parser for parsing techniques
