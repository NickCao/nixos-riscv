{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "duo-pinmux";
  version = "1.0.0";

  src = pkgs.fetchFromGitHub {
    owner = "milkv-duo";
    repo = "duo-pinmux";
    rev = "${version}";
    sha256 = "sha256-GLI76QdvH7y8Oca2PO+A8UocsSsI08k/RIbSVWsH7dY=";
  };

  nativeBuildInputs = [ ];

  buildPhase = ''
    cd duos
    riscv64-unknown-linux-gnu-gcc -march=rv64imafdcv0p7 -mabi=lp64d duo_pinmux.c devmem.c -o duo-pinmux
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp duo-pinmux $out/bin/
  '';

  meta = with pkgs.lib; {
    description = "Pin Multiplexing utility for Milk-V Duo, Duo256M, and DuoS";
    homepage = "https://github.com/milkv-duo/duo-pinmux";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
