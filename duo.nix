{ config, lib, pkgs, modulesPath, ... }:
let
  duo-buildroot-sdk = pkgs.fetchFromGitHub {
    owner = "milkv-duo";
    repo = "duo-buildroot-sdk";
    rev = "bb11c7ccf5bfd90d9acf2dc2d753ab4dfec8341d";
    hash = "sha256-FNSKTfen/JfWtb7Hng6JjjFbUxV9B4bNAriVL8206CY=";
  };
  version = "5.10.4";
  src = "${duo-buildroot-sdk}/linux_${lib.versions.majorMinor version}";
  extraconfig = pkgs.writeText "extraconfig" ''
    CONFIG_CGROUPS=y
    CONFIG_SYSFS=y
    CONFIG_PROC_FS=y
    CONFIG_FHANDLE=y
    CONFIG_CRYPTO_USER_API_HASH=y
    CONFIG_CRYPTO_HMAC=y
    CONFIG_DMIID=y
    CONFIG_AUTOFS_FS=y
    CONFIG_TMPFS_POSIX_ACL=y
    CONFIG_TMPFS_XATTR=y
    CONFIG_SECCOMP=y
    CONFIG_BLK_DEV_INITRD=y
    CONFIG_BINFMT_ELF=y
    CONFIG_INOTIFY_USER=y
  '';
  # hack: drop duplicated entries
  configfile = pkgs.runCommand "config" { } ''
    cp "${duo-buildroot-sdk}/build/boards/cv180x/cv1800b_milkv_duo_sd/linux/cvitek_cv1800b_milkv_duo_sd_defconfig" "$out"
    substituteInPlace "$out" \
      --replace CONFIG_BLK_DEV_INITRD=y "" \
      --replace CONFIG_DEBUG_FS=y       "" \
      --replace CONFIG_VECTOR=y         "" \
      --replace CONFIG_SIGNALFD=n       CONFIG_SIGNALFD=y \
      --replace CONFIG_TIMERFD=n        CONFIG_TIMERFD=y \
      --replace CONFIG_EPOLL=n          CONFIG_EPOLL=y
    cat ${extraconfig} >> "$out"
  '';
  kernel = (pkgs.linuxManualConfig {
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
  };
in
{

  disabledModules = [
    "profiles/all-hardware.nix"
  ];

  imports = [
    "${modulesPath}/installer/sd-card/sd-image.nix"
  ];

  nixpkgs = {
    localSystem.config = "x86_64-unknown-linux-gnu";
    crossSystem.config = "riscv64-unknown-linux-gnu";
  };

  boot.kernelPackages = pkgs.linuxPackagesFor kernel;

  boot.initrd = {
    compressor = "zstd";
    compressorArgs = [ "-22" "--ultra" ];
    includeDefaultModules = false;
  };

  boot.loader = {
    grub.enable = false;
  };

  system.build.its = pkgs.writeText "cv180x.its" ''
    /dts-v1/;

    / {
      description = "Various kernels, ramdisks and FDT blobs";
      #address-cells = <2>;

      images {
        kernel-1 {
          description = "kernel";
          type = "kernel";
          data = /incbin/("${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}");
          arch = "riscv";
          os = "linux";
          compression = "none";
          load = <0x00 0x80200000>;
          entry = <0x00 0x80200000>;
          hash-2 {
            algo = "crc32";
          };
        };

        /*
        ramdisk-1 {
          description = "ramdisk";
          type = "ramdisk";
          data = /incbin/("${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}");
          arch = "riscv";
          os = "linux";
          compression = "none";
          load = <00000000>;
          entry = <00000000>;
        };
        */

        fdt-1 {
          description = "flat_dt";
          type = "flat_dt";
          data = /incbin/("${./cv1800b_milkv_duo_sd.dtb}");
          arch = "riscv";
          compression = "none";
          hash-1 {
            algo = "sha256";
          };
        };
      };

      configurations {
        config-cv1800b_milkv_duo_sd {
          description = "boot cvitek system with board cv1800b_milkv_duo_sd";
          kernel = "kernel-1";
          /*
          ramdisk = "ramdisk-1";
          */
          fdt = "fdt-1";
        };
      };
    };
  '';

  system.build.bootsd = pkgs.runCommand "boot.sd"
    {
      nativeBuildInputs = [ pkgs.ubootTools pkgs.dtc ];
    } ''
    mkimage -f ${config.system.build.its} "$out"
  '';

  sdImage = {
    populateFirmwareCommands = ''
      cp ${./fip.bin}                  firmware/fip.bin
      cp ${config.system.build.bootsd} firmware/boot.sd
    '';
    populateRootCommands = "";
  };

}
