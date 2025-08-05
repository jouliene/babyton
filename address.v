module babyton

// -----------------
// Address submodule
// -----------------
//
// Minimal standard address type used by CellBuilder.store_address.
// Ordinary-only: no anycast/exotic forms here.
import encoding.hex

// Simple standard address structure
pub struct StdAddr {
	workchain i8   // 0 workchain or -1 masterchain
	address   []u8 // 32 bytes
}

// Helper function to print StdAddr
pub fn (a StdAddr) str() string {
	return '${a.workchain}:${hex.encode(a.address)}'
}

// Create new address instance from address string
pub fn StdAddr.from_string(s string) StdAddr {
	t := s.trim_space()
	parts := t.split(':')
	if parts.len != 2 {
		panic('[ERROR] address format expected as "workchain:hex"')
	}
	wc := parts[0].i8()
	addr := hex.decode(parts[1]) or { panic('[ERROR] while parsing address string') }
	if addr.len != 32 {
		panic('[ERROR] address hex should have 32 bytes')
	}
	return StdAddr{
		workchain: wc
		address:   addr
	}
}

// Create new address instance from parts
pub fn StdAddr.from_parts(wc i8, addr []u8) StdAddr {
	return StdAddr{
		workchain: wc
		address:   addr
	}
}
