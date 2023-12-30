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
    CONFIG_SERIAL_8250=y
    CONFIG_SERIAL_8250_CONSOLE=y
    CONFIG_SERIAL_8250_NR_UARTS=5
    CONFIG_SERIAL_8250_RUNTIME_UARTS=5
    CONFIG_SERIAL_8250_DW=y
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
