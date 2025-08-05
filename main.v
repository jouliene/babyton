// Simple example code of using babyton sdk
// v run .
// 

import babyton { CellBuilder, build_boc_bytes, build_boc_base64, get_boc_from_bytes }

fn main() {
	mut b1 := CellBuilder.new()
	b1.store_uint(0x0AAAAA, 24)
	b1.store_bool(true)
	b1.store_i16(-48)
	println('cell builder 1: ${b1}')
	cell1 := b1.build()
	println('cell 1:         ${cell1}\n')

	mut b2 := CellBuilder.new()
	b2.store_uint(0b10101, 5)
	b2.store_ref(cell1)
	println('cell builder 2: ${b1}')
	root_cell := b2.build()
	println('cell 2 (root):  ${root_cell}\n')

	boc := build_boc_bytes(root_cell)
	println('Building BoC in hex bytes: ${boc.hex()}')	

	boc_base64 := build_boc_base64(root_cell)
	println('Building BoC in base64:    ${boc_base64}')

	boc_base64_2 := get_boc_from_bytes(boc)
	println('BoC in bytes to base64:    ${boc_base64_2}')
	
}
