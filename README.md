# Project-Zero

A post-install setup script for a minimal Arch Linux desktop built on DWM, startx, and a curated set of tools. This is not a full Arch installer — you install Arch first, then run this script.

---

## Table of Contents

- [Step 1 — Installing Arch with archinstall](#step-1--installing-arch-with-archinstall)
- [Step 2 — Cloning the Repo and Running the Script](#step-2--cloning-the-repo-and-running-the-script)
- [What the Script Does — Section by Section](#what-the-script-does--section-by-section)
- [How DWM Works](#how-dwm-works)
- [How .xinitrc Works](#how-xinitrc-works)
- [Keybindings Reference](#keybindings-reference)
- [After Install](#after-install)

---

## Step 1 — Installing Arch with archinstall

Boot the Arch ISO, connect to the internet, and run:

```bash
archinstall
```

Below is every option in the archinstall menu and what to choose.

### Archinstall language

Leave as English unless you want the installer UI in another language. This does not affect your system language.

### Locales

Set your language (e.g. `en_US`) and keyboard layout. This affects how your system handles text encoding and key input. Get this right — it is easier to set here than to fix later.

### Mirrors and repositories

Choose mirrors geographically close to you. Closer mirrors download packages faster. You can use the mirror ranking feature to automatically pick the fastest ones.

### Disk configuration

Choose **Use a best-effort default partition layout**. This automatically creates:

- A 1 GiB EFI boot partition
- The rest of the disk as your main partition

For filesystem, choose **btrfs**. When asked about subvolumes, choose **Yes**. This creates the following layout:

| Subvolume | Mountpoint | Purpose |
| --- | --- | --- |
| `@` | `/` | Root filesystem |
| `@home` | `/home` | Your personal files |
| `@log` | `/var/log` | System logs (excluded from snapshots) |
| `@pkg` | `/var/cache/pacman/pkg` | Package cache (excluded from snapshots) |

Subvolumes let you take snapshots of your system before updates so you can roll back if something breaks — like a time machine for your OS.

When asked about compression, choose **Use compression**. This uses `zstd` compression which reduces disk writes and can actually improve performance. It does not hurt your SSD.

### Swap

Choose **zram** with **zstd**. zram creates a compressed swap space inside your RAM itself. It only activates when RAM is nearly full and has zero SSD writes — better for both performance and drive longevity compared to a traditional swap partition.

### Bootloader

Choose **GRUB**. It is the most widely supported bootloader and works reliably across hardware generations.

### Kernels

Leave as `linux` (the default). The standard kernel is fine for this setup.

### Hostname

Set whatever name you want your machine to have on the network (e.g. `archbox`, your name, anything).

### Authentication

Set your root password and create your user account. Make sure to check the option to give your user `sudo` access — the install script needs it.

### Profile

**Do not select any profile.** Leave this empty. The install script handles everything — selecting a profile here would install a desktop environment you don't want.

### Applications

- **Audio**: choose **PipeWire** — the script expects PipeWire and configures it
- **Bluetooth**: choose **Yes** if you want Bluetooth — the script also installs `blueman` for a GUI
- **Print service (CUPS)**: choose **No** unless you have a printer. It adds background services with no benefit if you don't print
- **Firewall**: choose **Yes** and select **ufw** — essential for a laptop that connects to public networks. It blocks incoming connections by default and you will never notice it

### Network configuration

Choose **Use NetworkManager (default backend)**. NetworkManager handles both wired and wireless connections and is what `nm-applet` in the systray talks to. Do not choose the iwd backend — it conflicts with the default wpa_supplicant setup and causes complications.

### Pacman

Enable **multilib** if you plan to run 32-bit applications or games. Otherwise leave defaults.

### Additional packages

Leave empty. The script installs everything.

### Timezone

Set your timezone. This keeps your system clock correct.

### Automatic time sync (NTP)

Leave enabled. This keeps your clock synced automatically over the internet.

Once everything is configured, choose **Install** and let it finish. When done, reboot into your new system.

---

## Step 2 — Cloning the Repo and Running the Script

After rebooting, log in as your user (not root). You will be at a plain terminal — that is correct.

Make sure you have an internet connection:

```bash
ping archlinux.org
```

Clone the repo:

```bash
git clone https://github.com/NOTHING-R/Arch-Dwm-Install-Script.git
cd Arch-Dwm-Install-Script
```

Make the script executable and run it:

```bash
chmod +x install.sh
./install.sh
```

The script will take 10–20 minutes depending on your internet speed. When it finishes you will see:

```
✅ Installation complete! Run 'startx' to launch dwm.
```

Then simply type:

```bash
startx
```

---

## What the Script Does — Section by Section

### Setup — yay (AUR helper)

```bash
sudo pacman -Suy
git clone https://aur.archlinux.org/yay.git /tmp/yay-build
```

The first thing the script does is update the system and install **yay**. Arch's official package manager is `pacman` but it only covers the official repositories. yay adds access to the **AUR (Arch User Repository)** — a community-maintained collection of thousands of additional packages. Three things in this setup require it: `betterlockscreen`, `wlogout`, and `google-chrome`. yay is cloned to `/tmp` so it doesn't leave a build folder in your home directory.

### Setup — Wallpapers and tpm

```bash
git clone https://github.com/NOTHING-R/Walllpapers.git ~/Walllpapers
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

The wallpaper repo is cloned to `~/Walllpapers` before any packages are installed. This is done early so `feh` can reference it correctly when the `~/.fehbg` file is written later. tpm (tmux plugin manager) is cloned to `~/.tmux/plugins/tpm` so that on your first tmux launch it finds its plugins (catppuccin theme) already in place.

### Section 0 — Intel Graphics Drivers

```
mesa, mesa-utils, vulkan-intel, vulkan-icd-loader,
intel-media-driver, libva, libva-intel-driver, libva-utils
```

X11 cannot start without graphics drivers. These packages are the complete open-source Intel graphics stack confirmed working on the HP EliteBook 840 G5 (Intel UHD 620).

- `mesa` — the core open-source graphics library. Provides OpenGL and the `iris` driver that X11 uses for Intel GPUs
- `mesa-utils` — provides `glxinfo` so you can confirm the driver loaded correctly with `glxinfo | grep "OpenGL renderer"`
- `vulkan-intel` — Vulkan support for Intel GPUs, used by newer applications and games
- `vulkan-icd-loader` — the loader that dispatches Vulkan calls to the correct driver
- `intel-media-driver` — hardware video acceleration (VA-API) using Intel's iHD driver. Makes Firefox and kdenlive use the GPU for video decode instead of burning CPU cycles
- `libva` — the VA-API library that `intel-media-driver` links against
- `libva-intel-driver` — legacy VA-API driver, kept alongside the modern one for compatibility
- `libva-utils` — provides the `vainfo` command to verify hardware acceleration is working

> **Note:** `xf86-video-intel` is intentionally not installed. On modern Intel hardware (anything after Sandy Bridge), the modesetting driver built into Mesa performs better. The `i915` kernel driver comes with the Linux kernel itself — no separate package is needed.

### Section 1 — Xorg Environment

```
git, base-devel, xorg-server, xorg-xinit, xorg-xrdb, xorg-setxkbmap,
libx11, libxft, libxinerama, libinput, xf86-input-libinput, xorg-xinput, rofi, unzip, curl
```

Everything needed to run X11 and compile DWM.

- `xorg-server` — the X11 display server. The entire graphical environment runs on top of this
- `xorg-xinit` — provides `startx`, the command you type to launch your graphical session
- `xorg-xrdb` — reads `~/.Xresources` on startup to apply DPI and font settings (called in `.xinitrc`)
- `xorg-setxkbmap` — keyboard layout configuration for X11
- `libx11`, `libxft`, `libxinerama` — X11 development libraries that DWM compiles against. Without these `make` fails
- `xf86-input-libinput` — the input driver for your touchpad and keyboard under X11. Enables tap-to-click, natural scrolling
- `xorg-xinput` — the `xinput` command used in `.xinitrc` to configure the touchpad at startup
- `rofi` — the application launcher bound to `Alt+D`. Replaces dmenu with a more modern look
- `base-devel` — the group of tools needed to compile software from source (gcc, make, etc.)

### Section 2 — Fonts

```
noto-fonts-emoji, ttf-jetbrains-mono-nerd, ttf-firacode-nerd,
ttf-hack-nerd, ttf-cascadia-code-nerd
```

Nerd Fonts are patched versions of popular programming fonts with thousands of icons embedded directly into the font. DWM, dwmblocks, rofi, and kitty all use these.

- `ttf-jetbrains-mono-nerd` — used in the DWM bar and rofi (`JetBrainsMono Nerd Font:size=11`)
- `ttf-cascadia-code-nerd` — used in the kitty terminal (`CaskaydiaCove Nerd Font`)
- `ttf-firacode-nerd` — used in dunst notifications (`FiraCode Nerd Font`)
- `noto-fonts-emoji` — system emoji support so emoji render in the browser and terminal

After installing, `fc-cache -fv` refreshes the font cache so the system immediately recognises the new fonts.

### Section 3 — Virtualization

```
qemu-full, virt-manager, virt-viewer, dnsmasq, vde2,
openbsd-netcat, libvirt, edk2-ovmf
```

A full KVM/QEMU virtual machine stack. Lets you run Windows, other Linux distros, or anything else in a VM.

- `qemu-full` — the actual virtualisation engine
- `virt-manager` — the GUI for managing VMs
- `libvirt` — the daemon that manages virtual machines. Enabled with `systemctl enable --now libvirtd`
- `dnsmasq` — provides DNS and DHCP for the virtual network so VMs can access the internet
- `edk2-ovmf` — UEFI firmware for VMs (needed for modern OS installs)
- The script adds your user to the `libvirt` group so you can manage VMs without sudo, and starts the default virtual network so VMs have internet access immediately

### Section 4 — Bluetooth

```
bluez, bluez-utils, blueman
```

- `bluez` — the Linux Bluetooth stack
- `bluez-utils` — command-line tools (`bluetoothctl`)
- `blueman` — the GUI Bluetooth manager whose tray icon appears in the systray via `blueman-applet &` in `.xinitrc`

### Section 5 — Audio

```
pipewire, pipewire-pulse, pipewire-alsa, wireplumber, pavucontrol
```

PipeWire is the modern Linux audio server. It replaces both PulseAudio and JACK.

- `pipewire` — the core audio server
- `pipewire-pulse` — a drop-in PulseAudio replacement layer. This is why `pactl` (used in the DWM volume keybinds) works — it talks to PipeWire as if it were PulseAudio
- `pipewire-alsa` — routes ALSA audio through PipeWire so apps that use ALSA directly also go through the same audio graph
- `wireplumber` — the session manager that tells PipeWire which audio devices to use and manages routing
- `pavucontrol` — a graphical mixer for adjusting volumes per-application

Services are enabled with `systemctl --user enable` so they start automatically on login without needing a display manager.

### Section 6 — Window Manager Core

```
picom, feh, dunst, flameshot, libnotify, networkmanager,
network-manager-applet, brightnessctl, nsxiv, nautilus,
xdg-user-dirs, xdg-utils, polkit-gnome
```

Everything that makes the desktop usable.

- `picom` — the compositor. Adds transparency to the kitty terminal, shadows, and blur effects. Without it windows render but look flat and there are no transparency effects
- `feh` — sets the desktop wallpaper. On every login `.xinitrc` runs `~/.fehbg` which calls `feh --bg-fill` with your last chosen wallpaper
- `dunst` — the notification daemon. Displays desktop notifications in the top-right corner when you change volume, brightness, or set a wallpaper
- `flameshot` — screenshot tool. Launched at startup so `flameshot gui` is available for region screenshots
- `libnotify` — provides the `notify-send` command which the DWM volume and brightness keybinds use to send notifications to dunst
- `networkmanager` — the actual network service. Manages wifi and ethernet. Without this package you have no internet after boot
- `network-manager-applet` — provides `nm-applet`, the network icon in the systray
- `brightnessctl` — controls screen brightness. Used by the `XF86MonBrightnessUp/Down` keybinds in DWM
- `nsxiv` — image viewer used by `wal.sh` to display wallpaper thumbnails for selection
- `nautilus` — graphical file manager
- `xdg-user-dirs` — creates standard folders (`~/Downloads`, `~/Documents`, `~/Pictures` etc.) via `xdg-user-dirs-update`. Nautilus and most apps expect these to exist
- `xdg-utils` — provides `xdg-open` so apps can open files and links with the correct program (e.g. clicking a PDF in a browser opens it in a PDF viewer)
- `polkit-gnome` — provides a graphical password prompt when an app needs elevated privileges (e.g. Nautilus accessing a protected folder). Without it, privilege requests silently fail

The script also writes `~/.fehbg` directly to disk rather than running `feh` — because during install there is no display server running, so `feh` would fail silently and `~/.fehbg` would never be created. Writing it directly guarantees the wallpaper loads on first boot.

### Section 7 — Programming Toolchain

```
vim, neovim, imagemagick, gcc, clang, make, cmake, nodejs, npm,
kitty, fish, stow, ripgrep, fd, curl, unzip, xclip, tmux, firefox, inxi
```

- `neovim` — the primary text editor, configured with lazy.nvim under `configs/nvim`
- `imagemagick` — required by the `image.nvim` plugin for rendering images inside neovim
- `kitty` — the terminal emulator. GPU-accelerated with transparency via picom
- `fish` — set as the default shell with `chsh`. A modern shell with autocompletion and syntax highlighting out of the box
- `tmux` — terminal multiplexer. Config in `~/.tmux.conf` uses catppuccin theme and tpm for plugin management
- `ripgrep`, `fd` — fast search tools used by telescope inside neovim
- `xclip` — clipboard integration between X11 and the terminal
- `nodejs`, `npm` — required by several neovim LSP servers and the live-server plugin
- `inxi` — system information tool. Run `inxi -Fxxxz` to see a full summary of your hardware and drivers
- `firefox` — set as the default browser in `.xprofile` via `export BROWSER=firefox`

After all section 7 packages install, `chsh -s $(which fish)` sets fish as the default shell. This takes effect on next login.

### AUR Packages

```
betterlockscreen, wlogout, google-chrome
```

These are installed via yay because they are not in the official Arch repos.

- `betterlockscreen` — a fast, good-looking screen locker. The script pre-caches `crime.jpg` with `betterlockscreen -u` so the lockscreen has a wallpaper immediately. Bound to `Alt+X` in DWM
- `wlogout` — a full-screen logout/shutdown/reboot menu. Bound to `Alt+P` in DWM
- `google-chrome` — Chrome browser as an alternative to Firefox

### Section 8 — Media and Editing

```
obs-studio, kdenlive, easyeffects
```

- `obs-studio` — screen recording and live streaming
- `kdenlive` — video editor. Uses VA-API hardware acceleration thanks to `intel-media-driver` installed in section 0
- `easyeffects` — advanced audio processing (equalizer, compressor, noise cancellation). Works natively with PipeWire

### Dotfiles Deploy

After all packages are installed the script deploys your configs:

```
configs/dunst    → ~/.config/dunst
configs/kitty    → ~/.config/kitty
configs/nvim     → ~/.config/nvim
configs/picom    → ~/.config/picom
configs/wlogout  → ~/.config/wlogout
dwm/             → ~/.config/dwm
dwmblocks/       → ~/.config/dwmblocks
startup/.xinitrc      → ~/
startup/.xprofile     → ~/
startup/.Xresources   → ~/
configs/.tmux.conf    → ~/
```

DWM and dwmblocks are copied to `~/.config/` rather than being built directly from the repo. This means your personal DWM source always lives at `~/.config/dwm` — if you want to change a keybind or color, you edit there, run `make && sudo make install`, and restart DWM.

---

## How DWM Works

DWM (Dynamic Window Manager) is a window manager written in C. Unlike GNOME or KDE, it has no settings menu — you configure it by editing the source code and recompiling. The entire configuration lives in two files.

### config.h

This is where everything about DWM's behavior is defined — fonts, colors, keybindings, layouts, and rules for specific applications. When you change something here you must recompile:

```bash
cd ~/.config/dwm
make clean && make && sudo make install
# Then restart DWM with Alt+Shift+Q and startx again
```

### colors.h

Defines the color palette used by the DWM bar. Colors come from `colors.h` which is included by `config.h`:

```c
static const char wal_bg[]     = "#020101"; // bar background
static const char wal_fg[]     = "#a7a7a6"; // bar text
static const char wal_border[] = "#747474"; // inactive window border
static const char wal_bg_sel[] = "#40403F"; // selected tag background
static const char wal_fg_sel[] = "#020101"; // selected tag text
```

### config.def.h

The "default" version of `config.h`. Kept identical to `config.h` so if `config.h` ever gets deleted, `make` regenerates it correctly from your custom settings rather than from the original stock DWM defaults.

### dwmblocks

DWM's bar cannot display dynamic information (time, battery, RAM) on its own. dwmblocks is a separate program that runs in the background and feeds text into the bar's status area by calling `xsetroot`. Each "block" is a small command that runs on a timer:

```c
{ "", "echo memory info",  1,  0 },  // updates every 1 second
{ "", "echo disk info",   60,  0 },  // updates every 60 seconds
{ "", "echo battery",     10,  0 },  // updates every 10 seconds
{ "", "echo date/time",    1,  0 },  // updates every 1 second
```

All four blocks are inlined directly in `blocks.h` as shell commands — no external scripts. Colors are defined once at the top:

```c
#define BG "#020101"  // background color
#define FG "#a7a7a6"  // foreground text color
```

And applied to every block using DWM's color markup syntax: `^c<color>^` sets foreground, `^b<color>^` sets background, `^d^` resets to defaults.

### Layouts

DWM comes with three layouts, switched with keybindings:

- **Tile `[]=`** — the default. One master window on the left taking 55% of the screen, all others stacked on the right
- **Float `><>`** — windows float freely, like a traditional desktop
- **Monocle `[M]`** — one fullscreen window at a time, like a maximized view

### Tags

DWM uses tags instead of traditional workspaces. Every window can be on one or more tags. Tags 1–10 are available. Firefox is configured to always open on tag 9 (`1 << 8`).

---

## How .xinitrc Works

`.xinitrc` is the script that runs when you type `startx`. It is executed by the X server before anything graphical appears. Every program you want running in your session must be started here.

```sh
#!/bin/sh

# Load Xresources (fonts, dpi)
[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources
```

`xrdb` loads `~/.Xresources` into the X resource database. This is where `Xft.dpi: 140` lives — setting the DPI to 140 makes text render at the right size for the EliteBook's 1920x1080 13.9" display. Without this, fonts are too small.

```sh
# Load xprofile (env settings)
[ -f ~/.xprofile ] && . ~/.xprofile
```

Sources `.xprofile` which sets environment variables:

```sh
export EDITOR=nvim
export TERMINAL=kitty
export BROWSER=firefox
```

These tell every program in the session which editor, terminal, and browser to use when they need to launch one.

```sh
# Input settings (touchpad)
xinput set-prop "SYNA3071:00 06CB:82F1 Touchpad" "libinput Tapping Enabled" 1
xinput set-prop "SYNA3071:00 06CB:82F1 Touchpad" "libinput Natural Scrolling Enabled" 1
```

Enables tap-to-click and natural (reversed) scrolling on the touchpad. The device name is specific to the HP EliteBook 840 G5. If you run this on a different machine, find your touchpad name with `xinput list` and update accordingly.

```sh
# Background
~/.fehbg &
```

Runs the `~/.fehbg` script which was created during install. It contains a single line:

```sh
feh --no-fehbg --bg-fill '/home/user/Walllpapers/crime.jpg'
```

`feh` sets this image as the desktop background. When you change the wallpaper using `wal.sh`, feh automatically updates `~/.fehbg` with the new image path, so it persists across reboots.

```sh
# System services (START HERE)
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
picom &
dwmblocks &
dunst &
nm-applet &
blueman-applet &
flameshot &
```

Every service is launched with `&` which means "run in the background and continue". The order matters:

- `polkit-gnome` starts first so it is ready before any app requests elevated privileges
- `picom` starts next — compositing needs to be active before windows appear
- `dwmblocks` starts and immediately begins updating the status bar
- `dunst` starts so it is ready to receive notifications from the services that follow
- `nm-applet`, `blueman-applet`, `flameshot` put their icons in the systray

```sh
# Start window manager
exec dwm
```

`exec` replaces the current shell process with `dwm`. This is important — using `exec` means when DWM exits, the X session ends cleanly. Without `exec` you would use `dwm &` and the session would not terminate when you quit DWM.

---

## Keybindings Reference

`MODKEY` is the `Alt` key.

| Keybind | Action |
| --- | --- |
| `Alt + Return` | Open kitty terminal |
| `Alt + D` | Open rofi app launcher |
| `Alt + B` | Open Firefox |
| `Alt + V` | Open neovim in kitty |
| `Alt + W` | Open wallpaper picker (nsxiv) |
| `Alt + X` | Lock screen (betterlockscreen) |
| `Alt + Shift + X` | Update lockscreen wallpaper to current wallpaper |
| `Alt + P` | Open wlogout (logout/shutdown menu) |
| `Alt + Q` | Close focused window |
| `Alt + Shift + Q` | Quit DWM |
| `Alt + N` | Toggle DWM bar |
| `Alt + J / K` | Focus next/previous window |
| `Alt + H / L` | Resize master area |
| `Alt + T` | Tile layout |
| `Alt + F` | Float layout |
| `Alt + M` | Monocle layout |
| `Alt + Tab` | Toggle between last two tags |
| `Alt + 1–0` | Switch to tag 1–10 |
| `Alt + Shift + J/K` | Move window up/down in stack |
| `Alt + Shift + F1` | Hide window |
| `Alt + Shift + F2` | Show window |
| `Alt + Ctrl + S` | Show all hidden windows |
| `Volume Up/Down` | Raise/lower volume 5% + dunst notification |
| `Mute` | Toggle mute + dunst notification |
| `Brightness Up/Down` | Raise/lower brightness 5% + dunst notification |

---

## After Install

**Verify graphics acceleration is working:**

```bash
glxinfo | grep "OpenGL renderer"
# Should show: Mesa Intel UHD Graphics 620 (KBL GT2)

vainfo
# Should show Intel iHD driver with H264, HEVC, VP9 support
```

**Install tmux plugins:**
Start tmux and press `Ctrl+B` then `Shift+I` to install the catppuccin theme and any other configured plugins.

**Change your wallpaper:**
Press `Alt+W` inside DWM to open the nsxiv wallpaper picker. Navigate thumbnails with arrow keys, press `M` to mark your choice, then `Q` to apply it.

**Recompile DWM after config changes:**

```bash
cd ~/.config/dwm
make clean && make && sudo make install
# Restart DWM: Alt+Shift+Q, then startx
```

---

## Browser File Uploading (File Picker)

### The Problem

On a minimal dwm + startx setup, clicking the file upload button in Firefox or Chrome shows either nothing at all or a blank white screen. This happens because browsers on X11 use the **xdg-desktop-portal** to open the system file picker dialog, and on a plain startx session the portal can't find the display because systemd user services don't inherit your X environment variables automatically.

Three things need to be in place for file uploading to work:

**1. Portal packages installed:**

- `xdg-desktop-portal` — the portal middleware layer
- `xdg-desktop-portal-gtk` — the GTK file picker backend
- `gvfs` — virtual filesystem support (required by the GTK portal)

All three are installed by `install.sh` in section 6.

**2. X environment exported to systemd on login:**

This line in `.xinitrc` passes `DISPLAY` to the systemd user session so `xdg-desktop-portal-gtk` can find the X server when it starts:

```sh
systemctl --user import-environment DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS
```

Without this, the GTK portal service starts but immediately crashes with `cannot open display`.

**3. Firefox configured to use the portal:**

By default Firefox on X11 uses its own built-in file picker which doesn't integrate with the system. To make it use the portal:

1. Open `about:config` in Firefox
2. Search for `widget.use-xdg-desktop-portal.file-picker`
3. Set the value to `1`
4. Restart Firefox

Chrome uses the portal automatically without any extra configuration.

---

### The Fullscreen File Picker Issue

On first use, the GTK file picker may open completely fullscreen — taking over your entire screen with no window decorations. This is GTK not knowing the correct screen dimensions on a tiling window manager.

**How to resize it:**

- Hold `Alt` and **right-click drag** anywhere on the file picker window to resize it
- GTK remembers the size after you resize it once — it will open at the correct size from then on

---

### Troubleshooting

If the file picker still doesn't appear, check if the portal services are running:

```bash
systemctl --user status xdg-desktop-portal
systemctl --user status xdg-desktop-portal-gtk
```

If `xdg-desktop-portal-gtk` shows `failed` with `cannot open display`, the environment wasn't imported correctly. Run manually:

```bash
systemctl --user import-environment DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS
systemctl --user restart xdg-desktop-portal-gtk
systemctl --user restart xdg-desktop-portal
```

Then try again. After the next full logout and `startx`, `.xinitrc` handles this automatically.
