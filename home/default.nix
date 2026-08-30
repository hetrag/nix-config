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

  # Claude Code — shared settings on every machine.
  # The auth token deliberately lives in sops, NOT in this file.
  home.file.".claude/settings.json".source = ./claude/settings.json;

  # Drop more dotfiles here the same way, e.g.:
  # home.file.".claude/CLAUDE.md".source = ./claude/CLAUDE.md;
}
