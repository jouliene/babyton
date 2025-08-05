module babyton

// Ordinary-only TON cells: hashing + minimal BoC (single root, no index/CRC)
import bitfield { BitField }
import crypto.sha256

// -----------------------------
// Cell (ordinary only: level=0)
// -----------------------------
pub struct Cell {
pub:
	data   BitField // raw bits
	bits   int      // number of valid bits in `data` (0..1023)
	refs   []&Cell  // up to 4 references (true refs via pointers)
	exotic bool     // always false here (ordinary)
	level  u8       // always 0 here (ordinary)
}

// Compact builder -> heap Cell (so &Cell refs remain valid)
pub fn (self CellBuilder) build() &Cell {
	mut compact := if self.bits == 0 { bitfield.new(1) } else { bitfield.new(self.bits) }
	for i in 0 .. self.bits {
		if self.data.get_bit(i) == 1 {
			compact.set_bit(i)
		}
	}
	return &Cell{
		data:   compact
		bits:   self.bits
		refs:   self.refs.clone()
		exotic: false
		level:  u8(0)
	}
}

// Pretty print without descending into refs (avoids huge/circular dumps)
pub fn (c Cell) str() string {
	mut s := ''
	for i in 0 .. c.bits {
		s += if c.data.get_bit(i) == 1 { '1' } else { '0' }
	}
	return 'Cell( bits:${c.bits} refs:${c.refs.len} data:${s} )'
}

// -----------------------------------------
// Bitstring packing (TON end-bit convention)
// -----------------------------------------
//
// Pack MSB-first to bytes; if `bits % 8 != 0`, append one end-bit '1',
// then zero-pad to the next octet.
pub fn pack_data_bytes(c &Cell) []u8 {
	if c.bits == 0 {
		return []u8{}
	}
	mut out := []u8{cap: (c.bits + 7) / 8}
	mut cur := u8(0)
	mut cnt := 0
	for i in 0 .. c.bits {
		cur = (cur << 1) | u8(c.data.get_bit(i) & 1)
		cnt++
		if cnt == 8 {
			out << cur
			cur = 0
			cnt = 0
		}
	}
	if cnt > 0 {
		// insert end-bit '1' then pad zeros
		cur = (cur << 1) | 1
		cnt++
		cur <<= u8(8 - cnt)
		out << cur
	}
	return out
}

// ----------------------
// Descriptor bytes (D1,D2)
// ----------------------
//
// D1 = refs + 8*exotic + 32*level  (here exotic=0, level=0 -> D1=refs)
// D2 = floor(bits/8) + ceil(bits/8)
pub fn descriptors(c &Cell) (u8, u8) {
	d1 := u8(c.refs.len)
	b := c.bits
	d2 := u8((b / 8) + ((b + 7) / 8))
	return d1, d2
}

// -----------------------------------------
// Representation hash (ordinary cells only)
// -----------------------------------------
//
// hash = sha256( D1, D2, packed_data, hash(child_0), ..., hash(child_r-1) )
pub fn cell_hash(c &Cell) []u8 {
	d1, d2 := descriptors(c)
	packed_data := pack_data_bytes(c)

	mut digest_input := []u8{cap: 2 + packed_data.len + 32 * c.refs.len}
	digest_input << d1
	digest_input << d2
	digest_input << packed_data
	for child in c.refs {
		child_hash := cell_hash(child)
		digest_input << child_hash
	}
	return sha256.sum(digest_input)
}
