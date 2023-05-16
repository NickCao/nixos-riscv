{
  inputs = {
    nixpkgs.url = "github:NickCao/nixpkgs/riscv";
    nixos-hardware.url = "github:NickCao/nixos-hardware/visionfive2";
    meta-sifive = {
      flake = false;
      url = "github:sifive/meta-sifive/master";
    };
  };
  outputs = { self, nixpkgs, nixos-hardware, meta-sifive }: {
    hydraJobs = with self.nixosConfigurations.unmatched;
      let vf2 = pkgs.callPackage "${nixos-hardware}/starfive/visionfive/v2/firmware.nix" { }; in {
        unmatched = config.system.build.sdImage;
        visionfive2 = self.nixosConfigurations.visionfive2.config.system.build.sdImage;
        inherit (pkgs)
          qemu opensbi
          uboot-unmatched
          bootrom-unmatched
          ;
        spl-vf2 = vf2.spl;
        uboot-fit-image-vf2 = vf2.uboot-fit-image;
        edk2-vf2 = pkgs.pkgsCross.riscv64-embedded.callPackage ./edk2-vf2.nix { };
      };
    overlay = final: prev: {
      inherit meta-sifive;
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
      visionfive2 = nixpkgs.lib.nixosSystem {
        modules = [
          "${nixos-hardware}/starfive/visionfive/v2/sd-image-installer.nix"
          ./visionfive2.nix
          ({ nixpkgs.overlays = [ self.overlay ]; })
        ];
      };
    };
  };
}
