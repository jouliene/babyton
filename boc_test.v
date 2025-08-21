// boc_test.v
module babyton

fn test_boc_creation() {
	// create leaf cell 'A'
	mut a_builder := CellBuilder.new()
	a_builder.store_bool(true)
	a_builder.store_bool(false)
	a_builder.store_ones(3)
	a_builder.store_zeros(2)
	a_builder.store_bit(1)
	a_builder.store_bit(0)
	a_builder.store_uint(0b101100111, 9)
	a_cell := a_builder.build()
	assert build_boc_base64(a_cell) == 'te6ccgEBAQEABQAABblZ4A=='
	assert cell_hash(a_cell).hex() == 'c603289b80de8223ccbd59791be20ed18a11188c842cf3a565c97052c28f77a8'

	// create leaf cell 'B' with reference to cell 'A'
	addr := StdAddr.from_string('0:d0d24e409d317f3932080414bbeb319810624e33ce249bd3e66674e783eba353')
	keypair := KeyPair.from_secret_string('8248d37cd689d02f4071dfa74737f6f23c85eebc46cdb44157a631a3f4d01f3a')
	mut b_builder := CellBuilder.new()
	b_builder.store_address(addr)
	b_builder.store_pubkey(keypair.pubkey)
	b_builder.store_ref(a_cell)
	b_cell := b_builder.build()
	assert build_boc_base64(b_cell) == 'te6ccgEBAgEASgABg4AaGknIE6Yv5yZBAIKXfWYzAgxJxnnEk3p8zM6c8H10anT9tRu8r1gVlxlBLADNDj1EB+19KapiHNow8YjxdNsJcAEABblZ4A=='
	assert cell_hash(b_cell).hex() == '0cd08328a1c47937892a6b64e9f6609d8b8555a3773c631ae599476fd52433ce'

	// create empty cell 'E'
	e_cell := CellBuilder.new().build()
	assert build_boc_base64(e_cell) == 'te6ccgEBAQEAAgAAAA=='
	assert cell_hash(e_cell).hex() == '96a296d224f285c67bee93c30f8a309157f0daa35dc5b87e410b78630a09cfc7'

	// create leaf cell 'C' with reference to empty cell 'E'
	message := 'hello'.bytes()
	signature := keypair.sign(message)
	mut c_builder := CellBuilder.new()
	c_builder.store_bytes(message)
	c_builder.store_signature(signature)
	c_builder.store_ref(e_cell)
	c_cell := c_builder.build()
	assert build_boc_base64(c_cell) == 'te6ccgEBAgEASgABimhlbGxvkXOdOvFVEZmaARRJuZ0uyWbPKcEnuLe1grLN528JO3LKC4wsfvNmG6Zrb0xNsgK+uYProzFkeZXJUVi68QtWBAEAAA=='
	assert cell_hash(c_cell).hex() == '7763a74df36b577df2365a0a0ef1305072f8152f95f923efd68ffe374ddca3a2'

	// create one more empty cell 'D'
	// it will be a separate reference to cell, but it should be deduplicated during serialization by hash
	d_cell := CellBuilder.new().build()
	assert build_boc_base64(e_cell) == 'te6ccgEBAQEAAgAAAA=='
	assert cell_hash(e_cell).hex() == '96a296d224f285c67bee93c30f8a309157f0daa35dc5b87e410b78630a09cfc7'

	// create cell 'Root'
	amount := token('15123456789')
	mut root_builder := CellBuilder.new()
	root_builder.store_i8(-15)
	root_builder.store_i32(-698547)
	root_builder.store_u128(amount)
	root_builder.store_ones(855)
	root_builder.store_ref(a_cell)
	root_builder.store_ref(b_cell)
	root_builder.store_ref(c_cell)
	root_builder.store_ref(d_cell)
	root_cell := root_builder.build()
	assert root_cell.bits == 1023
	assert root_cell.refs.len == 4
	assert build_boc_base64(root_cell) == 'te6ccgECBQEAARoABP/x//VXTQAAAAAAAAAAAAAAA4VtoxX//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////wQDAQIBimhlbGxvkXOdOvFVEZmaARRJuZ0uyWbPKcEnuLe1grLN528JO3LKC4wsfvNmG6Zrb0xNsgK+uYProzFkeZXJUVi68QtWBAIAAAGDgBoaScgTpi/nJkEAgpd9ZjMCDEnGecSTenzMzpzwfXRqdP21G7yvWBWXGUEsAM0OPUQH7X0pqmIc2jDxiPF02wlwBAAFuVng'
	assert cell_hash(root_cell).hex() == '8c20ad6923cdd1fbfca6630aac9572f4616e8c992b3d5d04e935ebc3e05ce446'
}

fn test_dedup_by_hash() {
	e1 := CellBuilder.new().build()
	e2 := CellBuilder.new().build() // different pointer, same content/hash

	mut rb := CellBuilder.new()
	rb.store_ref(e1)
	rb.store_ref(e2)
	root := rb.build()

	cells := order_cells_parent_first(root)
	// Expect: root + ONE empty cell (deduped by hash) = 2 cells total
	assert cells.len == 2
}
