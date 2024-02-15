{ config, lib, pkgs, modulesPath, ... }:

# The cv1812cp_milkv_duo256m_sd.dtb and fip-duo256.bin (aka fip.bin) files in
# the prebuilt/ dir used by this module were generated on Ubuntu via "./build.sh
# lunch" within a fork of Milk V's duo-buildroot-sdk repo at
# https://github.com/mcdonc/duo-buildroot-sdk/tree/nixos-riscv . The fork is
# trivial: two lines were changed to allow dynamic kernel params to be passed
# down to the kernel and to NixOS.  The cv1812cp_milkv_duo256m_sd.dtc file in
# the prebuilt/ dir was generated from the cv1812cp_milkv_duo256m_sd.dtb using
#
# dtc -I dtb -O dts -o cv1812cp_milkv_duo256m_sd.dts \
#    -@ linux_5.10/build/cv1812cp_milkv_duo256m_sd/arch/riscv/boot/dts/cvitek/cv1812cp_milkv_duo256m_sd.dtb
#
# The fip.bin file was taken from fsbl/build/cv1812cp_milkv_duo256m_sd/fip.bin

let
  duo-buildroot-sdk = pkgs.fetchFromGitHub {
    owner = "milkv-duo";
    repo = "duo-buildroot-sdk";
    rev = "0e0b8efb59bf8b9664353323abbfdd11751056a4";
    hash = "sha256-tG4nVVXh1Aq6qeoy+J1LfgsW+J1Yx6KxfB1gjxprlXU=";
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
    CONFIG_CRYPTO_ZSTD=y
    CONFIG_ZRAM=y
    CONFIG_MAGIC_SYSRQ=y
  '';
  # hack: drop duplicated entries
  configfile = pkgs.runCommand "config" { } ''
    cp "${duo-buildroot-sdk}/build/boards/cv181x/cv1812cp_milkv_duo256m_sd/linux/cvitek_cv1812cp_milkv_duo256m_sd_defconfig" "$out"
    substituteInPlace "$out" \
      --replace CONFIG_BLK_DEV_INITRD=y "" \
      --replace CONFIG_DEBUG_FS=y       "" \
      --replace CONFIG_VECTOR=y         "" \
      --replace CONFIG_POWER_RESET=y    "" \
      --replace CONFIG_RTC_CLASS=y      "" \
      --replace CONFIG_ZRAM=m           "" \
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

  boot.kernelParams = [ "console=ttyS0,115200" "earlycon=sbi" "riscv.fwsz=0x80000" ];
  boot.consoleLogLevel = 9;

  boot.initrd.includeDefaultModules = false;
  boot.initrd.systemd = {
    # enable = true;
    # enableTpm2 = false;
  };

  boot.loader = {
    grub.enable = false;
  };

  boot.kernel.sysctl = {
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
    "vm.swappiness" = 180;
    "kernel.pid_max" = 4096 * 8; # PAGE_SIZE * 8
  };

  system.build.dtb = pkgs.runCommand "duo256m.dtb" { nativeBuildInputs = [ pkgs.dtc ]; } ''
    dtc -I dts -O dtb -o "$out" ${pkgs.writeText "duo256m.dts" ''
      /include/ "${./prebuilt/cv1812cp_milkv_duo256m_sd.dts}"
      / {
        chosen {
          bootargs = "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}";
        };
      };
    ''}
  '';

  system.build.its = pkgs.writeText "cv181x.its" ''
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

        fdt-1 {
          description = "flat_dt";
          type = "flat_dt";
          data = /incbin/("${config.system.build.dtb}");
          arch = "riscv";
          compression = "none";
          hash-1 {
            algo = "sha256";
          };
        };
      };

      configurations {
        config-cv1812cp_milkv_duo256m_sd {
          description = "boot cvitek system with board cv1812cp_milkv_duo256m";
          kernel = "kernel-1";
          ramdisk = "ramdisk-1";
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

  services.zram-generator = {
    enable = true;
    settings.zram0 = {
      compression-algorithm = "zstd";
      zram-size = "ram * 2";
    };
  };

  users.users.root.initialHashedPassword = "";
  services.getty.autologinUser = "root";

  services.udev.enable = false;
  services.nscd.enable = false;
  networking.firewall.enable = false;
  networking.useDHCP = false;
  nix.enable = false;
  system.nssModules = lib.mkForce [ ];

  environment.systemPackages = with pkgs; [ pfetch python311 ];

  sdImage = {
    firmwareSize = 64;
    populateRootCommands = "";
    populateFirmwareCommands = ''
      cp ${./prebuilt/fip-duo256.bin}  firmware/fip.bin
      cp ${config.system.build.bootsd} firmware/boot.sd
    '';
  };

}
