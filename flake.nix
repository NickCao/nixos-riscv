{
  inputs = {
    nixpkgs.url = "github:NickCao/nixpkgs/riscv";
    nixos-hardware.url = "github:NickCao/nixos-hardware";
  };
  outputs = { self, nixpkgs, nixos-hardware }: {
    hydraJobs = with self.nixosConfigurations.qemu;{
      visionfive2 = self.nixosConfigurations.visionfive2.config.system.build.sdImage;
      duo = self.nixosConfigurations.duo.config.system.build.sdImage;
      duo-256 = self.nixosConfigurations.duo-256.config.system.build.sdImage;
      inherit (pkgs)
        qemu
        opensbi
        firefox-unwrapped
        thunderbird-unwrapped
        ;
      qt5 = {
        inherit (pkgs.qt5)
          qtbase
          ;
      };
      edk2-vf2 = pkgs.pkgsCross.riscv64-embedded.callPackage ./edk2-vf2.nix { };
    };
    nixosConfigurations = {
      qemu = nixpkgs.lib.nixosSystem {
        modules = [
          ./common.nix
          ./qemu.nix
        ];
      };
      duo = nixpkgs.lib.nixosSystem {
        modules = [
          ./duo.nix
        ];
      };
      duo-256 = nixpkgs.lib.nixosSystem {
        modules = [
          ./duo-256.nix
        ];
      };
      visionfive2 = nixpkgs.lib.nixosSystem {
        modules = [
          "${nixos-hardware}/starfive/visionfive/v2/sd-image-installer.nix"
          ./visionfive2.nix
        ];
      };
    };
  };
}
