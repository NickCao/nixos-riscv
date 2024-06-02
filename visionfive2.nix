{ pkgs, ... }: {

  nixpkgs = {
    localSystem.config = "x86_64-unknown-linux-gnu";
    crossSystem.config = "riscv64-unknown-linux-gnu";
  };

  programs.less.lessopen = null;

  services.openssh.enable = true;

  environment.systemPackages = with pkgs;[ neofetch iperf3 ];

  nixpkgs.flake = {
    setNixPath = false;
    setFlakeRegistry = false;
  };

  system.installer.channel.enable = false;

}
