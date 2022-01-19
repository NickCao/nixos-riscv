{
  inputs = {
    nixpkgs.url = "github:NickCao/nixpkgs/riscv";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rustsbi = {
      url = "github:NickCao/rustsbi-hifive-unmatched";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, rust-overlay, rustsbi }: {
    hydraJobs = with self.nixosConfigurations.unmatched; {
      unmatched = config.system.build.toplevel;
      inherit (pkgs) qemu opensbi-unmatched uboot-unmatched bootrom-unmatched uboot-unmatched-ram rustsbi-unmatched;
    };
    overlay = final: prev: rec {
      xdg-utils = prev.coreutils;
      meta-sifive = prev.fetchFromGitHub {
        owner = "sifive";
        repo = "meta-sifive";
        rev = "2021.12.00";
        sha256 = "sha256-zv05wAQ+pVUQGq7GCrU8tLzqGf7PLUOswUoiQ0A6Dd4=";
      };
      rustsbi-unmatched = prev.stdenv.mkDerivation rec {
        name = "rustsbi-unmatched";
        src = rustsbi;
        cargoDeps = prev.rustPlatform.importCargoLock {
          lockFile = "${src}/Cargo.lock";
          outputHashes = {
            "fu740-hal-0.1.0" = "sha256-h5zrJbRMHQntnhCtl4NSNynsaZaHRb+LYULtpO0Fumg=";
            "fu740-pac-0.1.0" = "sha256-cnUJtFCDDm5cZQSe7+7Izk0japS27M/kMCZiAf9NdrM=";
          };
        };
        nativeBuildInputs = with prev.buildPackages;[
          rustPlatform.cargoSetupHook
          (rust-bin.nightly.latest.minimal.override {
            extensions = [ "llvm-tools-preview" ];
            targets = [ "riscv64imac-unknown-none-elf" ];
          })
          cargo-binutils
        ];
        buildPhase = ''
          cargo make --release
        '';
        installPhase = ''
          install -Dm644 target/riscv64imac-unknown-none-elf/release/rustsbi-hifive-unmatched.bin "$out/rustsbi-hifive-unmatched.bin"
          install -Dm644 target/riscv64imac-unknown-none-elf/release/rustsbi-hifive-unmatched "$out/rustsbi-hifive-unmatched"
        '';
      };
      opensbi-unmatched = prev.stdenv.mkDerivation rec {
        pname = "opensbi";
        version = "1.0";
        src = prev.fetchFromGitHub {
          owner = "riscv";
          repo = "opensbi";
          rev = "v${version}";
          sha256 = "sha256-OgzcH+RLU680qF3+lUiWFFbif6YtjIknJriGlRqcOGs=";
        };
        makeFlags = [
          "PLATFORM=generic"
          "I=$(out)"
        ];
      };
      uboot-unmatched = prev.buildUBoot rec {
        version = "6ef836accea026a5f87145f890ee47748bc8bfac";
        src = prev.fetchFromGitHub {
          owner = "u-boot";
          repo = "u-boot";
          rev = "${version}";
          sha256 = "sha256-mR8ooGVQG2yRsRRhiZAqx3gzAQEnWYZ6i5zcB8hJlCU=";
        };
        defconfig = "sifive_unmatched_defconfig";
        extraPatches = map (patch: "${final.meta-sifive}/recipes-bsp/u-boot/files/riscv64/${patch}") [
          "0001-riscv-sifive-unleashed-support-compressed-images.patch"
          "0002-board-sifive-spl-Initialized-the-PWM-setting-in-the-.patch"
          "0003-board-sifive-Set-LED-s-color-to-purple-in-the-U-boot.patch"
          "0004-board-sifive-Set-LED-s-color-to-blue-before-jumping-.patch"
          # "0005-board-sifive-spl-Set-remote-thermal-of-TMP451-to-85-.patch"
          "0006-riscv-sifive-unmatched-leave-128MiB-for-ramdisk.patch"
          "0007-riscv-sifive-unmatched-disable-FDT-and-initrd-reloca.patch"
        ];
        extraMakeFlags = [
          "OPENSBI=${final.opensbi-unmatched}/share/opensbi/lp64/generic/firmware/fw_dynamic.bin"
        ];
        extraConfig = ''
          CONFIG_FS_EXT4=y
          CONFIG_CMD_EXT4=y
        '';
        filesToInstall = [ "u-boot.itb" "spl/u-boot-spl.bin" ];
      };
      uboot-unmatched-ram = uboot-unmatched.overrideAttrs (attrs: { patches = attrs.patches ++ [ ./0001-board-sifive-spl-boot-from-ram.patch ]; });
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
            imports = [
              "${modulesPath}/profiles/base.nix"
              "${modulesPath}/installer/sd-card/sd-image.nix"
            ];
            nixpkgs = {
              crossSystem.config = "riscv64-unknown-linux-gnu";
              config = {
                allowUnfree = true;
                allowBroken = true;
              };
              overlays = [ rust-overlay.overlay self.overlay ];
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
              # "0002-riscv-sifive-unmatched-update-regulators-values.patch"
              "0003-riscv-sifive-unmatched-define-PWM-LEDs.patch"
              # "0005-SiFive-HiFive-Unleashed-Add-PWM-LEDs-D1-D2-D3-D4.patch"
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
            services.getty.autologinUser = "root";
            services.xserver.desktopManager.gnome.enable = true;
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
              firefox
            ];
            networking.wireless.iwd.enable = true;
            hardware.firmware = with pkgs; [ firmwareLinuxNonfree ];
            hardware.opengl.enable = true;
            programs.sway.enable = true;
            users = {
              mutableUsers = false;
              users = {
                root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLQwaWXeJipSuAB+lV202yJOtAgJSNzuldH7JAf2jji" ];
              };
            };
          })
        ];
      };
    };
  };
}
