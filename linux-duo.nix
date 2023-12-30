{ lib
, fetchFromGitHub
, runCommand
, linuxManualConfig
}:
let
  duo-buildroot-sdk = fetchFromGitHub {
    owner = "milkv-duo";
    repo = "duo-buildroot-sdk";
    rev = "bb11c7ccf5bfd90d9acf2dc2d753ab4dfec8341d";
    hash = "sha256-FNSKTfen/JfWtb7Hng6JjjFbUxV9B4bNAriVL8206CY=";
  };
  version = "5.10.4";
  src = "${duo-buildroot-sdk}/linux_${lib.versions.majorMinor version}";
  # hack: drop duplicated entries
  configfile = runCommand "config" { } ''
    cp "${duo-buildroot-sdk}/build/boards/cv180x/cv1800b_milkv_duo_sd/linux/cvitek_cv1800b_milkv_duo_sd_defconfig" "$out"
    substituteInPlace "$out" \
      --replace CONFIG_BLK_DEV_INITRD=y "" \
      --replace CONFIG_DEBUG_FS=y       "" \
      --replace CONFIG_VECTOR=y         ""
  '';
in
(linuxManualConfig {
  inherit version src configfile;
  allowImportFromDerivation = true;
}).overrideAttrs {
  preConfigure = ''
    substituteInPlace arch/riscv/Makefile \
      --replace '-mno-ldd' "" \
      --replace 'KBUILD_CFLAGS += -march=$(riscv-march-cflags-y)' \
                'KBUILD_CFLAGS += -march=$(riscv-march-cflags-y)_zicsr_zifencei' \
      --replace 'KBUILD_AFLAGS += -march=$(riscv-march-aflags-y)' \
                'KBUILD_AFLAGS += -march=$(riscv-march-aflags-y)_zicsr_zifencei'
  '';
}
