{ stdenv
, fetchFromGitHub
, python3
, dtc
, buildPackages
, buildTarget ? "RELEASE"
}:
let
  version = "202304";
  src = fetchFromGitHub {
    owner = "starfive-tech";
    repo = "edk2";
    rev = "refs/tags/REL_VF2_APR2023";
    hash = "sha256-3fiD1M1AkGVpDfBY1D3dOES3ROriq9AF5f5OiqfO2bY=";
    fetchSubmodules = true;
  };

  platforms = fetchFromGitHub {
    owner = "starfive-tech";
    repo = "edk2-platforms";
    rev = "99f10149bf54c68890eb97aaab88a94e2bf734c6";
    hash = "sha256-3xb8P/kMLpuk3h7HG4/DPNmbHz6z+JX/jvLT4KWUhJk=";
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
