# pylint: disable=C0111
c = c  # noqa: F821 pylint: disable=E0602,C0103
config = config  # noqa: F821 pylint: disable=E0602,C0103
# pylint settings included to disable linting errors
config.source("matugen/colors.py")

# Colors (adjust for macOS)
# Example hardcoded colors:
# statusbar.normal.bg = "#1e1e1e"
# statusbar.normal.fg = "#d4d4d4"

# c.colors.statusbar.normal.bg = "#00000000"
# c.colors.statusbar.command.bg = "#00000000"
# c.colors.statusbar.command.fg = "#d4d4d4" # Example color
# c.colors.statusbar.normal.fg = "#569cd6" # Example color
# c.colors.statusbar.passthrough.fg = "#569cd6" # Example color
# c.colors.statusbar.url.fg = "#4ec9b0" # Example color
# c.colors.statusbar.url.success.https.fg = "#4ec9b0" # Example color
# c.colors.statusbar.url.hover.fg = "#c586c0" # Example color
# c.colors.statusbar.insert.bg = "#c586c0" # 
# # c.statusbar.show = "always"
# c.colors.tabs.even.bg = "#00000000" # transparent tabs!!
# c.colors.tabs.odd.bg = "#00000000"
# c.colors.tabs.bar.bg = "#00000000"
# c.colors.tabs.even.bg = "#1e1e1e" # Example color
# c.colors.tabs.odd.bg = "#1e1e1e" # Example color
# c.colors.tabs.even.fg = "#d4d4d4" # Example color
# c.colors.tabs.odd.fg = "#d4d4d4" # Example color
# c.colors.tabs.selected.even.bg = "#666A9E" # Example color
# c.colors.tabs.selected.odd.bg = "#666A9E" # Example color
# c.colors.tabs.selected.even.fg = "#d4d4d4" # Example color
# c.colors.tabs.selected.odd.fg = "#d4d4d4" # Example color
# c.colors.hints.bg = "#ecba73" # Example color
# c.colors.hints.fg = "#000000" # Example color
# c.colors.tabs.pinned.even.bg = "#000000"
# c.colors.tabs.pinned.odd.bg = "#000000"
# c.colors.tabs.pinned.selected.even.bg = "#d4d4d4"
# c.colors.tabs.pinned.selected.odd.bg = "#d4d4d4"
# c.colors.completion.item.selected.match.fg = "#c8c8c8" # Example color
# c.colors.completion.match.fg = "#c8c8c8" # Example color
#
# c.colors.tabs.indicator.start = "#569cd6" # Example color
# c.colors.tabs.indicator.stop = "#f44747" # Example color
# c.colors.completion.odd.bg = "#1e1e1e" # Example color
# c.colors.completion.even.bg = "#1e1e1e" # Example color
# c.colors.completion.fg = "#d4d4d4" # Example color
# c.colors.completion.category.bg = "#1e1e1e" # Example color
# c.colors.completion.category.fg = "#d4d4d4" # Example color
# c.colors.completion.item.selected.bg = "#1e1e1e" # Example color
# c.colors.completion.item.selected.fg = "#d4d4d4" # Example color
# c.colors.messages.info.bg = "#1e1e1e" # Example color
# c.colors.messages.info.fg = "#d4d4d4" # Example color
# c.colors.messages.error.bg = "#1e1e1e" # Example color
# c.colors.messages.error.fg = "#d4d4d4" # Example color
# c.colors.downloads.error.bg = "#1e1e1e" # Example color
# c.colors.downloads.error.fg = "#d4d4d4" # Example color
#
# c.colors.downloads.bar.bg = "#1e1e1e" # Example color
# c.colors.downloads.start.bg = "#569cd6" # Example color
# c.colors.downloads.start.fg = "#d4d4d4" # Example color
# c.colors.downloads.stop.bg = "#f44747" # Example color
# c.colors.downloads.stop.fg = "#d4d4d4" # Example color
#
# c.colors.tooltip.bg = "#1e1e1e" # Example color
# c.colors.webpage.bg = "#1e1e1e" # Example color
# c.hints.border = "#d4d4d4" # Example color
# c.url.start_pages = ""
# c.url.default_page = ""

c.tabs.show = "multiple"
c.tabs.title.format = "{audio}{index}: {current_title}"
c.fonts.web.size.default = 16
c.url.searchengines = {
# note - if you use duckduckgo, you can make use of its built in bangs, of which there are many! https://duckduckgo.com/bangs
        'DEFAULT': 'https://duckduckgo.com/?q={}',
        "wa": "https://wiki.archlinux.org/?search={}",
        'gh': 'https://github.com/search?o=desc&q={}&s=stars',
        'yt': 'https://www.youtube.com/results?search_query={}',
        'g': 'https://www.google.com/search?q={}',
        'nix': 'https://mynixos.com/search?q={}',
        'aur': 'https://aur.archlinux.org/packages?O=0&K={}',
        }

c.completion.open_categories = ['searchengines', 'quickmarks', 'bookmarks', 'filesystem'] # history is discluded  'history',
c.completion.height = "30%"
config.load_autoconfig() # load settings done via the gui

