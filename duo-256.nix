{ config, lib, pkgs, modulesPath, ... }:

# The cv1812cp_milkv_duo256m_sd.dtb and fip-duo256.bin (aka fip.bin) files in
# the prebuilt/ dir used by this module were generated on Ubuntu via "./build.sh
# lunch" within a fork of Milk V's duo-buildroot-sdk repo at
# https://github.com/mcdonc/duo-buildroot-sdk/tree/nixos-riscv . The fork is
# trivial: four lines were changed to allow dynamic kernel params to be passed
# down to the kernel and to NixOS and to increase available RAM by changing
# ION_SIZE.  The cv1812cp_milkv_duo256m_sd.dtc file in the prebuilt/ dir was
# generated from the cv1812cp_milkv_duo256m_sd.dtb using

# dtc -I dtb -O dts -o cv1812cp_milkv_duo256m_sd.dts \
#    -@ linux_5.10/build/cv1812cp_milkv_duo256m_sd/arch/riscv/boot/dts/cvitek/cv1812cp_milkv_duo256m_sd.dtb

# The fip.bin file was taken from fsbl/build/cv1812cp_milkv_duo256m_sd/fip.bin
#
# The file prebuilt/duo-256-kernel-config.txt was created by hand by copying the
# running kernel config from a buildroot-generated duo image and massaging it
# such that it compiled and had proper support for userspace NixOS bits and
# networking.  Note that, for whatever reason, ordering of configuration
# settings *matters* in this file. If you change the ordering of the CONFIG
# settings, you may get compile time errors.  Also, If comments about "is not
# set" are removed it may not work properly.
#
# If stage 2 of the boot from SD fails to boot automatically, it can be booted
# manually. via the U-Boot CLI:

# cv181x_c906# setenv othbootargs ${othbootargs} init=/nix/store/6qq6m4i6zb153nywy5qwr5v33akbzrxk-nixos-system-nixos-24.05.20240215.69c9919/init
# cv181x_c906# boot

# obviously the /nix/store path might be different, but doing

# cv181x_c906# setenv othbootargs ${othbootargs} boot.shell_on_fail
# cv181x_c906# boot

# will let you drop into a prompt to find it in /mnt-root/nix/store


let
  duo-buildroot-sdk = pkgs.fetchFromGitHub {
    owner = "milkv-duo";
    repo = "duo-buildroot-sdk";
    rev = "0e0b8efb59bf8b9664353323abbfdd11751056a4";
    hash = "sha256-tG4nVVXh1Aq6qeoy+J1LfgsW+J1Yx6KxfB1gjxprlXU=";
  };

  version = "5.10.4";
  src = "${duo-buildroot-sdk}/linux_${lib.versions.majorMinor version}";

  configfile = pkgs.writeText "milkv-duo-256-linux-config"
    (builtins.readFile ./prebuilt/duo-256-kernel-config.txt);

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
      substituteInPlace arch/riscv/mm/context.c \
        --replace sptbr CSR_SATP
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
    overlays = [(final: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // {allowMissing = true;});
    })];
  };

  boot.kernelPackages = pkgs.linuxPackagesFor kernel;

  boot.kernelParams = [
    "console=ttyS0,115200"
    "earlycon=sbi"
    "riscv.fwsz=0x80000"
  ];
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

  system.build.dtb = pkgs.runCommand "duo256m.dtb" {
    nativeBuildInputs = [ pkgs.dtc ]; } ''
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

  users.users.root.initialPassword = "milkv";
  services.getty.autologinUser = "root";

  services.udev.enable = false;
  services.nscd.enable = false;
  nix.enable = false;
  system.nssModules = lib.mkForce [ ];

  networking = {
    interfaces.usb0 = {
      ipv4.addresses = [
        {
          address = "192.168.58.2";
          prefixLength = 24;
        }
      ];
    };
    # dnsmasq reads /etc/resolv.conf to find 8.8.8.8 and 1.1.1.1
    nameservers =  [ "127.0.0.1" "8.8.8.8" "1.1.1.1"];
    useDHCP = false;
    dhcpcd.enable = false;
    defaultGateway = "192.168.58.1";
    hostName = "nixos-duo";
    firewall.enable = false;
  };

  # configure usb0 as an RNDIS device
  systemd.tmpfiles.settings = {
    "10-cviusb" = {
      "/proc/cviusb/otg_role".w.argument = "device";
    };
  };

  services.dnsmasq.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "yes";
    };
  };

  # generating the host key takes a while
  systemd.services.sshd.serviceConfig ={
    TimeoutStartSec = 120;
  };

  environment.systemPackages = with pkgs; [
    pfetch python311 usbutils inetutils iproute2 vim
  ];

  programs.less.lessopen = null;

  sdImage = {
    firmwareSize = 64;
    populateRootCommands = "";
    populateFirmwareCommands = ''
      cp ${./prebuilt/fip-duo256.bin}  firmware/fip.bin
      cp ${config.system.build.bootsd} firmware/boot.sd
    '';
  };

}
