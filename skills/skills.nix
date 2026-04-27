# Declarative agent skills catalog.
#
# This is the single source of truth for personal Agent Skills. Chezmoi does not
# apply ~/.agents/skills, ~/.claude/skills, or ~/.pi/agent/skills directly;
# the Nix installer materializes this catalog into those targets.
#
# DSL reference: https://github.com/Kyure-A/agent-skills-nix
{ inputs, ... }:
let
  replace = builtins.replaceStrings;

  # Helper for upstream skills whose directory name is the compatibility name
  # we want, but whose SKILL.md frontmatter uses a different name.
  renameSkill = old: new: { original, dependencies }:
    (replace [ "name: ${old}" "name: \"${old}\"" ] [ "name: ${new}" "name: \"${new}\"" ] original)
    + "\n"
    + dependencies;
in
{
  # ---------------------------------------------------------------------------
  # Sources: where SKILL.md directories are discovered.
  # ---------------------------------------------------------------------------
  sources = {
    # Local skills owned by this dotfiles repo. These replaced the old
    # dot_pi/agent/skills and dot_claude/skills checked-in directories.
    local = {
      path = ./local;
      subdir = ".";
      filter = {
        maxDepth = 1;
        nameRegex = "^[a-z][a-z0-9-]*$";
      };
    };

    # OpenAI curated skills used by the previous ~/.agents symlink stubs.
    openai = {
      path = inputs.openai-skills.outPath;
      subdir = "skills/.curated";
      filter = {
        maxDepth = 1;
        nameRegex = "^(doc|figma|gh-address-comments|gh-fix-ci|linear)$";
      };
    };

    vercel = {
      path = inputs.vercel-skills.outPath;
      subdir = "skills";
      filter = {
        maxDepth = 1;
        nameRegex = "^find-skills$";
      };
    };

    matt = {
      path = inputs.matt-skills.outPath;
      subdir = ".";
      filter = {
        maxDepth = 1;
        nameRegex = "^grill-me$";
      };
    };

    frad = {
      path = inputs.frad-dotclaude.outPath;
      subdir = "office/skills";
      filter = {
        maxDepth = 1;
        nameRegex = "^agent-browser$";
      };
    };

    astgrep = {
      path = inputs.ast-grep-skill.outPath;
      subdir = "ast-grep/skills";
      filter = {
        maxDepth = 1;
        nameRegex = "^ast-grep$";
      };
    };

    mgrep = {
      path = inputs.mgrep-skill.outPath;
      subdir = "plugins/mgrep/skills";
      filter = {
        maxDepth = 1;
        nameRegex = "^mgrep$";
      };
    };

    remotion = {
      path = inputs.remotion-skills.outPath;
      subdir = "skills";
      filter = {
        maxDepth = 1;
        nameRegex = "^remotion$";
      };
    };

    notebooklm = {
      path = inputs.notebooklm-py.outPath;
      subdir = ".";
      filter.maxDepth = 1;
    };

    every = {
      path = inputs.every-compound.outPath;
      subdir = "plugins/compound-engineering/skills";
      filter = {
        maxDepth = 1;
        nameRegex = "^ce-compound$";
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Skill selection: opt-in only. Nothing is auto-installed.
  # ---------------------------------------------------------------------------
  skills.enable = [
    # Local dotfiles skills.
    "crush"
    "git-workflow"
    "github-mcp"
    "lazygit"
    "manim-skill"
    "modern-bash"
    "oracle"
    "qmd"
    "ralph-loop"
    "review"
    "stitch-mcp"
    "web-browser"

    # Pinned upstream skills with matching public IDs.
    "agent-browser"
    "ast-grep"
    "doc"
    "figma"
    "find-skills"
    "gh-address-comments"
    "gh-fix-ci"
    "grill-me"
    "linear"
    "mgrep"
    "notebooklm"
  ];

  skills.enableAll = false;

  # Upstream skills whose stable compatibility name differs from their source
  # frontmatter/path are normalized here.
  skills.explicit = {
    every-team-compounding = {
      from = "every";
      path = "ce-compound";
      transform = { original, dependencies }:
        (replace
          [ "name: ce-compound" "# /ce-compound" ]
          [ "name: every-team-compounding" "# /every-team-compounding" ]
          original)
        + "\n"
        + dependencies;
    };

    remotion = {
      from = "remotion";
      path = "remotion";
      transform = renameSkill "remotion-best-practices" "remotion";
    };
  };

  # ---------------------------------------------------------------------------
  # Targets: where the bundle is materialized on disk.
  # ---------------------------------------------------------------------------
  targets = {
    # Canonical shared location used by several agents.
    agents = {
      enable = true;
      dest = "$HOME/.agents/skills";
      structure = "symlink-tree";
    };

    # Claude Code reads here.
    claude = {
      enable = true;
      dest = "\${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills";
      structure = "symlink-tree";
    };

    # Pi's current skill search path.
    pi = {
      enable = true;
      dest = "$HOME/.pi/agent/skills";
      structure = "symlink-tree";
    };
  };

  # Let agents keep their own generated system skill dirs.
  excludePatterns = [ "/.system" ];
}
