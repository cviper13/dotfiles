# Sway WM configurations

To install this configurations in your system copy the **content** of the folder
*"sway_wm"* into your home's *.config/sway* folder, then reload your sway
configuration (usually **Mod+Shift+C**)

**REMEMBER**
If you have previous configurations this will overwrite them or collide with
some of your shortcut definitions, make sure to backup your configurations first!

![Screenshot](https://i.postimg.cc/zDpD7mcf/2019-02-05-17-13-14-screenshot.png)

# Requirements

These configurations use the following software/fonts/things:

* [Kitty](https://sw.kovidgoyal.net/kitty/)
* [Terminus (TTF) font](https://aur.archlinux.org/packages/terminus-font-ttf/)
* [mako](https://github.com/emersion/mako) [Arch package](https://www.archlinux.org/packages/community/x86_64/mako/)
* pavucontrol / pactl
* swaylock
* swayidle
* swaybg
* [wofi](https://hg.sr.ht/~scoopta/wofi) [Arch package](https://www.archlinux.org/packages/community/x86_64/wofi/)
* [playerctl](https://github.com/acrisci/playerctl) [Arch package](https://www.archlinux.org/packages/community/x86_64/playerctl/)
* [light](https://github.com/haikarainen/light) [AUR package](https://aur.archlinux.org/packages/light-git)
* [grimshot](https://github.com/swaywm/sway/tree/master/contrib) [AUR package](https://aur.archlinux.org/packages/grimshot/)
* [waybar](https://github.com/Alexays/Waybar) [Arch package](https://www.archlinux.org/packages/community/x86_64/waybar/)

# Keybindings (case insensitive)

You will find that most of this keybindings are the same as the default ones
with some additions made by me.

*Mod* key is mapped to Windows/Logo/Command key

## Actions
* **Mod + Enter** New terminal
* **Mod + L** Lock screen
* **Mod + X** Run dialog
* **Mod + F** Make current window fullscreen
* **Mod + S** Take screenshot of entire screen (saved in Pictures folder)
* **Mod + Shift + S** Take screenshot of an area (saved in Pictures folder)
* **Mod + Shift + Q** Quit program
* **Mod + Shift + E** Exit Sway
* **Mod + Shift + C** Reload Sway configuration
* **Mod + Shift + -** Move window to scratchpad
* **Mod + -** Show scratchpad

## Workspaces keys

* **Mod + 0..9** Change current workspace
* **Mod + Shift + 0..9** Move current window to designated workspace
* **Mod + B** Horizontal layout
* **Mod + V** Vertical layout
* **Mod + T** Stacking layout
* **Mod + E** Toggle split layout
* **Mod + W** Tabbed layout
* **Mod + A** Focus on parent container
* **Mod + Space** Swap focus between tiling and floating
* **Mod + Shift + Space** Toggle floating mode
* **Mod + Tab** Next workspace
* **Mod + Shift + Tab** Previous workspace
* **Mod + Left/Right/Up/Down** Move focus of the window
* **Mod + Shift + Left/Right/Up/Down** Move the focused window in the workspace

## Multimedia/system keys

**NOTE**: The sound bindings expect to have at least one analog output, which
          they will use for sound. If your configuration differs, you have
          to change the *pactl* command that detects the output number
          in *config.d/multimedia*

* **Mod + F1** Mute/Unmute sound
* **Mod + F2** Decrease volume 2%
* **Mod + F3** Increase volume 2%
* **Mod + F4** Jump to previous song (MPRIS players only)
* **Mod + F5** Play/Pause song
* **Mod + F6** Jump to next song
* **Mod + F7** Disable eDP-1 display (usually laptop screen)
* **Mod + F8** Enable eDP-1 display (usually laptop screen)
* **Mod + F9** Decrease screen brightness 5%
* **Mod + F10** Increase screen brightness 5%
* **Alt + Shift** Change keyboard language

# Resize mode

To resize windows, you must enter resize mode, with the **Mod + R** keybinding. After
you enter resize mode you can resize windows with *Left/Right/Up/Down* keys, and
press *enter* or *escape* to return to default mode.

# Custom bindings

If you have custom bindings for your hardware put them into the `config.d/custom`
directory. In my case I have custom bindings for:

* Logitech MX Master 3 (side buttons for changing workspace)
* DasKeyboard 4 Ultimate (Multimedia keys)
