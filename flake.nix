{
  inputs = {
    nixpkgs.url = "github:NickCao/nixpkgs/riscv";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };
  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
    }:
    {
      hydraJobs = with self.nixosConfigurations.qemu; {
        visionfive2 = self.nixosConfigurations.visionfive2.config.system.build.sdImage;
        duo = self.nixosConfigurations.duo.config.system.build.sdImage;
        duo-256 = self.nixosConfigurations.duo-256.config.system.build.sdImage;
        duos = self.nixosConfigurations.duos.config.system.build.sdImage;
        inherit (pkgs)
          qemu
          opensbi
          firefox-unwrapped
          firefox-esr-unwrapped
          postgresql_13
          postgresql_14
          postgresql_15
          postgresql_16
          postgresql_17
          nodejs_18
          nodejs_20
          nodejs_22
          ;
        thunderbird = pkgs.thunderbird.unwrapped;
        thunderbird-128 = pkgs.thunderbird-128.unwrapped;
        qt5 = {
          inherit (pkgs.qt5) qtbase;
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
        duo = nixpkgs.lib.nixosSystem { modules = [ ./duo.nix ]; };
        duo-256 = nixpkgs.lib.nixosSystem { modules = [ ./duo-256.nix ]; };
        duos = nixpkgs.lib.nixosSystem { modules = [ ./duos.nix ]; };
        visionfive2 = nixpkgs.lib.nixosSystem {
          modules = [
            ./common.nix
            "${nixos-hardware}/starfive/visionfive/v2/sd-image-installer.nix"
          ];
        };
      };
    };
}
