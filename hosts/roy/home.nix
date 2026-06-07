# Roy-specific Home Manager configuration
{ config, pkgs, inputs, ... }:

{
  imports = [
    ../../home  # Import shared home-manager config from home/default.nix
  ];

  programs.zsh.shellAliases = {
    update = "sudo nixos-rebuild switch --flake .#roy";
  };

  programs.zsh.initContent= ''
  export OBAN_VIDEO_PROCESSING_CONCURRENCY="1"
  export OBAN_QUEUES="video_processing"
  export R2_PUBLIC_BASE_URL="https://videos.ossbjj.org"
  export IN_ACTION_VIDEO_STORAGE="r2"
  export IN_ACTION_VIDEO_TMP_DIR="/tmp/fos-bjj-in-action"
  export R2_ACCOUNT_ID="$(<"${config.sops.secrets.r2_account_id.path}")"
  export R2_BUCKET="$(<"${config.sops.secrets.ossbjj-clips.path}")"
  export R2_ACCESS_KEY_ID="$(<"${config.sops.secrets.r2_access_key_id.path}")"
  export R2_SECRET_ACCESS_KEY="$(<"${config.sops.secrets.r2_secret_access_key.path}")"
  export SECRET_KEY_BASE="$(<"${config.sops.secrets.ossbjj-secret-key-base.path}")"
  export TOKEN_SIGNING_SECRET="$(<"${config.sops.secrets.ossbjj-token-signing-secret.path}")"
  export DATABASE_URL="$(<"${config.sops.secrets.ossbjj-database-url.path}")"
  ''
}
