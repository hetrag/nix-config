# PLACEHOLDER — the real file is generated on the server at install time:
#
#   sudo nixos-generate-config --root /mnt
#
# then commit /mnt/etc/nixos/hardware-configuration.nix here. Keep the
# /mnt/raid and /mnt/ssd entries from hosts/server/default.nix (they are the
# data disks), and let the generated file provide /, /boot and swap.
#
# If the /raid array is mdadm or zfs (not plain ext4 on one device), the
# generated file will bring the extra boot/services config needed — make sure
# it ends up here too.
{ ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/" = {
    device = "/dev/disk/by-id/REPLACE-ME-system-ssd";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-id/REPLACE-ME-system-ssd-part1";
    fsType = "vfat";
  };
}
