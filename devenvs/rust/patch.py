from pathlib import Path

base_dir = Path("build")
file_in = base_dir / "riscv-musl-helloworld"
file_out = base_dir / "riscv-musl-helloworld-patched"
patch_content = "xgyi8gpldn3jy4djxzqvivrx1ar5fgbg".encode("ascii")
patch_offset = 0x2B3
patch_len = len(patch_content)


with open(file_in, "rb") as fin:
    with open(file_out, "wb") as fout:
        j = 0
        i = 0
        while b := fin.read(1):
            if i >= patch_offset and i < (patch_offset + patch_len):
                data = patch_content[j].to_bytes(1)
                print(f"reached byte {i}, patching byte {j}: {data}, replacing {b}")
                fout.write(data)
                j += 1
            else:
                fout.write(b)
            i += 1
