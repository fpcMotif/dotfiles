{
  description = "macOS dotfiles via nix-darwin + Home Manager, with chezmoi for customization";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, ... }:
    let
      system = "aarch64-darwin";
      user = "f";
      hostname = "mbp";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
        inherit system;
        modules = [
          ./nix/darwin.nix
          home-manager.darwinModules.home-manager
          {
            networking.hostName = hostname;

            users.users.${user} = {
              name = user;
              home = "/Users/${user}";
            };

            system.primaryUser = user;

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit user hostname; };
            home-manager.users.${user} = import ./nix/home.nix;
          }
        ];
      };

      homeConfigurations.${user} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit user hostname; };
        modules = [
          ./nix/home.nix
          {
            home.username = user;
            home.homeDirectory = "/Users/${user}";
          }
        ];
      };
    };
}
