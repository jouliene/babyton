import babyton { KeyPair }

fn main() {
	keypair := KeyPair.from_secret_string('8248d37cd689d02f4071dfa74737f6f23c85eebc46cdb44157a631a3f4d01f3a')
	message := 'hello'.bytes()
	signature := keypair.sign_raw(message)
	println(signature.hex())
}
