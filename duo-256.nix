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
#
#  Native ethernet is untested. GPIO is untested.
#
# You should be able to ssh to the Duo after plugging it in via RNDIS just like
# the buildroot image at root@192.168.42.1.  It takes about 30 seconds for the
# ssh server to start after the interface has been recognized by the host, be
# patient.  The password is "milkv".
#
# The Duo will have NAT access to the larger internet if you do the following,
# on the host the Duo is connected to.  The Duo itself needs no extra
# configuration.
#
#   "echo 1 > /proc/sys/net/ipv4/ip_forward"
#
# or (in NixOS) via declarative sysctl setup
#
#   boot.kernel.sysctl = { "net.ipv4.conf.all.forwarding" = true; };

# Then execute the following nftables script (I was unable to quickly make this
# work declaratively in my NixOS host config via "networking.nftables.ruleset";
# it's probably possible) which enables routing packets via masquerade from the
# Duo to the internet, changing the interface names as necessary.  Once
# executed, the Duo will be able to communicate with the outside world, using
# the host as a router. Note that on a NixOS host machine, you do *not* need
# "networking.firewall.enable = true;" for this to work.
# "networking.nftables.enable = true;" makes the nft command available.

#    #!/run/current-system/sw/bin/nft -f
#
#    # enp1s0 is my ethernet interface, connected to my Internet router.
#    # enp0s20f0u7u2 is the RNDIS interface created by attaching the Duo to
#    # USB.  Change as necessary.
#
#    table ip duo_table {
#           chain duo_nat {
#                   type nat hook postrouting priority 0; policy accept;
#                   oifname "enp1s0" masquerade
#           }
#
#          chain duo_forward {
#                   type filter hook forward priority 0; policy accept;
#                   iifname "enp0s20f0u7u2" oifname "enp1s0" accept
#           }
#    }

let
  duo-buildroot-sdk = pkgs.fetchFromGitHub {
    owner = "milkv-duo";
    repo = "duo-buildroot-sdk";
    rev = "0e0b8efb59bf8b9664353323abbfdd11751056a4";
    hash = "sha256-tG4nVVXh1Aq6qeoy+J1LfgsW+J1Yx6KxfB1gjxprlXU=";
  };

  host_addr = "00:22:82:ff:ff:20";
  dev_addr  = "00:22:82:ff:ff:22";

  version = "5.10.4";
  src = "${duo-buildroot-sdk}/linux_${lib.versions.majorMinor version}";

  route-cmd = "${pkgs.nettools}/bin/route";

  set-default-route = pkgs.writers.writePython3 "set-default-route" {
    flakeIgnore = [ "E501" ]; } ''
     # dnsmasq runs this script as root whenever a DHCP event occurs.
     # We set the default route to whatever IP the RNDIS host winds up with.

     import sys
     import os

     if len(sys.argv) >= 4:

         op, ip = sys.argv[1], sys.argv[3]

         # If it's a new DHCP lease, set the default route to the IP
         # address we've handed out (the RNDIS host).

         if op == "add":
             sys.stderr.write("Setting default gateway to %s\n" % ip)
             os.system("${route-cmd} del default")
             os.system("${route-cmd} add default gw %s" % ip)
  '';

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

  # g_ether.host_addr is meant to cause the machine the Duo is connected to use
  # its value as the MAC address of its USB RNDIS virtual interface.
  #
  # g_ether.dev_addr causes the Duo itself to use its value as the MAC address
  # of its RNDIS USB virtual interface.
  #
  # On observation, frustratingly, sometimes the RNDIS host will generate a
  # random MAC address for its USB RNDIS virtual interface anyway.  This has
  # only been observed after rebooting the host: on the first boot, after
  # plugging the Duo in, the RNDIS interface on the host will be "usb0" and will
  # have a randomized MAC.  Upon unplugging the Duo and replugging it in,
  # though, the usb0 interface will disappear and a new host RNDIS interface
  # named something like "enp0s20f0u7u3u2" will appear and will have the
  # g_ether.host_addr MAC. Every single disconnect and reconnect will result in
  # the same situation.  But this quirk causes us to need to tell dnsmasq to
  # hand out more than a single IP address. :(

  boot.kernelParams = [
    "console=ttyS0,115200"
    "earlycon=sbi"
    "riscv.fwsz=0x80000"
    "g_ether.host_addr=${host_addr}"
    "g_ether.dev_addr=${dev_addr}"
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
          address = "192.168.42.1";
          prefixLength = 24;
        }
      ];
    };
    # dnsmasq reads /etc/resolv.conf to find 8.8.8.8
    nameservers =  [ "127.0.0.1" "8.8.8.8" ];
    useDHCP = false;
    hostName = "nixos-duo";
    firewall.enable = false;
  };

  # configure usb0 as an RNDIS device
  systemd.tmpfiles.settings = {
    "10-cviusb" = {
      "/proc/cviusb/otg_role".w.argument = "device";
    };
  };

  # See also
  # https://community-milkv-io.translate.goog/t/arch-linux-on-milkv-duo-milkv-duo-arch-linux/329?_x_tr_sl=auto&_x_tr_tl=en&_x_tr_hl=en&_x_tr_pto=wapp&_x_tr_hist=true
  # https://www.marcusfolkesson.se/blog/nat-with-linux/

  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "usb0";
      # hand out 192.168.42.2 - 192.168.42.5
      dhcp-range = [ "192.168.42.2,192.168.42.5,1h"];
      # 3: default gateway, 6: DNS servers
      dhcp-option = [ "3" "6" ];
      # when a DHCP event occurs, run the script to set the default route
      dhcp-script = "${set-default-route}";
      # do not maintain a persistent leasefile
      leasefile-ro = true;
      # always give the same IP to the host
      dhcp-host = [ "${host_addr},192.168.42.2" ];
    };
  };

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

  sdImage = {
    firmwareSize = 64;
    populateRootCommands = "";
    populateFirmwareCommands = ''
      cp ${./prebuilt/fip-duo256.bin}  firmware/fip.bin
      cp ${config.system.build.bootsd} firmware/boot.sd
    '';
  };

}
