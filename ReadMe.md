# My macOS Ricing Environment 💻

A curated collection of dotfiles to create a beautiful and productive development environment on macOS, focusing on keyboard-driven workflows and minimalism.

## Showcase

[![Desktop Screenshot](https://i.imgur.com/gZlAKA4.png)](https://i.imgur.com/gZlAKA4.png)
_Wallpaper: [City Night](https://i.imgur.com/3VeMb4x.jpeg)_

---

## Core Components

This setup is built around a collection of powerful and customizable tools:

| Type                     | Tool                                                                                                  | Description                                                                                         |
| ------------------------ | ----------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **Window Manager**       | [AeroSpace](https://github.com/nikitabobko/AeroSpace)                                                 | An i3-like tiling window manager for macOS, configured declaratively via nix-darwin for focus and organization. |
| **Terminal**             | [Kitty](https://github.com/kovidgoyal/kitty)                                                          | A fast, feature-rich, GPU-based terminal emulator.                                                  |
| **Shell**                | [Zsh](https://www.zsh.org/) + [Starship](https://github.com/starship/starship)                        | A powerful shell configured with plugins, themes, and environment variables via nix-darwin, combined with a minimal prompt. |
| **Code Editor**          | [Neovim](https://neovim.io/)                                                                          | A highly extensible, Vim-based text editor, configured for a modern IDE experience.                 |
| **Terminal Multiplexer** | [Tmux](https://github.com/tmux/tmux)                                                                  | Manages multiple terminal sessions, making it easy to switch between projects and preserve layouts. |
| **Menu Bar**             | [SketchyBar](https://github.com/FelixKratz/SketchyBar)                                                | A highly customizable status bar that displays system information and workspaces.                   |
| **Web Browsers**         | [Zen](https://github.com/zen-browser/www) & [Qutebrowser](https://github.com/qutebrowser/qutebrowser) | Keyboard-driven and minimalist web browsers designed for efficiency and security.                   |
| **Package Manager**      | [Nix](https://nixos.org/) (with [nix-darwin](https://github.com/nix-darwin/nix-darwin))             | Declarative package and system management for macOS, ensuring reproducible environments.           |
| **File Manager**         | [Yazi](https://github.com/sxyazi/yazi)                                                                | A blazing-fast terminal file manager written in Rust, with a rich feature set and plugin support.   |

## Essential CLI Utilities

This environment is enhanced by a suite of modern command-line tools for a more efficient workflow:

- **[FZF](https://github.com/junegunn/fzf):** A general-purpose command-line fuzzy finder.
- **[Eza](https://github.com/eza-community/eza):** A modern, feature-rich replacement for the `ls` command.
- **[Bat](https://github.com/sharkdp/bat):** A `cat` clone with syntax highlighting and Git integration.
- **[fd](https://github.com/sharkdp/fd):** A simple, fast, and user-friendly alternative to `find`.
- **[Ripgrep](https://github.com/BurntSushi/ripgrep):** A line-oriented search tool that recursively searches for a regex pattern.

---

## Nix Configuration Overview

My environment is managed declaratively using Nix and nix-darwin. The nix-darwin configuration, including Zsh shell and AeroSpace window manager setups, has been moved to a separate repository for better organization.

- Main nix-darwin repo: [x0d7x/nix-config](https://github.com/x0d7x/nix-config)
- Key files in nix-config: `flake.nix`, `hosts/darwin/shell.nix` (Zsh config), `hosts/darwin/aerospace.nix` (AeroSpace config), etc.

To update packages or settings, clone the nix-config repo and run `darwin-rebuild switch --flake .#dox`.

---

## 🚀 Installation

1. **Clone the repository:**
   ```sh
   git clone https://github.com/x0d7x/dot.git ~/.dot
   cd ~/.dot
   ```
2. **Install Nix (if not already present):**
   Follow the [official Nix installation guide](https://nixos.org/download/#nix-install-macos) for multi-user installation:
   ```sh
   sh <(curl -L https://nixos.org/nix/install) --daemon
   ```
   Restart your shell or source the Nix environment as instructed.
3. **Enable Nix flakes:**
   If not already enabled, add the following to `~/.config/nix/nix.conf` (create the file if needed):
   ```
   experimental-features = nix-command flakes
   ```
4. **Apply the nix-darwin configuration:**
    ```sh
    git clone https://github.com/x0d7x/nix-config.git ~/.config/nix
    cd ~/.config/nix
    darwin-rebuild switch --flake .#dox
    ```
    This applies your system configuration, including Zsh and AeroSpace, installing packages and settings from the flake.
5. **Symlink dotfiles:**
   Manually symlink configuration files to your home directory using `stow` or your preferred method (e.g., `stow -d ~/.dot -t ~ .config`).

**Note:** The old `brew_packages.txt` is kept for reference. Zsh and AeroSpace configurations are now handled via nix-darwin. If you encounter issues, check the [nix-darwin manual](https://daiderd.com/nix-darwin/manual/index.html) or the [nix-config README](https://github.com/x0d7x/nix-config).

## 🛠️ Helper Scripts

A collection of scripts is included to automate common tasks:

| Script                | Description                                                                 |
| --------------------- | --------------------------------------------------------------------------- |
| `install.sh`          | Deprecated: Legacy Homebrew setup script. Use the installation guide above for Nix. |
| `brewls.sh`           | Deprecated: Exported Homebrew packages (kept for reference in `brew_packages.txt`). |
| `github_open.sh`      | Opens the GitHub repository for the current directory in your browser.      |
| `tmux-sessionizer.sh` | A script to easily find, create, and switch between tmux sessions.          |
