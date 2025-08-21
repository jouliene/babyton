module babyton

import crypto.sha256

// Helper to compute ABI v2 function ID (uint32 from first 4 bytes of SHA256(signature))
pub fn compute_abi_function_id(signature string) u32 {
	hash := sha256.sum(signature.bytes())
	return u32(hash[0]) << 24 | u32(hash[1]) << 16 | u32(hash[2]) << 8 | u32(hash[3])
}
