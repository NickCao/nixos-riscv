{
  inputs = {
    nixpkgs.url = "github:NickCao/nixpkgs/riscv";
  };
  outputs = { self, nixpkgs }: {
    hydraJobs = with self.nixosConfigurations.unmatched; {
      unmatched = config.system.build.toplevel;
      inherit (pkgs) qemu opensbi uboot-visionfive bootrom-visionfive uboot-unmatched bootrom-unmatched uboot-unmatched-ram;
    };
    overlay = final: prev: rec {
      xdg-utils = prev.coreutils;
      meta-sifive = prev.fetchFromGitHub {
        owner = "sifive";
        repo = "meta-sifive";
        rev = "2022.03.00";
        sha256 = "sha256-Z/BZ5p3lb2K6p4zOsmJQjUcs4EpaONAscsjGgQkUe54=";
      };
      uboot-visionfive = prev.buildUBoot rec {
        version = "d5f53001d7324c9680ab39c8a4c87ac03a4162b8";
        src = prev.fetchFromGitHub {
          owner = "NickCao";
          repo = "u-boot-starfive";
          rev = version;
          sha256 = "sha256-eAu8IW83X57+xG0yzl1+/OBWuYV2NT32N4r0elQ+/rQ=";
        };
        defconfig = "starfive_jh7100_visionfive_smode_defconfig";
        filesToInstall = [ "u-boot.bin" "u-boot.dtb" ];
      };
      opensbi-visionfive = (prev.opensbi.overrideAttrs (_: {
        src = prev.fetchFromGitHub {
          owner = "riscv-software-src";
          repo = "opensbi";
          rev = "474a9d45551ab8c7df511a6620de2427a732351f";
          sha256 = "sha256-kc6Z3pGSxq7/0NeGuBSidSNr/3LOCR4InaQYfUOwUUg=";
        };
      })).override {
        withPayload = "${final.uboot-visionfive}/u-boot.bin";
        withFDT = "${final.uboot-visionfive}/u-boot.dtb";
      };
      bootrom-visionfive = prev.runCommand "bootrom-visionfive.bin"
        {
          nativeBuildInputs = with prev.buildPackages; [ xxd ];
        } ''
        function handle_file {
          inFile=$1
          echo inFile: $inFile
          outFile=$2

          inSize=`stat -c "%s" $inFile`
          inSize32HexBe=`printf "%08x\n" $inSize`
          inSize32HexLe=''${inSize32HexBe:6:2}''${inSize32HexBe:4:2}''${inSize32HexBe:2:2}''${inSize32HexBe:0:2}
          echo "inSize: $inSize (0x$inSize32HexBe, LE:0x$inSize32HexLe)"

          echo $inSize32HexLe | xxd -r -ps > $outFile
          cat $inFile >> $outFile
          echo outFile: $outFile

          outSize=`stat -c "%s" $outFile`
          outSize32HexBe=`printf "%08x\n" $outSize`
          echo "outSize: $outSize (0x$outSize32HexBe)"
        }
        handle_file ${final.opensbi-visionfive}/share/opensbi/lp64/generic/firmware/fw_payload.bin $out
      '';
      uboot-unmatched = prev.buildUBoot rec {
        version = "2022.04-rc5";
        src = prev.fetchFromGitHub {
          owner = "u-boot";
          repo = "u-boot";
          rev = "v${version}";
          sha256 = "sha256-PWcmb57pfSVGVDiEgYvLi+SvCgNOj2WnCeiP7M0sosk=";
        };
        defconfig = "sifive_unmatched_defconfig";
        extraPatches = map (patch: "${final.meta-sifive}/recipes-bsp/u-boot/files/riscv64/${patch}") [
          "0001-riscv-sifive-unleashed-support-compressed-images.patch"
          "0002-board-sifive-spl-Initialized-the-PWM-setting-in-the-.patch"
          "0003-board-sifive-Set-LED-s-color-to-purple-in-the-U-boot.patch"
          # "0004-board-sifive-Set-LED-s-color-to-blue-before-jumping-.patch"
          "0005-board-sifive-spl-Set-remote-thermal-of-TMP451-to-85-.patch"
          "0006-riscv-sifive-unmatched-leave-128MiB-for-ramdisk.patch"
          "0007-riscv-sifive-unmatched-disable-FDT-and-initrd-reloca.patch"
          # "0008-pci-Work-around-PCIe-link-training-failures.patch"
        ];
        extraMakeFlags = [
          "OPENSBI=${final.opensbi}/share/opensbi/lp64/generic/firmware/fw_dynamic.bin"
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
              overlays = [ self.overlay ];
            };

          })
          ./unmatched.nix
        ];
      };
      visionfive = nixpkgs.lib.nixosSystem {
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
            };
          })
          ./visionfive.nix
        ];
      };
    };
  };
}
