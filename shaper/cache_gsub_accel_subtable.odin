package shaper

import "../ttf"
import "core:fmt"

process_lookup_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	accel: ^GSUB_Accelerator,
	lookup_idx: u16,
	lookup_type: ttf.GSUB_Lookup_Type,
	subtable_offset: uint,
) {
	// Skip if we can't access the subtable
	if bounds_check(subtable_offset + 2 >= uint(len(gsub.raw_data))) {
		return
	}

	format := ttf.read_u16(gsub.raw_data, subtable_offset)

	switch lookup_type {
	case .Single:
		accelerate_single_subtable(gsub, accel, lookup_idx, subtable_offset, format)

	case .Multiple:
		accelerate_multiple_subtable(gsub, accel, lookup_idx, subtable_offset, format)

	case .Alternate:
		accelerate_alternate_subtable(gsub, accel, lookup_idx, subtable_offset, format)

	case .Ligature:
		accelerate_ligature_subtable(gsub, accel, lookup_idx, subtable_offset, format)

	case .Context:
		accelerate_context_subtable(gsub, accel, lookup_idx, subtable_offset, format)

	case .ChainedContext:
		accelerate_chained_context_subtable(gsub, accel, lookup_idx, subtable_offset, format)

	case .Extension:
		// Should not happen here, as extensions are resolved earlier
		fmt.println("Unexpected Extension subtable in process_lookup_subtable")

	case .ReverseChained:
		accelerate_reverse_chained_subtable(gsub, accel, lookup_idx, subtable_offset, format)
	}
}

accelerate_single_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	accel: ^GSUB_Accelerator,
	lookup_idx: u16,
	subtable_offset: uint,
	format: u16,
) {
	if format != 1 && format != 2 {
		fmt.printf("Unsupported Single subtable format: %d\n", format)
		return
	}

	// Process coverage
	coverage_offset := ttf.read_u16(gsub.raw_data, subtable_offset + 2)
	abs_coverage_offset := subtable_offset + uint(coverage_offset)

	// Create coverage digest if needed
	if _, has_digest := accel.coverage_digest[abs_coverage_offset]; !has_digest {
		digest := build_coverage_digest(gsub, abs_coverage_offset)
		accel.coverage_digest[abs_coverage_offset] = digest
	}

	// Continue with your existing accelerate_single_substitution logic
	accelerate_single_substitution(gsub, accel, lookup_idx, subtable_offset, abs_coverage_offset)
}

// Process multiple substitution subtable
accelerate_multiple_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	accel: ^GSUB_Accelerator,
	lookup_idx: u16,
	subtable_offset: uint,
	format: u16,
) {
	// Multiple substitution only has format 1
	if format != 1 {
		fmt.printf("Unsupported Multiple subtable format: %d\n", format)
		return
	}

	// Get coverage
	coverage_offset := ttf.read_u16(gsub.raw_data, subtable_offset + 2)
	abs_coverage_offset := subtable_offset + uint(coverage_offset)

	// Create coverage digest if needed
	if _, has_digest := accel.coverage_digest[abs_coverage_offset]; !has_digest {
		digest := build_coverage_digest(gsub, abs_coverage_offset)
		accel.coverage_digest[abs_coverage_offset] = digest
	}

	// TODO: Implement multiple substitution acceleration
	// This would involve creating a map of input glyphs to output sequence
}

// Process alternate substitution subtable
accelerate_alternate_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	accel: ^GSUB_Accelerator,
	lookup_idx: u16,
	subtable_offset: uint,
	format: u16,
) {
	// Alternate substitution only has format 1
	if format != 1 {
		fmt.printf("Unsupported Alternate subtable format: %d\n", format)
		return
	}

	// Get coverage
	coverage_offset := ttf.read_u16(gsub.raw_data, subtable_offset + 2)
	abs_coverage_offset := subtable_offset + uint(coverage_offset)

	// Create coverage digest if needed
	if _, has_digest := accel.coverage_digest[abs_coverage_offset]; !has_digest {
		digest := build_coverage_digest(gsub, abs_coverage_offset)
		accel.coverage_digest[abs_coverage_offset] = digest
	}

	// TODO: Implement alternate substitution acceleration
	// This would involve mapping glyphs to arrays of alternates
}

// Process ligature substitution subtable
accelerate_ligature_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	accel: ^GSUB_Accelerator,
	lookup_idx: u16,
	subtable_offset: uint,
	format: u16,
) {
	// Ligature substitution only has format 1
	if format != 1 {
		fmt.printf("Unsupported Ligature subtable format: %d\n", format)
		return
	}

	// Get coverage
	coverage_offset := ttf.read_u16(gsub.raw_data, subtable_offset + 2)
	abs_coverage_offset := subtable_offset + uint(coverage_offset)

	// Create coverage digest if needed
	if _, has_digest := accel.coverage_digest[abs_coverage_offset]; !has_digest {
		digest := build_coverage_digest(gsub, abs_coverage_offset)
		accel.coverage_digest[abs_coverage_offset] = digest
	}

	// Call existing implementation
	accelerate_ligature_substitution(gsub, accel, lookup_idx, subtable_offset, abs_coverage_offset)
}

