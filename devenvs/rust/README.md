# rust devenv

A development environment for the milkv duo chips.

Supports compiling against

* glibc using `riscv64-unknown-linux-gnu` for the nixos image built with this repo
* musl using `riscv64-unknown-linux-musl` for the official duo-buildroot image. Uncomment the correct triple in `flake.nix`.

Note that often the loader is not found. Use `readelf -l milkv-rust-binary | grep "interpreter"` to identify the absolute path of the interpreter. Then either patch the binary or create a symbolic link on the target system pointing to the actual ld, eg. `ln -s /lib/ld-musl-riscv64v0p7_xthead.so.1 /lib/ld-musl-riscv64.so.1`


When using the nixos image built with this project its best to reference the lock file of the image. This will garantee that the interpreter paths match.

```
  $ nix develop --reference-lock-file --no-write-lock-file ../../flake.lock -c fish
```
