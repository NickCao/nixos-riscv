{ lib
, fetchFromGitHub
, buildLinux
, ...
} @ args:

let
  modDirVersion = "5.15.0";
in
buildLinux (args // {
  inherit modDirVersion;
  version = "${modDirVersion}-vf2";

  src = fetchFromGitHub {
    owner = "starfive-tech";
    repo = "linux";
    rev = "162a9afb0b009393f4f21ee8c20d773131fd6b1e";
    sha256 = "sha256-zh1tonlqEY1KE2wHz1Rq8wGXZoC7Dw5U4sDYnQM3JUA=";
  };

  defconfig = "starfive_visionfive2_defconfig";

  extraMeta = {
    branch = "JH7110_VisionFive2_devel";
    maintainers = with lib.maintainers; [ nickcao ];
    description = "Linux kernel for StarFive's VisionFive2";
    platforms = [ "riscv64-linux" ];
    hydraPlatforms = [ ];
  };
} // (args.argsOverride or { }))