// Process context substitution subtable
accelerate_context_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	accel: ^GSUB_Accelerator,
	lookup_idx: u16,
	subtable_offset: uint,
	format: u16,
) {
	if format < 1 || format > 3 {
		fmt.printf("Invalid Context format: %d\n", format)
		return
	}

	// Initialize Context Accelerator if not exists
	if _, has_accel := accel.context_subst[lookup_idx]; !has_accel {
		context_accel := Context_Accelerator {
			format = format,
		}

		if format == 1 {
			context_accel.rule_sets = make(map[Glyph][]Context_Rule)
		} else if format == 2 {
			context_accel.class_def = make(map[Glyph]u16)
			context_accel.class_sets = make(map[u16][]Context_Rule)
		}

		accel.context_subst[lookup_idx] = context_accel
	}

	// Handle format-specific processing
	if format == 1 {
		// Format 1: Rule sets based on first glyph
		coverage_offset := ttf.read_u16(gsub.raw_data, subtable_offset + 2)
		abs_coverage_offset := subtable_offset + uint(coverage_offset)

		// Create coverage digest
		if _, has_digest := accel.coverage_digest[abs_coverage_offset]; !has_digest {
			digest := build_coverage_digest(gsub, abs_coverage_offset)
			accel.coverage_digest[abs_coverage_offset] = digest
		}

		// TODO: Process format 1 rules

	} else if format == 2 {
		// Format 2: Class-based rules
		coverage_offset := ttf.read_u16(gsub.raw_data, subtable_offset + 2)
		abs_coverage_offset := subtable_offset + uint(coverage_offset)

		// Create coverage digest
		if _, has_digest := accel.coverage_digest[abs_coverage_offset]; !has_digest {
			digest := build_coverage_digest(gsub, abs_coverage_offset)
			accel.coverage_digest[abs_coverage_offset] = digest
		}

		// TODO: Process class definition and rules

	} else if format == 3 {
		// Format 3: Coverage-based rules
		// TODO: Process format 3 with multiple coverage tables
	}
}

// Process chained context substitution subtable
accelerate_chained_context_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	accel: ^GSUB_Accelerator,
	lookup_idx: u16,
	subtable_offset: uint,
	format: u16,
) {
	if format < 1 || format > 3 {
		fmt.printf("Invalid ChainedContext format: %d\n", format)
		return
	}

	// Initialize Chained Context Accelerator if not exists
	if _, has_accel := accel.chained_context_subst[lookup_idx]; !has_accel {
		chained_accel := Chained_Context_Accelerator {
			format = format,
		}

		accel.chained_context_subst[lookup_idx] = chained_accel
	}

	// Handle format-specific processing
	if format == 1 {
		// Format 1: Rule sets based on first glyph
		coverage_offset := ttf.read_u16(gsub.raw_data, subtable_offset + 2)
		abs_coverage_offset := subtable_offset + uint(coverage_offset)

		// Create coverage digest
		if _, has_digest := accel.coverage_digest[abs_coverage_offset]; !has_digest {
			digest := build_coverage_digest(gsub, abs_coverage_offset)
			accel.coverage_digest[abs_coverage_offset] = digest
		}

		// TODO: Process format 1 chain rules

	} else if format == 2 {
		// Format 2: Class-based chain rules
		coverage_offset := ttf.read_u16(gsub.raw_data, subtable_offset + 2)
		abs_coverage_offset := subtable_offset + uint(coverage_offset)

		// Create coverage digest
		if _, has_digest := accel.coverage_digest[abs_coverage_offset]; !has_digest {
			digest := build_coverage_digest(gsub, abs_coverage_offset)
			accel.coverage_digest[abs_coverage_offset] = digest
		}

		// TODO: Process class definitions and chain rules

	} else if format == 3 {
		// Format 3: Coverage-based chain rules
		// TODO: Process format 3 with multiple coverage tables

		// Read counts
		backtrack_count := ttf.read_u16(gsub.raw_data, subtable_offset + 2)

		// Skip format 3 for now as it requires more complex handling
		fmt.printf(
			"ChainedContext Format 3 acceleration not yet implemented (lookup %d)\n",
			lookup_idx,
		)
	}
}

// Process reverse chained single substitution subtable
accelerate_reverse_chained_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	accel: ^GSUB_Accelerator,
	lookup_idx: u16,
	subtable_offset: uint,
	format: u16,
) {
	// Reverse chained substitution only has format 1
	if format != 1 {
		fmt.printf("Unsupported ReverseChained subtable format: %d\n", format)
		return
	}

	// Initialize Reverse Chained Accelerator if not exists
	if _, has_accel := accel.reverse_chained_subst[lookup_idx]; !has_accel {
		reverse_accel := Reverse_Chained_Accelerator {
			format           = format,
			substitution_map = make(map[Glyph]Glyph),
		}

		accel.reverse_chained_subst[lookup_idx] = reverse_accel
	}

	// Get coverage
	coverage_offset := ttf.read_u16(gsub.raw_data, subtable_offset + 2)
	abs_coverage_offset := subtable_offset + uint(coverage_offset)

	// Create coverage digest
	if _, has_digest := accel.coverage_digest[abs_coverage_offset]; !has_digest {
		digest := build_coverage_digest(gsub, abs_coverage_offset)
		accel.coverage_digest[abs_coverage_offset] = digest

		// Store in the accelerator
		subst := &accel.reverse_chained_subst[lookup_idx]
		subst.coverage = digest
	}

	// TODO: Process backtrack and lookahead coverages
	// TODO: Build substitution map
}
