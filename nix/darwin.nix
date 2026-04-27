{ pkgs, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    chezmoi
  ];

  system.stateVersion = 5;
}
