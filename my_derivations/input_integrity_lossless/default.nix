{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, zlib
, gzip
, icu
, fontconfig
, xorg
, libGL
, libglvnd
, libusb1
, openssl
}:

stdenv.mkDerivation rec {
  pname = "input-integrity-manager";
  version = "2.0";

  src = fetchurl {
    url = "https://dnlo0r667tlsj.cloudfront.net/LosslessAdapterManager2_Linux.gz";
    hash = "sha256-BHfz28rIJTkTPOA0320Myb/tdQArtrExFoDv37j2y5E=";
  };

  # The source is a gzipped binary, not a tarball
  unpackPhase = ''
    runHook preUnpack

    # Extract the gzipped binary to the current directory
    gunzip -c $src > LosslessAdapterManager2_Linux
    chmod +x LosslessAdapterManager2_Linux

    runHook postUnpack
  '';

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    gzip
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    zlib
    icu
    fontconfig
    xorg.libX11
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    xorg.libSM
    xorg.libICE
    libGL
    libglvnd
    libusb1
    openssl
  ];

  # Don't strip the binary - it contains bundled application data
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp LosslessAdapterManager2_Linux $out/bin/.input-integrity-manager-unwrapped

    # Wrap the binary to set library paths for .NET runtime and Avalonia UI
    makeWrapper $out/bin/.input-integrity-manager-unwrapped $out/bin/input-integrity-manager \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ icu fontconfig xorg.libX11 xorg.libXcursor xorg.libXrandr xorg.libXi xorg.libSM xorg.libICE libGL libglvnd libusb1 openssl ]}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Input Integrity Manager - Software to manage GameCube controller adapters";
    homepage = "https://www.input-integrity.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
