# My macOS Ricing Environment 💻

A curated collection of dotfiles to create a beautiful and productive development environment on macOS, focusing on keyboard-driven workflows and minimalism.

## Showcase

[![Desktop Screenshot](https://i.imgur.com/LTLFeW9.jpeg)](https://i.imgur.com/LTLFeW9.jpeg)
_Wallpaper: [City Night](https://i.imgur.com/3VeMb4x.jpeg)_

---

## Core Components

This setup is built around a collection of powerful and customizable tools:

| Type                     | Tool                                                                                                  | Description                                                                                                                 |
| ------------------------ | ----------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| **Window Manager**       | [Rift](https://github.com/riftWM/rift)                                                                 | A modern, dynamic tiling window manager for macOS, configured declaratively via nix-darwin.                                    |
| **Terminal**             | [Kitty](https://github.com/kovidgoyal/kitty)                                                          | A fast, feature-rich, GPU-based terminal emulator.                                                                          |
| **Shell**                | [Zsh](https://www.zsh.org/) + [10kpowerlevel](https://github.com/10kpowerlevel/10kpowerlevel)         | A powerful shell configured with plugins, themes, and environment variables via nix-darwin, combined with a feature-rich prompt. |
| **Code Editor**          | [Neovim](https://neovim.io/)                                                                          | A highly extensible, Vim-based text editor, configured for a modern IDE experience with Blink.cmp.                              |
| **Terminal Multiplexer** | [Tmux](https://github.com/tmux/tmux)                                                                  | Manages multiple terminal sessions, making it easy to switch between projects and preserve layouts.                         |
| **Menu Bar**             | [SketchyBar](https://github.com/FelixKratz/SketchyBar)                                                | A highly customizable status bar that displays system information and workspaces.                                           |
| **Web Browsers**         | [Zen](https://github.com/zen-browser/www) & [Qutebrowser](https://github.com/qutebrowser/qutebrowser) | Keyboard-driven and minimalist web browsers designed for efficiency and security.                                           |
| **Package Manager**      | [Nix](https://nixos.org/) (with [nix-darwin](https://github.com/nix-darwin/nix-darwin))               | Declarative package and system management for macOS, ensuring reproducible environments.                                    |
| **File Manager**         | [Yazi](https://github.com/sxyazi/yazi)                                                                | A blazing-fast terminal file manager written in Rust, with a rich feature set and plugin support.                           |

---

## Nix Configuration

My environment is managed declaratively using Nix and nix-darwin. The system configuration is maintained in a separate repository.

- **nix-config repo:** [x0d7x/nix-config](https://github.com/x0d7x/nix-config)
- **Contains:** Zsh config, Rift window manager config, Home Manager, system packages, and more

To update packages or settings, clone the nix-config repo and run:
```sh
darwin-rebuild switch --flake .#dox
```

---

## Essential CLI Utilities

This environment is enhanced by a suite of modern command-line tools for a more efficient workflow:

- **[FZF](https://github.com/junegunn/fzf):** A general-purpose command-line fuzzy finder.
- **[Eza](https://github.com/eza-community/eza):** A modern, feature-rich replacement for `ls` command.
- **[Bat](https://github.com/sharkdp/bat):** A `cat` clone with syntax highlighting and Git integration.
- **[fd](https://github.com/sharkdp/fd):** A simple, fast, and user-friendly alternative to `find`.
- **[Ripgrep](https://github.com/BurntSushi/ripgrep):** A line-oriented search tool that recursively searches for a regex pattern.
- **[Fastfetch](https://github.com/fastfetch-cli/fastfetch):** A system information fetch tool with image support.

---

## Installation

1. **Clone the repository:**
   ```sh
   git clone https://github.com/x0d7x/dot.git ~/dot
   cd ~/dot
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
4. **Clone and apply nix-config:**
   ```sh
   git clone https://github.com/x0d7x/nix-config.git ~/.config/nix
   cd ~/.config/nix
   darwin-rebuild switch --flake .#dox
   ```
5. **Symlink dotfiles with GNU Stow:**
   ```sh
   cd ~/dot && stow -v -t ~ .config
   ```

---

## 🛠️ Helper Scripts

A collection of scripts to automate common tasks:

| Script                  | Description                                                                         |
| ---------------------- | ---------------------------------------------------------------------------------- |
| `tmux-sessionizer`     | A script to easily find, create, and switch between tmux sessions.                |
| `tmux-session-switch`  | Quickly switch between existing tmux sessions.                                     |
| `github_open`          | Opens the GitHub repository for the current directory in your browser.            |
| `notes`                | Quick note-taking script.                                                          |
| `sticky`                | Create floating sticky notes on macOS.                                             |
| `rename_files_with_fd` | Batch rename files using fd and fzf.                                               |
| `obs_switch.lua`       | OBS scene switcher for streaming/recording.                                        |
| `chbg`                 | Change desktop wallpaper.                                                          |
| `brewls`               | Lists installed Homebrew packages (legacy, for reference).                        |
| `install`              | Legacy installation script (deprecated).                                          |
