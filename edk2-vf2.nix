{ stdenv
, fetchFromGitHub
, python3
, dtc
, buildPackages
, buildTarget ? "RELEASE"
}:
let
  version = "202306";
  src = fetchFromGitHub {
    owner = "starfive-tech";
    repo = "edk2";
    rev = "refs/tags/REL_VF2_JUN2023";
    hash = "sha256-RVky5Sfm2Dj12YrLsTleuoYxl4gv5n9MjchWDC9Mp+8=";
    fetchSubmodules = true;
  };

  platforms = fetchFromGitHub {
    owner = "starfive-tech";
    repo = "edk2-platforms";
    rev = "ef35a2a2450275b9208f5c9ad5b60a405e33e45a";
    hash = "sha256-o+vtzaAWSQRJVjGEktJKj0NSmoGE2IeQNrlnwf6EsB4=";
    fetchSubmodules = true;
  };

  basetools = buildPackages.callPackage ./edk2-basetools.nix { inherit version src; };
in
stdenv.mkDerivation {
  pname = "edk2";
  inherit version src;

  postPatch = ''
    patchShebangs BaseTools/BinWrappers
    ln -sv ${basetools}/bin BaseTools/Source/C/bin
  '';

  preConfigure = ''
    export PACKAGES_PATH=.:${platforms}
    source edksetup.sh BaseTools
  '';

  depsBuildBuild = [ buildPackages.stdenv.cc ]; # for cpp
  nativeBuildInputs = [ python3 dtc ];

  env = {
    PYTHON_COMMAND = "python3";
    GCC5_RISCV64_PREFIX = stdenv.cc.targetPrefix;
  };

  buildPhase = ''
    runHook preBuild
    build --arch=RISCV64 --platform=${platforms}/Platform/StarFive/JH7110SeriesPkg/JH7110Board/JH7110.dsc --tagname=GCC5 --buildtarget=${buildTarget}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 Build/JH7110/${buildTarget}_GCC5/FV/JH7110.fd $out/JH7110.fd
    runHook postInstall
  '';
}
