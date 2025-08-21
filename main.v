import babyton { CellBuilder, build_boc_base64, cell_hash }

fn main() {
	mut bb := CellBuilder.new()
	bb.store_bool(true)
	bc := bb.build()

	mut ab := CellBuilder.new()
	ab.store_bool(false)
	ab.store_ref(bc)
	ac := ab.build()

	mut bb2 := CellBuilder.new()
	bb2.store_bool(true)
	bc2 := bb2.build()

	mut rb := CellBuilder.new()
	rb.store_bool(false)
	rb.store_ref(ac)
	rb.store_ref(bc2)
	rc := rb.build()
	println(rc)

	// compute cell hash for signing
	cell_hash_bytes := cell_hash(rc)
	println(cell_hash_bytes.hex())
	println(build_boc_base64(rc))
}
