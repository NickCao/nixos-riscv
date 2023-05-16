{
  inputs = {
    nixpkgs.url = "github:NickCao/nixpkgs/riscv";
    meta-sifive = {
      flake = false;
      url = "github:sifive/meta-sifive/master";
    };
    starfive-tools = {
      flake = false;
      url = "github:NickCao/starfive-tools";
    };
  };
  outputs = { self, nixpkgs, meta-sifive, starfive-tools }: {
    hydraJobs = with self.nixosConfigurations.unmatched; {
      unmatched = config.system.build.sdImage;
      visionfive2 = self.nixosConfigurations.visionfive2.config.system.build.sdImage;
      inherit (pkgs)
        qemu opensbi
        uboot-vf2
        firmware-vf2
        linux-vf2
        uboot-unmatched
        bootrom-unmatched
        ;
    };
    overlay = final: prev: {
      inherit meta-sifive;
      uboot-vf2 = (final.buildUBoot rec {
        version = "2023.07-rc2";

        src = final.fetchurl {
          url = "ftp://ftp.denx.de/pub/u-boot/u-boot-${version}.tar.bz2";
          hash = "sha256-GE1zRpmAPOdBQX6Q9vuf4hjxzk/OR53CZqNNhp5t+Ms=";
        };

        defconfig = "starfive_visionfive2_defconfig";

        filesToInstall = [
          "u-boot.itb"
          "spl/u-boot-spl.bin"
        ];

        extraMakeFlags = [
          "OPENSBI=${final.opensbi}/share/opensbi/lp64/generic/firmware/fw_dynamic.bin"
        ];
      }).overrideAttrs (_: { patches = [ ]; });
      firmware-vf2 = final.stdenv.mkDerivation {
        name = "firmware-vf2";
        dontUnpack = true;
        nativeBuildInputs = [
          final.buildPackages.python3
        ];
        installPhase = ''
          runHook preInstall

          mkdir -p $out
          python3 ${starfive-tools}/spl_tool/create_sbl ${final.uboot-vf2}/u-boot-spl.bin $out/u-boot-spl.bin.normal.out
          install -Dm444 ${final.uboot-vf2}/u-boot.itb $out/u-boot.itb

          mkdir -p "$out/nix-support"
          echo "file bin \"$out/u-boot-spl.bin.normal.out\"" >> "$out/nix-support/hydra-build-products"
          echo "file bin \"$out/u-boot.itb\"" >> "$out/nix-support/hydra-build-products"

          runHook postInstall
        '';
      };
      linux-vf2 = final.callPackage ./linux-vf2.nix { };
      uboot-unmatched = (prev.buildUBoot rec {
        version = "2023.04";

        src = final.fetchurl {
          url = "ftp://ftp.denx.de/pub/u-boot/u-boot-${version}.tar.bz2";
          hash = "sha256-4xyskVRf9BtxzsXYwir9aVZFzW4qRCzNrKzWBTQGk0E=";
        };

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

        filesToInstall = [ "u-boot.itb" "spl/u-boot-spl.bin" ];
      }).overrideAttrs (_: { patches = [ ]; });
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
      qemu = nixpkgs.lib.nixosSystem { modules = [ ./common.nix ./qemu.nix ]; };
      unmatched = nixpkgs.lib.nixosSystem { modules = [ ./common.nix ./unmatched.nix ({ nixpkgs.overlays = [ self.overlay ]; }) ]; };
      visionfive2 = nixpkgs.lib.nixosSystem { modules = [ ./common.nix ./visionfive2.nix ({ nixpkgs.overlays = [ self.overlay ]; }) ]; };
    };
  };
}
