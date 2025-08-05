// Simple example code of using babyton sdk
// v run .
// 

import babyton { StdAddr, KeyPair, CellBuilder, build_boc_bytes, build_boc_base64, get_boc_from_bytes }

fn main() {
	addr := StdAddr.from_string('0:538b6135fd39fc707b0c1459469db104383c431d4d116ffd0d58cc75c95a3f95')
	println(addr)	
	println('')

	keypair := KeyPair.generate()
	println(keypair)
	println('')

	mut b1 := CellBuilder.new()
	b1.store_uint(0x0AAAAA, 24)
	b1.store_bool(true)
	b1.store_i16(-48)
	println(b1)
	leaf_cell := b1.build()
	println(leaf_cell)
	println('')

	mut b2 := CellBuilder.new()
	b2.store_uint(0b10101, 5)
	b2.store_ref(leaf_cell)
	println(b2)
	root_cell := b2.build()
	println(root_cell)
	println('')

	boc := build_boc_bytes(root_cell)
	println('Building BoC in hex bytes: ${boc.hex()}')	

	boc_base64 := build_boc_base64(root_cell)
	println('Building BoC in base64:    ${boc_base64}')

	boc_base64_2 := get_boc_from_bytes(boc)
	println('BoC in bytes to base64:    ${boc_base64_2}')	
}
