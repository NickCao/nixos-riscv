{
  inputs = {
    nixpkgs.url = "github:NickCao/nixpkgs/riscv";
  };
  outputs = { self, nixpkgs }: {
    hydraJobs = with self.nixosConfigurations.unmatched; {
      unmatched = config.system.build.toplevel;
      inherit (pkgs) qemu opensbi-unmatched uboot-unmatched bootrom-unmatched chromium
        apacheHttpd emacs firefox firefox-lto imagemagick mysql nginx nodejs-17_x pandoc php postgresql subversion vim gtk3;
      inherit (pkgs.libsForQt5) qtbase qtdeclarative qtmultimedia qtsvg qttools qtwebengine qtwebview;
      gnomePkgs = pkgs.lib.filterAttrs (_: drv: pkgs.lib.isDerivation (builtins.tryEval drv).value) pkgs.gnome;
      goPkgs = import ./go-packages.nix { inherit pkgs; };
      rustPkgs = import ./rust-packages.nix { inherit pkgs; };
      pythonPkgs = pkgs.lib.filterAttrs (_: drv: pkgs.lib.isDerivation (builtins.tryEval drv).value) pkgs.python3Packages;
    };
    overlay = final: prev: rec {
      libmysqlclient = null;
      gtk3 = prev.gtk3.override { trackerSupport = false; };
      git = prev.git.override { perlSupport = false; }; # https://github.com/NixOS/nixpkgs/issues/66741
      xdg-utils = prev.coreutils; # also relies on perl
      qemu = prev.qemu.override { gtkSupport = false; };
      firefox-unwrapped = prev.firefox-unwrapped.override { webrtcSupport = false; ltoSupport = false; };
      firefox-unwrapped-lto = prev.firefox-unwrapped.override { webrtcSupport = false; ltoSupport = true; };
      firefox = prev.wrapFirefox firefox-unwrapped { };
      firefox-lto = prev.wrapFirefox firefox-unwrapped-lto { };
      meta-sifive = prev.fetchFromGitHub {
        owner = "sifive";
        repo = "meta-sifive";
        rev = "2021.11.00";
        sha256 = "sha256-Toh80cXl+w1QFrbZnCP2Bjg2eN1V8vItACOO7/rWx0k=";
      };
      opensbi-unmatched = prev.stdenv.mkDerivation rec {
        pname = "opensbi";
        version = "22d556d26809775e2ac19251e5df9075434ee66e";
        src = prev.fetchFromGitHub {
          owner = "riscv";
          repo = "opensbi";
          rev = version;
          sha256 = "sha256-9j/0D4t15TlTHXtkDj0BQ0W7M5Uom7U8b6gnVq8vjrI=";
        };
        patches = map (patch: "${final.meta-sifive}/recipes-bsp/opensbi/files/${patch}") [
          "0001-Makefile-Don-t-specify-mabi-or-march.patch"
        ];
        hardeningDisable = [ "all" ];
        makeFlags = [
          "PLATFORM=generic"
          "I=$(out)"
        ];
      };
      uboot-unmatched = prev.buildUBoot rec {
        version = "2021.10";
        src = prev.fetchFromGitHub {
          owner = "u-boot";
          repo = "u-boot";
          rev = "v${version}";
          sha256 = "sha256-2CcIHGbm0HPmY63Xsjaf/Yy78JbRPNhmvZmRJAyla2U=";
        };
        defconfig = "sifive_unmatched_defconfig";
        extraPatches = map (patch: "${final.meta-sifive}/recipes-bsp/u-boot/files/riscv64/${patch}") [
          "0001-riscv-sifive-unleashed-support-compressed-images.patch"
          "0002-board-sifive-spl-Initialized-the-PWM-setting-in-the-.patch"
          "0003-board-sifive-Set-LED-s-color-to-purple-in-the-U-boot.patch"
          "0004-board-sifive-Set-LED-s-color-to-blue-before-jumping-.patch"
          "0005-board-sifive-spl-Set-remote-thermal-of-TMP451-to-85-.patch"
          "0006-riscv-sifive-unmatched-leave-128MiB-for-ramdisk.patch"
          "0007-riscv-sifive-unmatched-disable-FDT-and-initrd-reloca.patch"
        ] ++ [ ./u-boot-spi.patch ];
        extraMakeFlags = [
          "OPENSBI=${final.opensbi-unmatched}/share/opensbi/lp64/generic/firmware/fw_dynamic.bin"
        ];
        extraConfig = ''
          CONFIG_FS_EXT4=y
          CONFIG_CMD_EXT4=y
          CONFIG_SPL_SPI_FLASH_SUPPORT=y
          CONFIG_SPL_DM_SPI_FLASH=y
          CONFIG_SPL_SPI_LOAD=y
          CONFIG_USE_ENV_SPI_BUS=y
          CONFIG_ENV_SPI_BUS=1
          CONFIG_SPI_FLASH_ISSI=y
        '';
        filesToInstall = [ "u-boot.itb" "spl/u-boot-spl.bin" ];
      };
      bootrom-unmatched = prev.runCommand "bootrom"
        {
          nativeBuildInputs = with prev.buildPackages; [ gptfdisk ];
        } ''
        set +o pipefail
        mkdir -p "$out/nix-support"
        tr '\0' '\377' < /dev/zero | dd of="$out/flash.bin" iflag=fullblock bs=1M count=32
        sgdisk -g --clear -a 1 \
          --new=1:40:2087     --change-name=1:spl   --typecode=1:5B193300-FC78-40CD-8002-E86C45580B47 \
          --new=2:2088:10279  --change-name=2:uboot --typecode=2:2E54B353-1271-4842-806F-E436D6AF6985 \
          --new=3:10280:10535 --change-name=3:env   --typecode=3:0FC63DAF-8483-4772-8E79-3D69D8477DE4 \
          "$out/flash.bin"
        dd if=${final.uboot-unmatched}/u-boot-spl.bin of="$out/flash.bin" bs=4096 seek=5 conv=sync
        dd if=${final.uboot-unmatched}/u-boot.itb  of="$out/flash.bin" bs=4096 seek=261 conv=sync
        echo "file bin \"$out/flash.bin\"" >> "$out/nix-support/hydra-build-products"
      '';
    };
    nixosConfigurations = {
      unmatched = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ config, pkgs, lib, modulesPath, ... }: {
            imports = [ "${modulesPath}/installer/sd-card/sd-image.nix" ];
            disabledModules = [ "profiles/all-hardware.nix" ];
            nixpkgs = {
              crossSystem.config = "riscv64-unknown-linux-gnu";
              config.allowUnfree = true;
              overlays = [ self.overlay ];
            };
            sdImage = {
              populateRootCommands = ''
                mkdir -p ./files/boot
                ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
              '';
              populateFirmwareCommands = "";
            };
            boot.loader = {
              grub.enable = false;
              generic-extlinux-compatible.enable = true;
            };
            boot.initrd.kernelModules = [ "nvme" "mmc_block" "mmc_spi" "spi_sifive" "spi_nor" "uas" "sdhci_pci" ];
            boot.kernelParams = [ "console=ttySIF1" ];
            boot.kernelPackages = pkgs.linuxPackages_latest;
            boot.kernelPatches = map (patch: { name = patch; patch = "${pkgs.meta-sifive}/recipes-kernel/linux/files/${patch}"; }) [
              "0001-riscv-sifive-fu740-cpu-1-2-3-4-set-compatible-to-sif.patch"
              "0002-riscv-sifive-unmatched-update-regulators-values.patch"
              "0003-riscv-sifive-unmatched-define-PWM-LEDs.patch"
              "0004-riscv-sifive-unmatched-add-gpio-poweroff-node.patch"
              "0005-SiFive-HiFive-Unleashed-Add-PWM-LEDs-D1-D2-D3-D4.patch"
              "0006-riscv-sifive-unleashed-define-opp-table-cpufreq.patch"
              "riscv-sbi-srst-support.patch"
            ] ++ [{
              name = "sifive";
              patch = null;
              extraConfig = ''
                SOC_SIFIVE y
                PCIE_FU740 y
                PWM_SIFIVE y
                EDAC_SIFIVE y
                SIFIVE_L2 y
                RISCV_ERRATA_ALTERNATIVE y
                ERRATA_SIFIVE y
                ERRATA_SIFIVE_CIP_453 y
                ERRATA_SIFIVE_CIP_1200 y
              '';
            }];
            services.udisks2.enable = false;
            security.polkit.enable = false;
            services.getty.autologinUser = "nickcao";
            services.openssh.enable = true;
            environment.systemPackages = with pkgs; [
              neofetch
              mtdutils
              lm_sensors
              waypipe
              pciutils
              glxinfo
              radeontop
              iperf3
              gdb
            ];
            networking.wireless.iwd.enable = true;
            hardware.firmware = with pkgs; [ firmwareLinuxNonfree ];
            hardware.opengl.enable = true;
            programs.sway.enable = true;
            fonts.fontconfig.enable = false;
            users = {
              mutableUsers = false;
              users = {
                root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLQwaWXeJipSuAB+lV202yJOtAgJSNzuldH7JAf2jji" ];
                nickcao = {
                  openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLQwaWXeJipSuAB+lV202yJOtAgJSNzuldH7JAf2jji" ];
                  isNormalUser = true;
                };
              };
            };
          })
        ];
      };
    };
  };
}
