{ lib
, stdenv
, autoPatchelfHook
, dpkg
, makeWrapper
, xdg-utils
, zlib
}:

stdenv.mkDerivation rec {
  pname = "dreamcoder";
  version = "1.0.16";

  src = ../../dreamcoder-dreamcoder_1.0.16_amd64.deb;

  nativeBuildInputs = [ autoPatchelfHook dpkg makeWrapper ];
  buildInputs = [ stdenv.cc.cc.lib zlib ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  # Preserve the compiled Python application's bundled data and libraries.
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib" "$out/bin"
    cp -a usr/lib/dreamcoder "$out/lib/"
    cp -a usr/share "$out/share"

    # The Debian launcher is an absolute symlink into /usr/lib.
    makeWrapper "$out/lib/dreamcoder/dreamcoder/dreamcoder-server" "$out/bin/dreamcoder" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}
    substituteInPlace "$out/share/applications/ai.dreamcoder.dreamcoder.desktop" \
      --replace-fail /usr/lib/dreamcoder/dreamcoder/dreamcoder-server "$out/bin/dreamcoder"

    runHook postInstall
  '';

  meta = {
    description = "AI-powered coding assistant with semantic code search";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "dreamcoder";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
