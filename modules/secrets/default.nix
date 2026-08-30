{ config, ... }:

{
  # Encrypted secrets live here; each machine decrypts with its own
  # /etc/ssh/ssh_host_ed25519_key (sops-nix default via age conversion).
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";

  sops.secrets.anthropic_auth_token = {
    owner = config.users.users.mig.name;
    group = "users";
  };

  sops.secrets.ssh_key = {
    owner = config.users.users.mig.name;
    group = "users";
    mode = "0600";
  };

  # Deploy the shared user SSH key: symlink ~/.ssh/id_ed25519 to the
  # decrypted secret, so all machines share one identity.
  systemd.tmpfiles.rules = [
    "d /home/mig/.ssh 0700 mig users -"
    "L+ /home/mig/.ssh/id_ed25519 - - - - ${config.sops.secrets.ssh_key.path}"
  ];
}
