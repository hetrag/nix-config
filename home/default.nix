{ pkgs, ... }:

{
  home.username = "mig";
  home.homeDirectory = "/home/mig";
  home.stateVersion = "24.05";

  programs.bash = {
    enable = true;
    initExtra = ''
      # Prompt: NixOS green default, with "(.venv)" prefix when a virtualenv
      # is active. direnv drops the PS1 change that `activate` makes (it only
      # propagates exported vars), but VIRTUAL_ENV *is* exported — so read it
      # here. Single-quoted PS1 => bash re-expands it at every prompt render.
      PS1='\n''${VIRTUAL_ENV:+(''${VIRTUAL_ENV##*/}) }\[\033[1;32m\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$\[\033[0m\] '

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
