# My Custom Neovim Setup

A smart, daily-driver Neovim configuration built from scratch for performance and a smooth, distro-free experience.

![Neovim Setup](https://imgur.com/a/1yrRZCM)

## Features

- **Smart AI Integration:** Go beyond basic editing with integrated AI features.
- **Powerful Autocompletion:** Fast and intelligent code completion with `nvim-cmp`.
- **Effortless Formatting:** Keep your code clean and consistent with `conform.lua`.
- **Seamless Git Integration:** Manage your Git workflow without leaving the editor.
- **Robust Linting and LSP:** Get real-time feedback and code intelligence with built-in linting and LSP support.
- **Beautiful and Performant UI:** A custom theme and a minimal, clean interface with `noice.lua`.
- **Advanced Syntax Highlighting:** Better code understanding with `nvim-treesitter`.
- **And much more...**

## Plugin Overview

This setup is built on a curated list of plugins, managed by `lazy.nvim`. Here are some of the key players:

- **AI:** `ai.lua`
- **Completion:** `cmp-autocom.lua`
- **Formatting:** `conform.lua`
- **Git:** `Git.lua`
- **Linting:** `linter.lua`
- **LSP:** `lsp.lua`
- **UI:** `noice.lua`, `miniFile.lua`, `which-key.lua`
- **Syntax:** `treesittr.lua`
- **Theme:** `theme.lua`

For a full list of plugins, see the `lua/plugins/` directory and the `lazy-lock.json` file.

## Installation

1.  Clone this repository to your `~/.config/nvim` directory.
2.  Install `lazy.nvim` if you don't have it already.
3.  Start Neovim and `lazy.nvim` will handle the rest.

## Keymaps

All keymaps are defined in `lua/config/keymaps.lua`. Check out the file to see how to get the most out of this setup.

## Customization

Feel free to customize this setup to your liking. The main configuration files are:

- `init.lua`: The entry point of the configuration.
- `lua/config/opts.lua`: General Neovim options.
- `lua/plugins/`: Add or remove plugins here.

---

_This README was generated with love by Gemini._