c.auto_save.session = True # save tabs on quit/restart
c.session.lazy_restore = True # restore tabs on startup
c.window.hide_decoration = True
c.content.autoplay = False
c.hints.chars = "asdghjkl"
c.editor.command = ["kitty", "--app-id", "edit","-e", "nvim", "{file}"]

# keybinding changes
config.bind('=', 'cmd-set-text -s :open')
config.bind('hi', 'history')
config.bind('ge', 'edit-url')
config.bind('<Ctrl-i>', 'jseval document.activeElement.blur()')
config.bind('cs', 'cmd-set-text -s :config-source')
config.bind('tH', 'config-cycle tabs.show multiple switching never')
config.bind('sH', 'config-cycle statusbar.show always never')
config.bind('T', 'hint links tab')
config.bind('pP', 'open -- {primary}')
config.bind('pp', 'open -- {clipboard}')
config.bind('pt', 'open -t -- {clipboard}')
config.bind('qm', 'macro-record')
# config.bind('<ctrl-y>', 'spawn --userscript ytdl.sh') # Check if ytdl.sh is compatible with macOS or needs modification
config.bind('tT', 'config-cycle tabs.position top left')
config.bind('gJ', 'tab-move +')
config.bind('gK', 'tab-move -')
config.bind('gm', 'tab-move')
config.bind('gn', ' tab-next ')
config.bind('gp', ' tab-prev ') 
config.bind('X', ' undo ')
config.bind('jk', 'mode-leave', mode='insert')
config.bind('<Backspace>', 'mode-leave', mode='hint')
config.bind('f', 'mode-leave', mode='hint')
config.bind('<Ctrl-p>', 'tab-pin')
config.bind(",v", "hint links spawn --detach mpv {hint-url}")
# config.set('colors.webpage.darkmode.enabled', False, 'file://*')
# Bitwarden/rbw integration
config.bind('<Ctrl-b>', 'spawn --userscript rbw-fill', mode='insert')
config.bind('pw', 'spawn --userscript rbw-fill', mode='normal')
# dark mode setup
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.darkmode.algorithm = 'lightness-cielab'
c.colors.webpage.darkmode.policy.images = 'never'
c.hints.leave_on_load = True
c.tabs.new_position.related = "last"


# styles, cosmetics
# c.content.user_stylesheets = ["~/.config/qutebrowser/styles/youtube-tweaks.css"] # Check path on macOS
c.tabs.padding = {'top': 5, 'bottom': 5, 'left': 9, 'right': 9}
c.tabs.indicator.width = 3 # no tab indicators
c.tabs.pinned.frozen = True # Pinned tabs keep their original URL
c.window.transparent = True # apparently not needed
c.tabs.width = '7%'
c.scrolling.smooth = True
c.scrolling.bar = "when-searching"
c.content.headers.custom = {"accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"}
c.content.webgl = False
c.tabs.select_on_remove = "last-used"

# fonts
c.fonts.default_family = []
c.fonts.default_size = '13pt'
c.fonts.web.family.fixed = 'thmanyah sans'
c.fonts.web.family.sans_serif = 'thmanyah sans'
c.fonts.web.family.serif = 'thmanyah sans'
c.fonts.web.family.standard = 'thmanyah sans'
c.zoom.default =  112
# privacy - adjust these settings based on your preference
# config.set("completion.cmd_history_max_items", 0)
# config.set("content.private_browsing", True)
# config.set("content.webgl", False, "*")
config.set('content.canvas_reading', False)
config.set("content.geolocation", False)
config.set("content.webrtc_ip_handling_policy", "default-public-interface-only")
config.set("content.cookies.accept", "no-unknown-3rdparty")
config.set("content.cookies.store", True)
config.set("content.javascript.enabled", True)

# Adblocking info -->
# For yt ads: place the greasemonkey script yt-ads.js in your greasemonkey folder (~/.config/qutebrowser/greasemonkey).
# The script skips through the entire ad, so all you have to do is click the skip button.
# Yeah it's not ublock origin, but if you want a minimal browser, this is a solution for the tradeoff.
# You can also watch yt vids directly in mpv, see qutebrowser FAQ for how to do that.
# If you want additional blocklists, you can get the python-adblock package, or you can uncomment the ublock lists here.
c.content.blocking.enabled = True
c.content.blocking.hosts.block_subdomains = True
c.content.blocking.method = 'both' # uncomment this if you install python-adblock
c.content.blocking.adblock.lists = [
"https://easylist.to/easylist/easylist.txt",
"https://easylist.to/easylist/easyprivacy.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/legacy.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters-2020.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters-2021.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters-2022.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters-2023.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters-2024.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters-2025.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters-2026.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/badware.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/privacy.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/badlists.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/annoyances.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/annoyances-cookies.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/annoyances-others.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/quick-fixes.txt",
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/resource-abuse.txt",
"https://github.com/uBlockOrigin/uAssets/raw/master/filters/annoyances-cookies.txt"
        "https://github.com/uBlockOrigin/uAssets/raw/master/filters/unbreak.txt"]

