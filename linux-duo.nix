{ lib
, linuxPackages_testing
}:

linuxPackages_testing.kernel.override (args: {
  kernelPatches = (args.kernelPatches or [ ]) ++ [{
    name = "milkv-duo";
    patch = null;
    extraStructuredConfig = with lib.kernel; {
      ARCH_SOPHGO = yes;
    };
  }];
})
