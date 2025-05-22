# duo.nix
self: super: {
  blink-blue-led = import ./blink_blue_led.nix { pkgs = super; };
  duo-pinmux = import ./duo-pinmux.nix {
    pkgs = super;
  };
  spidev-test = import ./spi-test.nix {
    pkgs = super;
  };
}
