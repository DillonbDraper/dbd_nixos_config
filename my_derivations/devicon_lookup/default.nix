{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "devicon-lookup";
  version = "0.10.2";

  src = fetchFromGitHub {
    owner = "coreyja";
    repo = "devicon-lookup";
    rev = "v${version}";
    hash = "sha256-mDjRbBX3B1pfGX9SkrQLFXpgpq3Kay+crFXT1Bmfadk=";
  };

  cargoHash = "sha256-aewaNaeJLxRqm6p9K/GzHhJY3/b5z7N4Z8F7KjVxzcQ=";

  meta = with lib; {
    description = "Prepend the correct devicon to each filename";
    homepage = "https://github.com/coreyja/devicon-lookup";
    license = licenses.mit;
    mainProgram = "devicon-lookup";
    platforms = platforms.unix;
  };
}
