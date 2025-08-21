module babyton

// ----------------------------
// BoC (Bag of Cells) — minimal
//   * single root
//   * no index table
//   * no CRC32C
// ----------------------------
import encoding.base64

// helpers: make a string key from a []u8 hash
fn hash_key(c &Cell) string {
	return cell_hash(c).bytestr()
}

pub fn order_cells_parent_first(root &Cell) []&Cell {
	mut out := []&Cell{}
	mut seen := map[string]bool{} // dedupe by content hash (string key)
	mut stack := []&Cell{}
	stack << root
	for stack.len > 0 {
		c := stack.pop()
		k := hash_key(c)
		if k in seen {
			continue
		}
		seen[k] = true
		out << c

		if c.refs.len == 0 {
			continue
		}

		// Partition children: push LEAVES first, NON-LEAVES last (so non-leaves pop first)
		mut leaves := []&Cell{}
		mut nonleaves := []&Cell{}
		for ch in c.refs {
			if ch.refs.len == 0 {
				leaves << ch
			} else {
				nonleaves << ch
			}
		}
		for ch in leaves {
			stack << ch
		}
		for ch in nonleaves {
			stack << ch
		}
	}
	return out
}

// Selects the minimal byte width (1-4) to represent u32 value
fn choose_size_bytes(max_val u32) int {
	if max_val <= 0xFF {
		return 1
	}
	if max_val <= 0xFFFF {
		return 2
	}
	if max_val <= 0xFFFFFF {
		return 3
	}
	return 4
}

// Selects the minimal byte width (1-4) for reference indices based on cell count
fn choose_ref_size(cells_count int) int {
	if cells_count <= 0x100 {
		return 1
	}
	if cells_count <= 0x10000 {
		return 2
	}
	if cells_count <= 0x1000000 {
		return 3
	}
	return 4
}

// Appends a u32 value in big-endian format using exactly size_bytes bytes
fn put_uint_be(mut dst []u8, value u32, size_bytes int) {
	for i in 0 .. size_bytes {
		shift := (size_bytes - 1 - i) * 8
		dst << u8((value >> u32(shift)) & 0xFF)
	}
}

// Serializes a cell to flat bytes: D1 D2 packed_data ref_indices...
// Ref indices are looked up from idx_of (keyed by string(cell hash)).
fn serialize_cell_flat(c &Cell, idx_of map[string]int, ref_size int) []u8 {
	d1, d2 := descriptors(c)
	data := pack_data_bytes(c)

	mut out := []u8{cap: 2 + data.len + c.refs.len * ref_size}
	out << d1
	out << d2
	out << data
	for r in c.refs {
		idx := idx_of[hash_key(r)]
		put_uint_be(mut out, u32(idx), ref_size)
	}
	return out
}

pub fn build_boc_bytes(root &Cell) []u8 {
	// Order cells (dedup by hash string) and build index map
	cells := order_cells_parent_first(root)
	cells_count := cells.len

	mut idx_of := map[string]int{}
	for i, c in cells {
		idx_of[hash_key(c)] = i
	}
	root_idx := idx_of[hash_key(root)] // explicit root index

	// Choose ref index width (unchanged)
	ref_size := choose_ref_size(cells_count)

	// Serialize flat cells
	mut flats := [][]u8{cap: cells_count}
	mut total_cells_size := 0
	for c in cells {
		f := serialize_cell_flat(c, idx_of, ref_size)
		total_cells_size += f.len
		flats << f
	}

	// IMPORTANT: use two widths (like Nekoton / Go code)
	cell_size_bytes := choose_size_bytes(u32(cells_count)) // for counts & root indices
	size_bytes := choose_size_bytes(u32(total_cells_size)) // for payload size (& offsets)
	off_bytes := size_bytes

	// Build BoC: header + body
	mut boc := []u8{cap: 32 + total_cells_size}

	// Magic bytes for BoC
	boc << [u8(0xb5), 0xee, 0x9c, 0x72]

	// Flags: has_idx=0, has_crc=0, has_cache_bits=0, flags=0, and LOW 3 BITS = cell_size_bytes
	boc << u8(cell_size_bytes)

	// off_bytes (width for offsets / payload length field)
	boc << u8(off_bytes)

	// Counts/sizes
	// NOTE: counts in `cell_size_bytes`, payload size in `size_bytes`
	put_uint_be(mut boc, u32(cells_count), cell_size_bytes) // cells_count
	put_uint_be(mut boc, 1, cell_size_bytes) // roots_count
	put_uint_be(mut boc, 0, cell_size_bytes) // absent_count
	put_uint_be(mut boc, u32(total_cells_size), size_bytes) // total serialized cells size

	// root index list (each in `cell_size_bytes`)
	put_uint_be(mut boc, u32(root_idx), cell_size_bytes)

	// body = concatenated flat cells
	for f in flats {
		boc << f
	}

	return boc
}

// Build BoC in base64 encoding
pub fn build_boc_base64(root &Cell) string {
	return base64.encode(build_boc_bytes(root))
}

// Get BoC from bytes BoC
pub fn get_boc_base64_from_bytes(boc []u8) string {
	return base64.encode(boc)
}

// Get bytes from base64
pub fn get_boc_bytes_from_base64(boc string) []u8 {
	return base64.decode(boc)
}
