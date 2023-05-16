{ stdenv
, fetchFromGitHub
, python3
, nasm
, acpica-tools
, dtc
, buildPackages
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
    rev = "refs/tags/REL_VF2_APR2023";
    hash = "sha256-WXW+FxTAe+BeG94U9fKHwWfCh9wuxVkHxCXJEO5NtbE=";
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

  depsBuildBuild = [ buildPackages.stdenv.cc ];
  nativeBuildInputs = [ python3 nasm acpica-tools dtc ];

  env.PYTHON_COMMAND = "python3";
  env.GCC5_RISCV64_PREFIX = stdenv.cc.targetPrefix;
  env.NIX_CFLAGS_COMPILE = toString [ "-Wformat" ];

  buildPhase = ''
    runHook preBuild
    build --arch=RISCV64 --platform=${platforms}/Platform/StarFive/JH7110SeriesPkg/JH7110Board/JH7110.dsc --tagname=GCC5
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 Build/JH7110/DEBUG_GCC5/FV/JH7110.fd $out/JH7110.fd
    runHook postInstall
  '';
}
