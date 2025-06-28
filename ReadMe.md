# My macOS Ricing Environment 💻

A curated collection of dotfiles to create a beautiful and productive development environment on macOS, focusing on keyboard-driven workflows and minimalism.

## Showcase

[![Desktop Screenshot](https://i.imgur.com/gZlAKA4.png)](https://i.imgur.com/gZlAKA4.png)
*Wallpaper: [City Night](https://i.imgur.com/3VeMb4x.jpeg)*

---

## Core Components

This setup is built around a collection of powerful and customizable tools:

| Type                  | Tool                                                                                             | Description                                                                                                |
| --------------------- | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| **Window Manager**    | [AeroSpace](https://github.com/nikitabobko/AeroSpace)                                              | An i3-like tiling window manager for macOS that enforces focus and organization.                           |
| **Terminal**          | [Kitty](https://github.com/kovidgoyal/kitty)                                                     | A fast, feature-rich, GPU-based terminal emulator.                                                         |
| **Shell**             | [Zsh](https://www.zsh.org/) + [Starship](https://github.com/starship/starship)                     | A powerful shell combined with a minimal, blazing-fast, and infinitely customizable prompt.                |
| **Code Editor**       | [Neovim](https://neovim.io/) ([LazyVim](https://www.lazyvim.org))                                  | A highly extensible, Vim-based text editor, configured using the LazyVim distribution for a modern IDE experience. |
| **Terminal Multiplexer**| [Tmux](https://github.com/tmux/tmux)                                                             | Manages multiple terminal sessions, making it easy to switch between projects and preserve layouts.        |
| **Menu Bar**          | [SketchyBar](https://github.com/FelixKratz/SketchyBar)                                           | A highly customizable status bar that displays system information and workspaces.                          |
| **Web Browsers**      | [Zen](https://github.com/zen-browser/www) & [Qutebrowser](https://github.com/qutebrowser/qutebrowser) | Keyboard-driven and minimalist web browsers designed for efficiency and security.                          |
| **Package Manager**   | [Homebrew](https://brew.sh/)                                                                     | The essential package manager for installing and managing software on macOS.                               |
| **File Manager**      | [Yazi](https://github.com/sxyazi/yazi)                                                           | A blazing-fast terminal file manager written in Rust, with a rich feature set and plugin support.          |

## Essential CLI Utilities

This environment is enhanced by a suite of modern command-line tools for a more efficient workflow:

- **[FZF](https://github.com/junegunn/fzf):** A general-purpose command-line fuzzy finder.
- **[Eza](https://github.com/eza-community/eza):** A modern, feature-rich replacement for the `ls` command.
- **[Bat](https://github.com/sharkdp/bat):** A `cat` clone with syntax highlighting and Git integration.
- **[fd](https://github.com/sharkdp/fd):** A simple, fast, and user-friendly alternative to `find`.
- **[Ripgrep](https://github.com/BurntSushi/ripgrep):** A line-oriented search tool that recursively searches for a regex pattern.
- **[Maccy](https://maccy.app/):** A lightweight and powerful clipboard manager for macOS.

---

## 🚀 Installation

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/d7manDev/dot.git ~/.dotfiles
    ```
2.  **Run the installation script:**
    ```sh
    cd ~/.dotfiles
    bash .config/scripts/install.sh
    ```
    This script will:
    - Install [Homebrew](https://brew.sh/) if it's not already present.
    - Install all required packages, casks, and fonts from the list at `.config/scripts/brew_packages.txt`.
    - **Note:** You may need to manually symlink the configuration files to your home directory (e.g., using `stow`).

## 🛠️ Helper Scripts

A collection of scripts is included to automate common tasks:

| Script                  | Description                                                                 |
| ----------------------- | --------------------------------------------------------------------------- |
| `install.sh`            | Installs Homebrew and all packages from `brew_packages.txt`.                |
| `brewls.sh`             | Exports all currently installed Homebrew packages into `brew_packages.txt`. |
| `github_open.sh`        | Opens the GitHub repository for the current directory in your browser.      |
| `tmux-sessionizer.sh`   | A script to easily find, create, and switch between tmux sessions.          |
