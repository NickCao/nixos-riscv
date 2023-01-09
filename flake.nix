{
  inputs = {
    nixpkgs.url = "github:NickCao/nixpkgs/riscv";
    u-boot-starfive = {
      flake = false;
      url = "github:NickCao/u-boot-starfive";
    };
    meta-sifive = {
      flake = false;
      url = "github:sifive/meta-sifive/master";
    };
    uboot-vf2-src = {
      flake = false;
      url = "github:starfive-tech/u-boot/JH7110_VisionFive2_devel";
    };
    starfive-tools = {
      flake = false;
      url = "github:NickCao/starfive-tools";
    };
  };
  outputs = { self, nixpkgs, u-boot-starfive, meta-sifive, uboot-vf2-src, starfive-tools }: {
    hydraJobs = with self.nixosConfigurations.unmatched; {
      unmatched = config.system.build.sdImage;
      visionfive = self.nixosConfigurations.visionfive.config.system.build.sdImage;
      inherit (pkgs)
        qemu opensbi
        uboot-vf2
        opensbi-vf2
        firmware-vf2
        uboot-visionfive
        bootrom-visionfive
        uboot-unmatched
        bootrom-unmatched
        uboot-unmatched-ram
        ;
    };
    overlay = final: prev: {
      inherit meta-sifive;
      uboot-vf2 = prev.buildUBoot {
        version = uboot-vf2-src.shortRev;
        src = uboot-vf2-src;
        defconfig = "starfive_visionfive2_defconfig";
        filesToInstall = [
          "u-boot.bin"
          "spl/u-boot-spl.bin"
          "arch/riscv/dts/starfive_visionfive2.dtb"
        ];
      };
      opensbi-vf2 = (prev.opensbi.override {
        withPayload = "${final.uboot-vf2}/u-boot.bin";
        withFDT = "${final.uboot-vf2}/starfive_visionfive2.dtb";
      }).overrideAttrs (attrs: {
        makeFlags = attrs.makeFlags ++ [ "FW_TEXT_START=0x40000000" ];
      });
      firmware-vf2 = final.stdenv.mkDerivation {
        name = "firmware-vf2";
        dontUnpack = true;
        nativeBuildInputs = [
          final.buildPackages.python3
          final.buildPackages.ubootTools
          final.buildPackages.dtc
        ];
        installPhase = ''
          runHook preInstall
          mkdir -p $out
          python3 ${starfive-tools}/spl_tool/create_sbl ${final.uboot-vf2}/u-boot-spl.bin $out/u-boot-spl.bin.normal.out
          substitute ${starfive-tools}/uboot_its/visionfive2-uboot-fit-image.its visionfive2-uboot-fit-image.its \
            --replace fw_payload.bin ${final.opensbi-vf2}/share/opensbi/lp64/generic/firmware/fw_payload.bin
          mkimage -f visionfive2-uboot-fit-image.its -A riscv -O u-boot -T firmware $out/visionfive2_fw_payload.img
          runHook postInstall
        '';
      };
      uboot-visionfive = prev.buildUBoot {
        version = "e068256b4ea2d01562317cd47caab971815ba174";
        src = u-boot-starfive;
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
        patches = [ ./opensbi.patch ];
      })).override {
        withPayload = "${final.uboot-visionfive}/u-boot.bin";
        withFDT = "${final.uboot-visionfive}/u-boot.dtb";
      };
      bootrom-visionfive = prev.runCommand "bootrom-visionfive"
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
        mkdir -p "$out/nix-support"
        echo "file bin \"$out/bootrom.bin\"" >> "$out/nix-support/hydra-build-products"
        handle_file ${final.opensbi-visionfive}/share/opensbi/lp64/generic/firmware/fw_payload.bin $out/bootrom.bin
      '';
      uboot-unmatched = prev.buildUBoot {
        defconfig = "sifive_unmatched_defconfig";
        extraPatches = map (patch: "${final.meta-sifive}/recipes-bsp/u-boot/files/riscv64/${patch}") [
          "0002-board-sifive-spl-Initialized-the-PWM-setting-in-the-.patch"
          "0003-board-sifive-Set-LED-s-color-to-purple-in-the-U-boot.patch"
          "0004-board-sifive-Set-LED-s-color-to-blue-before-jumping-.patch"
          "0005-board-sifive-spl-Set-remote-thermal-of-TMP451-to-85-.patch"
          "0008-riscv-dts-Add-few-PMU-events.patch"
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
      uboot-unmatched-ram = final.uboot-unmatched.overrideAttrs (attrs: { patches = attrs.patches ++ [ ./0001-board-sifive-spl-boot-from-ram.patch ]; });
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
      qemu = nixpkgs.lib.nixosSystem {
        modules = [
          {
            imports = [
            ];
            nixpkgs = {
              localSystem.config = "x86_64-unknown-linux-gnu";
              crossSystem.config = "riscv64-unknown-linux-gnu";
            };
          }
          ./qemu.nix
        ];
      };
      unmatched = nixpkgs.lib.nixosSystem {
        modules = [
          ({ config, pkgs, lib, modulesPath, ... }: {
            imports = [
              "${modulesPath}/profiles/base.nix"
              "${modulesPath}/installer/sd-card/sd-image.nix"
            ];
            nixpkgs = {
              localSystem.config = "x86_64-unknown-linux-gnu";
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
        modules = [
          ({ config, pkgs, lib, modulesPath, ... }: {
            imports = [
              "${modulesPath}/profiles/base.nix"
              "${modulesPath}/installer/sd-card/sd-image.nix"
            ];
            nixpkgs = {
              localSystem.config = "x86_64-unknown-linux-gnu";
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
