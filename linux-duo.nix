{ runCommand
, linuxPackages_testing
, linuxManualConfig
, linuxConfig
, writeText
}:
let
  base = linuxPackages_testing.kernel;
  tinyconfig = linuxConfig {
    inherit (base) version src;
    makeTarget = "tinyconfig";
  };
  extraconfig = writeText "extraconfig" ''
    CONFIG_ARCH_SOPHGO=y
  '';
  configfile = runCommand "config" { } ''
    cat ${tinyconfig} ${extraconfig} > "$out"
  '';
in
linuxManualConfig {
  inherit (base) version src;
  inherit configfile;
  allowImportFromDerivation = true;
}
