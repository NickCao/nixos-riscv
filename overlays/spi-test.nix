{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "spi-test";
  version = "1.0.0";

  src = pkgs.fetchFromGitHub {
    owner = "rm-hull";
    repo = "spidev-test";
    rev = "453596c9541f01705d786a40802d068238eae215";
    sha256 = "sha256-4XieRFlqNmnlkJjq7qiKRLOEDwAzKlQkYqsGFnjagYQ=";
  };

  nativeBuildInputs = [ ];

  buildPhase = ''
    riscv64-unknown-linux-gnu-gcc -march=rv64imafdcv0p7 -mabi=lp64d spidev_test.c -o spidev_test
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp spidev_test $out/bin/
  '';

  meta = with pkgs.lib; {
    description = "Linux kernel utility to test a spi bus by connecting MISO with MOSI";
    homepage = "https://github.com/rm-hull/spidev-test";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
