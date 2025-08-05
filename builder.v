module babyton

//--------------------
// Cell builder module
//--------------------
import bitfield { BitField }

pub const max_cell_bits = 1023
pub const max_cell_refs = 4

// struct to hold up to 1023 bits and up to 4 reference (refs TODO)
pub struct CellBuilder {
mut:
	data   BitField
	bits   int
	refs   []&Cell
	exotic bool
	level  u8
}

// helper function to print CellBuilder
pub fn (self CellBuilder) str() string {
	mut output := 'CellBuilder( bits:${self.bits} refs:${self.refs.len} data:'
	for i in 0 .. self.bits {
		output += if self.data.get_bit(i) == 1 { '1' } else { '0' }
	}
	return output + ' )'
}

// create an empty CellBuilder with 1023-bit capacity
pub fn CellBuilder.new() CellBuilder {
	return CellBuilder{
		data:   bitfield.new(max_cell_bits)
		bits:   0
		refs:   []&Cell{}
		exotic: false
		level:  0
	}
}

// return how many bits used
pub fn (self CellBuilder) get_used_bits() int {
	return self.bits
}

// return how many bits left
pub fn (self CellBuilder) get_spare_bits() int {
	return max_cell_bits - self.bits
}

// return how many refs added
pub fn (self CellBuilder) get_refs_len() int {
	return self.refs.len
}

// ---------- internal guard ------------
@[inline]
fn (self &CellBuilder) ensure_capacity(add int) {
	if add < 0 {
		panic('[ERROR] negative number of bits to add to the cell')
	}
	if add > max_cell_bits - self.bits {
		panic('[ERROR] cell overflow')
	}
}

@[inline]
fn (self &CellBuilder) ensure_can_add_refs(n int) {
	if self.refs.len + n > max_cell_refs {
		panic('[ERROR] too many references (max ${max_cell_refs})')
	}
}

// ---- integers width checks ----
@[inline]
fn fits_uint(n u64, bits int) bool {
	if bits < 0 {
		return false
	}
	if bits == 0 {
		return n == 0
	}
	if bits == 64 {
		return true
	}
	return n < (u64(1) << bits)
}

@[inline]
fn fits_int(n i64, bits int) bool {
	if bits < 0 {
		return false
	}
	if bits == 0 {
		return n == 0
	}
	if bits == 64 {
		return true
	}
	two_pow := (u64(1) << u64(bits - 1))
	min := -i64(two_pow)
	max := i64(two_pow) - 1
	return n >= min && n <= max
}

// store a single bit 0 or 1
pub fn (mut self CellBuilder) store_bit(b u8) {
	if b > 1 {
		panic('[ERROR] bit must be 0 or 1')
	}
	self.ensure_capacity(1)
	if b == 1 {
		self.data.set_bit(self.bits)
	}
	self.bits += 1
}

// store a bool for convenience
pub fn (mut self CellBuilder) store_bool(v bool) {
	self.store_bit(if v { u8(1) } else { u8(0) })
}

// store a number of zeros (no writes needed)
pub fn (mut self CellBuilder) store_zeros(n int) {
	if n == 0 {
		return
	}
	self.ensure_capacity(n)
	self.bits += n
}

// store a number of ones (chunked up to 64 bits per insert)
pub fn (mut self CellBuilder) store_ones(n int) {
	if n == 0 {
		return
	}
	self.ensure_capacity(n)
	mut remain := n
	for remain > 0 {
		chunk := if remain >= 64 { 64 } else { remain }
		mask := if chunk == 64 { u64(0xffff_ffff_ffff_ffff) } else { (u64(1) << chunk) - 1 }
		self.data.insert(self.bits, chunk, mask)
		self.bits += chunk
		remain -= chunk
	}
}

// ---------- Unsigned integers ----------

// store n as an unsigned integer using exactly `bits` bits
pub fn (mut self CellBuilder) store_uint(n u64, bits int) {
	if bits == 0 {
		if n != 0 {
			panic('[ERROR] non-zero uint ${n} does not fit into 0 bits')
		}
		return
	}
	if bits < 0 || bits > 64 {
		panic('[ERROR] unsupported uint width: ${bits}')
	}
	if !fits_uint(n, bits) {
		panic('[ERROR] uint ${n} does not fit into ${bits} bits')
	}
	self.ensure_capacity(bits)
	self.data.insert(self.bits, bits, n)
	self.bits += bits
}

pub fn (mut self CellBuilder) store_u8(n u8) {
	self.store_uint(u64(n), 8)
}

pub fn (mut self CellBuilder) store_u16(n u16) {
	self.store_uint(u64(n), 16)
}

pub fn (mut self CellBuilder) store_u32(n u32) {
	self.store_uint(u64(n), 32)
}

pub fn (mut self CellBuilder) store_u64(n u64) {
	self.store_uint(n, 64)
}

// ---------- Signed integers ----------

// store n as a signed two's-complement integer using exactly `bits` bits
pub fn (mut self CellBuilder) store_int(n i64, bits int) {
	if bits == 0 {
		if n != 0 {
			panic('[ERROR] non-zero int ${n} does not fit into 0 bits')
		}
		return
	}
	if bits < 1 || bits > 64 {
		panic('[ERROR] unsupported int width: ${bits}')
	}
	if !fits_int(n, bits) {
		panic('[ERROR] int ${n} does not fit into ${bits} bits')
	}
	self.ensure_capacity(bits)
	self.data.insert(self.bits, bits, n)
	self.bits += bits
}

pub fn (mut self CellBuilder) store_i8(n i8) {
	self.store_int(i64(n), 8)
}

pub fn (mut self CellBuilder) store_i16(n i16) {
	self.store_int(i64(n), 16)
}

pub fn (mut self CellBuilder) store_i32(n int) {
	self.store_int(i64(n), 32)
}

pub fn (mut self CellBuilder) store_i64(n i64) {
	self.store_int(n, 64)
}

// ---------- Bytes ----------

pub fn (mut self CellBuilder) store_bytes(b []u8) {
	if b.len == 0 {
		return
	}
	max_bytes := (max_cell_bits - self.bits) / 8
	if b.len > max_bytes {
		panic('[ERROR] cell overflow')
	}
	for by in b {
		self.store_u8(by)
	}
}

// ---------- Address ----------

pub fn (mut self CellBuilder) store_address(a StdAddr) {
	if a.address.len != 32 {
		panic('[ERROR] address must be 32 bytes')
	}
	// 2 (tag) + 1(anycast) + 8(wc) + 256(addr)
	self.ensure_capacity(2 + 1 + 8 + 256)
	self.store_uint(0b10, 2)
	self.store_bit(0)
	self.store_i8(a.workchain)
	self.store_bytes(a.address)
}

// ---------- Pubkeys ----------

pub fn (mut self CellBuilder) store_pubkey(pk []u8) {
	if pk.len != 32 {
		panic('[ERROR] pubkey must be 32 bytes')
	}
	// 256 bits
	self.ensure_capacity(256)
	self.store_bytes(pk)
}

// ----------- Signature -----------

pub fn (mut self CellBuilder) store_signature(sig []u8) {
	if sig.len != 64 {
		panic('[ERROR] signature must be 64 bytes')
	}
	// 512 bits
	self.ensure_capacity(512)
	self.store_bytes(sig)
}

// ---------- Reference -------------

// Add a reference to an already-built child cell
pub fn (mut self CellBuilder) store_ref(child &Cell) {
	self.ensure_can_add_refs(1)
	self.refs << child
}
