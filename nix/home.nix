{ config, pkgs, user, ... }:
{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    zsh
    ripgrep
    fd
    bat
    eza
    starship
    zoxide
    jq
    fzf
    dust
    procs
    bottom
    lazygit
    git-delta
  ];

  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";

    sessionVariables = {
      EDITOR = "vi";
      VISUAL = "$EDITOR";
      BAT_THEME = "Catppuccin-macchiato";
      HOMEBREW_NO_ANALYTICS = "1";
      RANGER_LOAD_DEFAULT_RC = "FALSE";
      PNPM_HOME = "$HOME/Library/pnpm";
      LESSKEYIN = "$HOME/.config/less/.lesskey";
      LESSHISTFILE = "$HOME/.config/less/.lesshst";
      SHELL = "${pkgs.zsh}/bin/zsh";
    };

    initExtraFirst = ''
      # Load local secrets before anything else.
      [[ -f "$ZDOTDIR/.secret" ]] && source "$ZDOTDIR/.secret"
    '';

    initExtra = ''
      # Preserve existing modular init ordering from rc.d/.
      if [[ -d "$ZDOTDIR/rc.d" ]]; then
        for conf in "$ZDOTDIR/rc.d/"*.zsh(N); do
          source "$conf"
        done
        unset conf
      fi
    '';
  };
}
