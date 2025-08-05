module babyton

//------------------
// KeyPair submodule
//------------------
//
// Minimal functionality to generate new random keypair
// or create keypair from secret key
import crypto.ed25519
import encoding.hex

pub struct KeyPair {
pub:
	pubkey []u8 // 32 bytes
	secret []u8 // 32 bytes
}

// Generate new ed25519 keypair
pub fn KeyPair.generate() KeyPair {
	pubkey, secret := ed25519.generate_key() or { panic('[ERROR] Failed to generate key pair}') }
	return KeyPair{
		pubkey: pubkey
		secret: secret[..32]
	}
}

// Generate new ed25519 keypair from secret key in bytes form
pub fn KeyPair.from_secret_bytes(secret []u8) KeyPair {
	full_secret_key := ed25519.new_key_from_seed(secret)
	pubkey := ed25519.PrivateKey(full_secret_key).public_key()
	return KeyPair{
		pubkey: pubkey
		secret: secret
	}
}

// Generate new ed25519 keypair from secret key in string hex form
pub fn KeyPair.from_secret_string(secret string) KeyPair {
	mut s := secret.trim_space()
	if s.starts_with('0x') || s.starts_with('0x') {
		s = s[2..]
	}
	secret_bytes := hex.decode(s) or { panic('[ERROR] Invalid secret key hex string') }
	return KeyPair.from_secret_bytes(secret_bytes)
}

// Create 64 bytes / 512 bits ed25519 signature
pub fn (self KeyPair) sign(message []u8) []u8 {
	full_secret_key := ed25519.new_key_from_seed(self.secret)
	signature := ed25519.sign(full_secret_key, message) or {
		panic('[ERROR] Failed to sign message')
	}
	return signature
}

// Verify signature
pub fn verify(pubkey []u8, message []u8, signature []u8) bool {
	ok := ed25519.verify(pubkey, message, signature) or {
		panic('[ERROR] Failed to verify signature')
	}
	return ok
}

// Helper function to print keypair
pub fn (self KeyPair) str() string {
	return 'KeyPair{pubkey: ${hex.encode(self.pubkey)}, secret: ${hex.encode(self.secret)}}'
}
