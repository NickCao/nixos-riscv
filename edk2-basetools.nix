{ stdenv
, version
, src
, libuuid
}:

stdenv.mkDerivation {
  pname = "BaseTools";
  inherit version src;

  strictDeps = true;
  buildInputs = [ libuuid ];

  makeFlags = [ "-C" "BaseTools/Source/C" ];

  enableParallelBuilding = true;

  installPhase = ''
    runHook preBuild
    install -Dm555 BaseTools/Source/C/bin/* -t $out/bin
    runHook postBuild
  '';
}
