{
  description = "Declarative agent skills catalog (powered by agent-skills-nix)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    agent-skills.url = "github:Kyure-A/agent-skills-nix";
    agent-skills.inputs.nixpkgs.follows = "nixpkgs";

    # Upstream skill catalogs. Keep these pinned in flake.lock and review
    # SKILL.md diffs before updating.
    openai-skills = {
      url = "github:openai/skills";
      flake = false;
    };
    vercel-skills = {
      url = "github:vercel-labs/skills";
      flake = false;
    };
    matt-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };
    frad-dotclaude = {
      url = "github:FradSer/dotclaude";
      flake = false;
    };
    ast-grep-skill = {
      url = "github:ast-grep/agent-skill";
      flake = false;
    };
    mgrep-skill = {
      url = "github:mixedbread-ai/mgrep";
      flake = false;
    };
    remotion-skills = {
      url = "github:remotion-dev/skills";
      flake = false;
    };
    notebooklm-py = {
      url = "github:teng-lin/notebooklm-py";
      flake = false;
    };
    every-compound = {
      url = "github:EveryInc/compound-engineering-plugin";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, agent-skills, ... }@inputs:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems
        (system: f { pkgs = nixpkgs.legacyPackages.${system}; inherit system; });

      catalogConfig = import ./skills.nix { inherit inputs; };
      ask = agent-skills.lib.agent-skills;

      selectionFor = pkgs:
        let
          catalog = ask.discoverCatalog catalogConfig.sources;
          allowlist = ask.allowlistFor {
            inherit catalog;
            sources = catalogConfig.sources;
            enableAll = catalogConfig.skills.enableAll or false;
            enable = catalogConfig.skills.enable or [];
          };
        in ask.selectSkills {
          inherit catalog allowlist;
          skills = catalogConfig.skills.explicit or {};
          sources = catalogConfig.sources;
        };

      bundleFor = pkgs: ask.mkBundle {
        inherit pkgs;
        selection = selectionFor pkgs;
      };

      excludePatterns = catalogConfig.excludePatterns or ask.defaultExcludePatterns;
    in
    {
      # Home Manager module: import from a user HM config with:
      #   inputs.dotfiles-skills.homeManagerModules.default
      homeManagerModules.default = { ... }: {
        imports = [ agent-skills.homeManagerModules.default ];
        config.programs.agent-skills = { enable = true; } // catalogConfig;
      };

      homeManagerModules.agent-skills = agent-skills.homeManagerModules.default;
      lib = { inherit catalogConfig; };

      packages = forAllSystems ({ pkgs, system }: {
        bundle = bundleFor pkgs;
        default = self.packages.${system}.bundle;
      });

      checks = forAllSystems ({ pkgs, system }: {
        skills = self.packages.${system}.bundle;
      });

      apps = forAllSystems ({ pkgs, system }:
        let
          catalog = ask.discoverCatalog catalogConfig.sources;
          jsonDrv = pkgs.writeText "skills-catalog.json" (builtins.toJSON (ask.catalogJson catalog));
          bundle = self.packages.${system}.bundle;
          installScript = pkgs.writeShellApplication {
            name = "skills-install";
            runtimeInputs = [ pkgs.rsync pkgs.coreutils ];
            text = ask.mkSyncScript {
              inherit pkgs bundle excludePatterns;
              targets = catalogConfig.targets;
              system = system;
              allowOverrides = true;
            };
          };
          listScript = pkgs.writeShellApplication {
            name = "skills-list";
            runtimeInputs = [ pkgs.jq pkgs.coreutils ];
            text = ''
              exec jq . ${jsonDrv}
            '';
          };
        in {
          skills-install = {
            type = "app";
            program = "${installScript}/bin/skills-install";
          };
          skills-list = {
            type = "app";
            program = "${listScript}/bin/skills-list";
          };
          default = self.apps.${system}.skills-install;
        });
    };
}
