{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage (finalAttrs: {
  pname = "cursor-agent-acp-npm";
  version = "0.5.2";

  src = fetchFromGitHub {
    owner = "blowmage";
    repo = "cursor-agent-acp-npm";
    tag = "v${finalAttrs.version}";
    hash = "sha256-VtrLud3YvWxNkxaQbffpnvYHoZ0iOXnlikOz6e8Yguw=";
  };

  npmDepsHash = "sha256-krfdClqYtyPqcXdmJw/BG6LNArlFlWOLHyRBFVL2x8E=";

  NODE_OPTIONS = "--openssl-legacy-provider";

  meta = {
    description = "ACP compliant bridge for the cursor-cli client";
    homepage = "https://github.com/blowmage/cursor-agent-acp-npm";
    license = lib.licenses.mit;
  };
})
