#!/usr/bin/env bash
set -euo pipefail

ensure_path_entry() {
  local entry="$1"
  local line="export PATH=\"$entry:\$PATH\""

  case ":$PATH:" in
  *":$entry:"*) ;;
  *) export PATH="$entry:$PATH" ;;
  esac

  touch "$HOME/.bashrc"

  if ! grep -Fqx "$line" "$HOME/.bashrc"; then
    echo "$line" >>"$HOME/.bashrc"
  fi
}

ensure_local_dirs() {
  mkdir -p "$HOME/.local/bin" "$HOME/.local/opt" "$HOME/.config"
}

ensure_local_bin_on_path() {
  ensure_path_entry "$HOME/.local/bin"
}

ensure_npm_user_prefix() {
  local prefix="$HOME/.local/npm-global"

  mkdir -p "$prefix"
  npm config set prefix "$prefix"

  ensure_path_entry "$prefix/bin"
}

install_neovim() {
  local version="${NVIM_VERSION:-stable}"
  local arch
  local archive
  local install_dir="$HOME/.local/opt/nvim"

  case "$(uname -m)" in
  x86_64) arch="x86_64" ;;
  aarch64 | arm64) arch="arm64" ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
  esac

  archive="nvim-linux-${arch}.tar.gz"

  (
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    curl -fsSL "https://github.com/neovim/neovim/releases/download/${version}/${archive}" \
      -o "$tmp/${archive}"

    rm -rf "$install_dir"
    mkdir -p "$install_dir"

    tar -xzf "$tmp/${archive}" -C "$install_dir" --strip-components=1
  )

  ln -sfn "$install_dir/bin/nvim" "$HOME/.local/bin/nvim"
  nvim --version | head -n 1
}

install_chezmoi() {
  if command -v chezmoi >/dev/null 2>&1; then
    chezmoi --version
    return
  fi

  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
  chezmoi --version
}

apply_dotfiles() {
  chezmoi init --apply https://github.com/robian/dotfiles3.git
  git -C "$(chezmoi source-path)" remote set-url --push origin git@github.com:robian/dotfiles3.git
}

install_tree_sitter_cli() {
  if command -v tree-sitter >/dev/null 2>&1; then
    tree-sitter --version
    return
  fi

  if ! command -v npm >/dev/null 2>&1; then
    echo "npm is required to install tree-sitter-cli" >&2
    return 1
  fi

  ensure_npm_user_prefix

  npm install -g tree-sitter-cli
  tree-sitter --version
}

main() {
  ensure_local_dirs
  ensure_local_bin_on_path

  if command -v npm >/dev/null 2>&1; then
    ensure_npm_user_prefix
  fi

  install_neovim
  install_tree_sitter_cli
  install_chezmoi
  apply_dotfiles
}

main "$@"
