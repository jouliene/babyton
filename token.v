module babyton

import math.big

// Helper to create U128 token amount from string
pub fn token(s string) U128 {
	return big.integer_from_string(s) or { panic('[ERROR] invalid token amount') }
}
