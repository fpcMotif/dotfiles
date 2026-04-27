#!/usr/bin/env bash

pi_agent__path_prepend_unique() {
  local segment
  for segment in "$@"; do
    [ -n "$segment" ] || continue
    case ":$PATH:" in
      *":$segment:"*) ;;
      *) PATH="$segment:$PATH" ;;
    esac
  done
}

pi_agent_is_nix_mode() {
  if [ "${PI_AGENT_PACKAGE_MANAGER:-}" = "nix" ] || [ "${PI_PACKAGE_MANAGER:-}" = "nix" ]; then
    return 0
  fi

  if [ -n "${IN_NIX_SHELL:-}" ] || [ -n "${NIX_PROFILES:-}" ]; then
    return 0
  fi

  if [ -d /nix ] && [ -x "$HOME/.nix-profile/bin/nix" ]; then
    return 0
  fi

  return 1
}

pi_agent_apply_path() {
  pi_agent__path_prepend_unique \
    "/opt/zerobrew/prefix/bin" \
    "$HOME/.bun/bin" \
    "$HOME/.local/bin" \
    "/sbin" \
    "/usr/sbin" \
    "/bin" \
    "/usr/bin"

  if pi_agent_is_nix_mode; then
    pi_agent__path_prepend_unique \
      "$HOME/.nix-profile/bin" \
      "/nix/var/nix/profiles/default/bin"
  fi

  export PATH
}
