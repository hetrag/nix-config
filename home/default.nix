{ pkgs, ... }:

{
  home.username = "mig";
  home.homeDirectory = "/home/mig";
  home.stateVersion = "24.05";

  programs.bash = {
    enable = true;
    initExtra = ''
      # Auth token from sops (silently skipped until secrets are set up)
      if [ -r /run/secrets/anthropic_auth_token ]; then
        export ANTHROPIC_AUTH_TOKEN="$(cat /run/secrets/anthropic_auth_token)"
      fi
    '';
  };

  # direnv — auto-loads dev shells per directory (see python/.envrc).
  # The bash hook ("eval $(direnv hook bash)") is added automatically
  # because programs.bash is enabled above; no manual initExtra needed.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true; # caches nix shells so `use nix` is instant after the first load
  };

  # Claude Code — shared settings on every machine.
  # The auth token deliberately lives in sops, NOT in this file.
  home.file.".claude/settings.json".source = ./claude/settings.json;

  # Drop more dotfiles here the same way, e.g.:
  # home.file.".claude/CLAUDE.md".source = ./claude/CLAUDE.md;
}
