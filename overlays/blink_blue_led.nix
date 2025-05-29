{ pkgs }:
pkgs.stdenv.mkDerivation {
  pname = "blink-blue-led";
  version = "1.0";
  src = ./blink_blue_led;

  buildInputs = [
  ];

  # Build Phases
  configurePhase = '''';
  buildPhase = '''';
  installPhase = ''
    mkdir -p "$out/bin"
    cp ./blink.sh "$out/bin/blink-blue-led"
    chmod 777 $out/bin/blink-blue-led
    patchShebangs --build $out/bin
  '';
  meta = with pkgs.lib; {
    description = "The blink script of the official buildroot repo";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
