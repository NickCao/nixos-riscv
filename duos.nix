{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

# The cv1813hXXX_milkv_duos_sd.dtb and fip-duos.bin (aka fip.bin) files in
# the prebuilt/ dir used by this module were generated on Debian via "./build.sh
# lunch" within a fork of Milk V's duo-buildroot-sdk repo at
# https://github.com/mcdonc/duo-buildroot-sdk/tree/nixos-riscv . The fork is
# trivial: four lines were changed to allow dynamic kernel params to be passed
# down to the kernel and to NixOS and to increase available RAM by changing
# ION_SIZE.  The cv1813h_milkv_duos_sd.dtc file in the prebuilt/ dir was
# generated from the cv1813h_milkv_duos_sd.dtb using

# dtc -I dtb  -O dts -o cv1813h_milkv_duos_sd.dts  -@ ~/duo-buildroot-sdk/linux_5.10/build/cv1813h_milkv_duos_sd/arch/riscv/boot/dts/cvitek/cv1813h_milkv_duos_sd.dtb

# The fip.bin file was taken from fsbl/build/cv1813h_milkv_duos_sd/fip.bin
#
# The kernel config file was reused from duo256
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

  configfile = pkgs.writeText "milkv-duo-256-linux-config" (
    builtins.readFile ./prebuilt/duo-s-kernel-config.txt
  );

  kernel =
    (pkgs.linuxManualConfig {
      inherit version src configfile;
      allowImportFromDerivation = true;
    }).overrideAttrs
      {
        preConfigure = ''
          substituteInPlace arch/riscv/Makefile \
            --replace '-mno-ldd' "" \
            --replace 'KBUILD_CFLAGS += -march=$(riscv-march-cflags-y)' \
                      'KBUILD_CFLAGS += -march=$(riscv-march-cflags-y)_zicsr_zifencei -fno-asynchronous-unwind-tables -fno-unwind-tables' \
            --replace 'KBUILD_AFLAGS += -march=$(riscv-march-aflags-y)' \
                      'KBUILD_AFLAGS += -march=$(riscv-march-aflags-y)_zicsr_zifencei'
          substituteInPlace arch/riscv/mm/context.c \
            --replace sptbr CSR_SATP
        '';
      };
  duo_overlay = import ./overlays/duo.nix;

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
    overlays = [
      (final: super: {
        makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
      })
      duo_overlay
    ];
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

  boot.kernelModules = [
    "aic8800_bsp"
    "aic8800_fdrv"
  ];

  system.stateVersion = "25.05";

  system.build.dtb =
    pkgs.runCommand "duos.dtb"
      {
        nativeBuildInputs = [ pkgs.dtc ];
      }
      ''
        dtc -I dts -O dtb -o "$out" ${pkgs.writeText "duos.dts" ''
          /include/ "${./prebuilt/cv1813h_milkv_duos_sd.dts}"
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
        config-cv1813h_milkv_duos_sd {
          description = "boot cvitek system with board cv1812h_milkv_duos";
          kernel = "kernel-1";
          ramdisk = "ramdisk-1";
          fdt = "fdt-1";
        };
      };
    };
  '';

  system.build.bootsd =
    pkgs.runCommand "boot.sd"
      {
        nativeBuildInputs = [
          pkgs.ubootTools
          pkgs.dtc
        ];
      }
      ''
        mkimage -f ${config.system.build.its} "$out"
      '';

  hardware.enableAllFirmware = false;

  hardware.enableAllHardware = lib.mkForce false;

  hardware.enableRedistributableFirmware = false;

  # NOTE: setting hardware.firmwareCompression = "none"is required because the aic8800_fdrv driver module cannot load xz compressed files. If set to xz or zstd, adding the aic8800 firmware to hardware.firmware automatically compresses the files, which in turn will make loading the aic8800_fdrv driver module fail.
  hardware.firmwareCompression = "none";

  hardware.firmware = [
    (pkgs.stdenv.mkDerivation {
      name = "wlan-aic8800-firmware";
      src = "${duo-buildroot-sdk}/device/milkv-duos-sd/overlay/mnt/system/firmware/aic8800/";
      installPhase = ''
        mkdir -p $out/lib/firmware/aic8800
        cp $src/fw_patch_table_8800d80_u02.bin $out/lib/firmware/aic8800/
        cp $src/fw_patch_8800d80_u02.bin $out/lib/firmware/aic8800/
        cp $src/lmacfw_rf_8800d80_u02.bin $out/lib/firmware/aic8800/
        cp $src/aic_userconfig_8800d80.txt $out/lib/firmware/aic8800/
        cp $src/fw_adid_8800d80_u02.bin $out/lib/firmware/aic8800/
        cp $src/fmacfw_8800d80_u02.bin $out/lib/firmware/aic8800/
      '';
    })
  ];

  services.zram-generator = {
    enable = true;
    settings.zram0 = {
      compression-algorithm = "zstd";
      zram-size = "ram * 2";
    };
  };

  users.users.root.initialPassword = "milkv";
  services.getty.autologinUser = "root";
  users.motd = ''Welcome to the milkv duos!'';

  services.udev.enable = false;
  services.nscd.enable = false;
  nix.enable = false;
  system.nssModules = lib.mkForce [ ];

  networking = {
    wireless = {
      enable = true;
      networks."mySSID1".psk = "password";
      networks."mySSID2".psk = "password";
      extraConfig = "ctrl_interface=DIR=/var/run/wpa_supplicant";
    };
    # output ends up in /run/wpa_supplicant/wpa_supplicant.conf
    interfaces.usb0 = {
      ipv4.addresses = [
        {
          address = "192.168.58.2";
          prefixLength = 24;
        }
      ];
    };
    interfaces.end0 = {
      ipv4.addresses = [
        {
          address = "192.168.7.251";
          prefixLength = 24;
        }
      ];
    };
    interfaces.wlan0 = {
      ipv4.addresses = [
        {
          address = "192.168.7.250";
          prefixLength = 24;
        }
      ];
    };
    # dnsmasq reads /etc/resolv.conf to find 8.8.8.8 and 1.1.1.1
    nameservers = [
      "127.0.0.1"
      "8.8.8.8"
      "1.1.1.1"
    ];
    useDHCP = false;
    dhcpcd.enable = false;
    defaultGateway = {
      address = "192.168.7.1";
      interface = "wlan0";
    };
    hostName = "nix-prunus";
    firewall.enable = false;
    networkmanager.enable = false;
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
  systemd.services.sshd.serviceConfig = {
    TimeoutStartSec = 120;
  };

  environment.systemPackages = with pkgs; [
    pfetch
    python311
    usbutils
    inetutils
    iproute2
    helix
    i2c-tools
    blink-blue-led
    eza
    duo-pinmux
    spidev-test
    wpa_supplicant
    wirelesstools
  ];

  programs.less.lessopen = null;

  sdImage = {
    firmwareSize = 64;
    populateRootCommands = "";
    populateFirmwareCommands = ''
      cp ${./prebuilt/fip-duos.bin}  firmware/fip.bin
      cp ${config.system.build.bootsd} firmware/boot.sd
    '';
  };

}
