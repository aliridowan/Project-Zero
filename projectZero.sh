#!/bin/bash

# ==========================================
# ARCH LINUX POST INSTALL SETUP SCRIPT
# zerosdots — stow-based dotfiles workflow
# ==========================================
# This script installs:
# 0. Intel graphics drivers
# 1. Development + Xorg environment (for DWM / X11)
# 2. Nerd fonts (for terminal + icons)
# 3. Virt-manager (KVM/QEMU virtual machines)
# 4. Bluetooth stack (Bluez + GUI tool)
# 5. Audio stack (PipeWire)
# 6. Window manager rice core tools
# 7. Programming + terminal toolchain
# 8. Media and editing tools
# Then clones ~/zerosdots and deploys all dotfiles using stow
# ==========================================

# ------------------------------------------
# STRICT ERROR HANDLING
# ------------------------------------------
# set -e  — exit immediately if any command returns a non-zero exit code.
#           Without this, a failed pacman install would let the script keep
#           running, potentially building DWM without its dependencies.
# set -u  — treat unset variables as an error. Catches typos like $DOTS_DRI
#           before they silently expand to empty strings and corrupt paths.
# set -o pipefail — makes a pipeline fail if ANY command in it fails, not just
#                   the last one. e.g. "pacman -Q pkg | grep something" would
#                   hide a missing-package error without this.
set -euo pipefail

# Colors for output
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

echo "Starting system setup..."

cat <<'EOF'


                           WELCOME ON
____________ _____   ___ _____ _____ _____   ______ ___________ _____ 
| ___ \ ___ \  _  | |_  |  ___/  __ \_   _| |___  /|  ___| ___ \  _  |
| |_/ / |_/ / | | |   | | |__ | /  \/ | |      / / | |__ | |_/ / | | |
|  __/|    /| | | |   | |  __|| |     | |     / /  |  __||    /| | | |
| |   | |\ \\ \_/ /\__/ / |___| \__/\ | |   ./ /___| |___| |\ \\ \_/ /
\_|   \_| \_|\___/\____/\____/ \____/ \_/   \_____/\____/\_| \_|\___/ 

                      YOUR SYSTEM PARTNER 
EOF

echo ""

# ------------------------------------------
# ROOT CHECK
# ------------------------------------------
# Running this script as root breaks several things:
# - yay refuses to run as root (AUR builds must be done as a normal user)
# - makepkg refuses to run as root
# - stow symlinks would land in /root instead of your home directory
# - chsh would change root's shell, not yours
# - systemctl --user would target root's session, not yours
# The script uses sudo internally for the commands that actually need it.
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}ERROR: Do not run this script as root.${RESET}"
  echo -e "${RED}Run it as your normal user with sudo privileges:${RESET}"
  echo -e "${RED}  bash install.sh${RESET}"
  exit 1
fi

# ------------------------------------------
# SUDO PRIVILEGE CHECK
# ------------------------------------------
# Validate that sudo works before spending time installing packages,
# only to fail on the first sudo command minutes into the run.
echo -e "${YELLOW}Checking sudo access...${RESET}"
if ! sudo -v; then
  echo -e "${RED}ERROR: sudo access required. Add your user to the sudoers file.${RESET}"
  exit 1
fi
echo "✔ sudo access confirmed"

# Keep sudo alive for the duration of the script so it doesn't time out
# mid-install and block on a password prompt.
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!

# Clean up the keepalive process when the script exits for any reason
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# DOTS_DIR is fixed — stow requires the package root to be at this exact path
# so that symlinks resolve relative to $HOME correctly.
DOTS_DIR="$HOME/zerosdots"

# ------------------------------------------
# SETUP — yay (AUR helper)
# ------------------------------------------
# Arch's official package manager (pacman) only covers the official repos.
# yay adds access to the AUR — a community-maintained collection of thousands
# of additional packages. betterlockscreen, wlogout, google-chrome, and
# ibus-avro are all AUR-only.
# yay is cloned to /tmp so it doesn't leave a build folder in your home directory.
# git and base-devel are installed first since makepkg needs them.
echo -e "${YELLOW}Setting up yay...${RESET}"
sudo pacman -Suy --noconfirm
sudo pacman -S --needed --noconfirm git base-devel go

# Safe clone — if /tmp/yay-build already exists from a previous interrupted run,
# remove it first so git clone doesn't fail.
rm -rf /tmp/yay-build
git clone https://aur.archlinux.org/yay.git /tmp/yay-build
cd /tmp/yay-build
makepkg -si --noconfirm
cd "$HOME"
echo "✔ yay ready"

# ------------------------------------------
# CLONE DOTFILES REPO
# ------------------------------------------
# zerosdots is cloned here — before any stow commands — so the installer
# never assumes the repo already exists. You can run this script from
# anywhere (e.g. a USB drive or curl | bash) and it will set itself up.
# Stow requires the repo to live at ~/zerosdots specifically because that
# is where all the symlink targets will point.
echo -e "${YELLOW}Cloning dotfiles repo...${RESET}"
if [ -d "$DOTS_DIR" ]; then
  # Repo already exists — pull latest changes instead of failing
  echo "  ~/zerosdots already exists, pulling latest changes..."
  git -C "$DOTS_DIR" pull
else
  git clone https://github.com/aliridowan/zerosdots "$DOTS_DIR"
fi
echo "✔ Dotfiles repo ready at $DOTS_DIR"

# ------------------------------------------
# CLONE WALLPAPER REPO
# ------------------------------------------
# Cloned early so feh can reference it when ~/.fehbg is written later in
# section 6. The wallpaper must exist on disk before that line runs.
echo -e "${YELLOW}Cloning wallpapers...${RESET}"
if [ -d "$HOME/Walllpapers" ]; then
  echo "  ~/Walllpapers already exists, pulling latest changes..."
  git -C "$HOME/Walllpapers" pull
else
  git clone https://github.com/NOTHING-R/Walllpapers.git ~/Walllpapers
fi
echo "✔ Wallpapers ready at ~/Walllpapers"

# ------------------------------------------
# CLONE TMUX PLUGIN MANAGER (tpm)
# ------------------------------------------
# tpm manages tmux plugins (catppuccin theme etc.).
# Cloned here so on first tmux launch it finds its plugins already in place.
# Install plugins inside tmux with: Ctrl+B then Shift+I
echo -e "${YELLOW}Cloning tmux plugin manager...${RESET}"
if [ -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "  tpm already exists, skipping..."
else
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi
echo "✔ tpm ready at ~/.tmux/plugins/tpm"

echo ""
echo -e "${YELLOW}Installing packages...${RESET}"
echo ""

# ------------------------------------------
# 0. GRAPHICS DRIVERS (Intel)
# ------------------------------------------
# Confirmed working on HP EliteBook 840 G5 (Intel UHD 620 / Kaby Lake-R).
# X11 cannot start without graphics drivers — this must be installed first.
#
# mesa             — the core open-source graphics library. Provides OpenGL and
#                    the iris driver that X11 uses for Intel GPUs
# mesa-utils       — provides glxinfo so you can verify the driver loaded:
#                    glxinfo | grep "OpenGL renderer"
# vulkan-intel     — Vulkan support for Intel GPUs, used by newer apps and games
# vulkan-icd-loader — the loader that dispatches Vulkan calls to the correct driver
# intel-media-driver — hardware video acceleration (VA-API) using Intel's iHD driver.
#                    Makes Firefox and kdenlive use the GPU for video decode instead
#                    of burning CPU cycles
# libva            — the VA-API library that intel-media-driver links against
# libva-intel-driver — legacy VA-API driver, kept alongside the modern one for compat
# libva-utils      — provides vainfo to verify hardware acceleration is working
#
# NOTE: xf86-video-intel is intentionally NOT installed.
# On modern Intel hardware (anything after Sandy Bridge) the modesetting driver
# built into Mesa performs better. The i915 kernel driver comes with the Linux
# kernel itself — no separate package needed.
echo -e "${YELLOW}[0/8] Installing Intel graphics drivers...${RESET}"
sudo pacman -S --needed --noconfirm \
  mesa \
  mesa-utils \
  vulkan-intel \
  vulkan-icd-loader \
  intel-media-driver \
  libva \
  libva-intel-driver \
  libva-utils
echo "✔ Intel graphics drivers installed"

# ------------------------------------------
# 1. BASIC DEVELOPMENT + XORG ENVIRONMENT
# ------------------------------------------
# Everything needed to run X11 and compile DWM from source.
#
# git, base-devel  — version control and the gcc/make/etc toolchain needed
#                    to compile DWM, dwmblocks, and AUR packages
# stow             — the dotfiles manager. Creates symlinks from ~/zerosdots
#                    into their correct locations so edits in the repo are live
# xorg-server      — the X11 display server. The entire graphical environment
#                    runs on top of this
# xorg-xinit       — provides startx, the command you type to launch your session
# xorg-xrdb        — reads ~/.Xresources on startup to apply DPI and font settings
# xorg-setxkbmap   — keyboard layout configuration for X11
# libx11, libxft, libxinerama — X11 development libraries that DWM compiles
#                    against. Without these make fails
# xf86-input-libinput — the input driver for your touchpad and keyboard under X11.
#                    Enables tap-to-click and natural scrolling
# xorg-xinput      — the xinput command used in .xinitrc to configure the touchpad
# rofi             — the application launcher bound to Alt+D. Replaces dmenu
# btop             -as a system monitor
# zip, unzip       — archive tools needed by various install scripts
# inxi             — system info tool. Run: inxi -Fxxxz
# usbutils         — provides lsusb for diagnosing USB/printer/scanner devices
# curl             — used to download files in scripts
echo -e "${YELLOW}[1/8] Installing Xorg + build tools...${RESET}"
sudo pacman -S --needed --noconfirm \
  git \
  base-devel \
  xorg-server \
  xorg-xinit \
  xorg-xrdb \
  xorg-setxkbmap \
  libx11 \
  libxft \
  libxinerama \
  libinput \
  xf86-input-libinput \
  xorg-xinput \
  rofi \
  btop \
  zip \
  unzip \
  inxi \
  usbutils \
  curl
echo "✔ Xorg + development tools installed"

# ------------------------------------------
# 2. FONTS AND THEMES (NERD FONTS + ICON SUPPORT)
# ------------------------------------------
# Nerd Fonts are patched versions of popular programming fonts with thousands
# of icons embedded directly into the font. DWM, dwmblocks, rofi, and kitty
# all use these for bar icons and UI glyphs.
#
# ttf-jetbrains-mono-nerd — used in the DWM bar and rofi (JetBrainsMono Nerd Font:size=11)
# ttf-cascadia-code-nerd  — used in the kitty terminal (CaskaydiaCove Nerd Font)
# ttf-firacode-nerd       — used in dunst notifications (FiraCode Nerd Font)
# ttf-hack-nerd           — general fallback nerd font
# noto-fonts-emoji        — system emoji support so emoji render in browser and terminal
# ttf-indic-otf           — Indic script support (Bengali, Hindi etc.)
# harfbuzz                — text shaping library required for correct rendering of
#                           complex scripts like Bengali
# gnome-themes-extra      - For Dark Theme
# nwg-look                - For Setting up gtk application themes
#
# fc-cache -fv refreshes the font cache so the system immediately recognises
# the new fonts without needing a reboot.
echo -e "${YELLOW}[2/8] Installing fonts...${RESET}"
sudo pacman -S --needed --noconfirm \
  noto-fonts-emoji \
  ttf-jetbrains-mono-nerd \
  ttf-firacode-nerd \
  ttf-hack-nerd \
  ttf-indic-otf \
  gnome-themes-extra \
  nwg-look \
  harfbuzz \
  ttf-cascadia-code-nerd
fc-cache -fv
echo "✔ Fonts installed and cache updated"

# ------------------------------------------
# 3. VIRTUALIZATION (Virt-Manager / KVM)
# ------------------------------------------
# A full KVM/QEMU virtual machine stack. Lets you run Windows, other Linux
# distros, or anything else in a VM with near-native performance.
#
# qemu-full        — the actual virtualisation engine
# virt-manager     — the GUI for creating and managing VMs
# virt-viewer      — the display window that shows the VM screen
# libvirt          — the daemon that manages virtual machines
# dnsmasq          — provides DNS and DHCP for the virtual network so VMs
#                    can access the internet
# vde2             — virtual distributed ethernet for advanced VM networking
# openbsd-netcat   — network utility required by libvirt
# edk2-ovmf        — UEFI firmware for VMs (needed for modern OS installs)
#
# libvirtd is enabled so it starts on boot.
# The user is added to the libvirt group — this takes effect on NEXT LOGIN,
# not in the current session. Until you log out and back in, virt-manager
# will still prompt for a password.
# The default virtual network is started so VMs have internet immediately.
echo -e "${YELLOW}[3/8] Installing virt-manager / KVM...${RESET}"
sudo pacman -S --needed --noconfirm \
  qemu-full \
  virt-manager \
  virt-viewer \
  dnsmasq \
  vde2 \
  openbsd-netcat \
  libvirt \
  edk2-ovmf
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt "$(whoami)"
# net-start can fail if the network is already running — treat that as non-fatal
sudo virsh net-start default 2>/dev/null || true
sudo virsh net-autostart default 2>/dev/null || true
echo "✔ Virt-manager + KVM setup complete"

# ------------------------------------------
# 4. BLUETOOTH SUPPORT
# ------------------------------------------
# bluez            — the Linux Bluetooth protocol stack
# bluez-utils      — command-line tools (bluetoothctl) for pairing devices
# blueman          — the GUI Bluetooth manager whose tray icon appears in the
#                    systray via blueman-applet & in .xinitrc
echo -e "${YELLOW}[4/8] Installing Bluetooth...${RESET}"
sudo pacman -S --needed --noconfirm \
  bluez \
  bluez-utils \
  blueman
sudo systemctl enable --now bluetooth
echo "✔ Bluetooth service enabled"

# ------------------------------------------
# 5. AUDIO (PipeWire + PulseAudio compat)
# ------------------------------------------
# PipeWire is the modern Linux audio server. It replaces both PulseAudio
# and JACK while staying compatible with software written for either.
#
# pipewire         — the core audio server
# pipewire-pulse   — a drop-in PulseAudio replacement layer. This is why
#                    pactl (used in the DWM volume keybinds) works — it talks
#                    to PipeWire as if it were PulseAudio
# pipewire-alsa    — routes ALSA audio through PipeWire so apps that use ALSA
#                    directly also go through the same audio graph
# wireplumber      — the session manager that tells PipeWire which audio
#                    devices to use and manages routing between apps
# pavucontrol      — a graphical mixer for adjusting volumes per-application
#
# Services are enabled with --user so they start automatically on login
# without needing a display manager. They will NOT start in this TTY session —
# they start on next login automatically.
echo -e "${YELLOW}[5/8] Installing audio stack...${RESET}"
sudo pacman -S --needed --noconfirm \
  pipewire \
  pipewire-pulse \
  pipewire-alsa \
  wireplumber \
  pavucontrol
# systemctl --user requires an active user session with XDG_RUNTIME_DIR set.
# On a fresh Arch install booted to TTY this is not available yet — the user
# session only starts on login. We use || true so the script does not die here.
# PipeWire will auto-start on next login because of the enable.
systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null || true
echo "✔ Audio stack installed (PipeWire + PulseAudio compat)"

# ------------------------------------------
# 6. WINDOW MANAGER / RICE CORE
# ------------------------------------------
# Everything that makes the desktop usable beyond just DWM itself.
#
# picom            — the compositor. Adds transparency to kitty, shadows, and
#                    blur effects. Without it windows render flat with no effects
# feh              — sets the desktop wallpaper. On every login .xinitrc runs
#                    ~/.fehbg which calls feh --bg-fill with your chosen wallpaper
# dunst            — the notification daemon. Displays desktop notifications in
#                    the corner when you change volume, brightness, or wallpaper
# flameshot        — screenshot tool. Launched at startup so flameshot gui is
#                    available for region screenshots
# libnotify        — provides the notify-send command which the DWM volume and
#                    brightness keybinds use to send notifications to dunst
# networkmanager   — the actual network service. Manages wifi and ethernet.
#                    Without this package you have no internet after boot
# network-manager-applet — provides nm-applet, the network icon in the systray
# brightnessctl    — controls screen brightness. Used by XF86MonBrightnessUp/Down
#                    keybinds in DWM
# nsxiv            — image viewer used by wal.sh to display wallpaper thumbnails
# nautilus         — graphical file manager
# xdg-user-dirs    — creates standard folders (~/Downloads, ~/Documents etc.)
#                    via xdg-user-dirs-update. Nautilus and most apps expect these
# xdg-utils        — provides xdg-open so apps can open files and links with the
#                    correct program (e.g. clicking a PDF opens a PDF viewer)
# xdg-desktop-portal     — middleware layer that lets apps open system dialogs
#                          (file pickers, screen share) in a sandboxed way
# xdg-desktop-portal-gtk — the GTK file picker backend. Required for the file
#                          upload dialog to work in Firefox and Chrome on X11
# gvfs             — virtual filesystem for Nautilus (trash, MTP, network shares)
# polkit-gnome     — provides a graphical password prompt when an app needs
#                    elevated privileges. Without it, privilege requests fail silently
echo -e "${YELLOW}[6/8] Installing WM rice core tools...${RESET}"
sudo pacman -S --needed --noconfirm \
  picom \
  feh \
  dunst \
  flameshot \
  libnotify \
  networkmanager \
  network-manager-applet \
  brightnessctl \
  nsxiv \
  nautilus \
  xdg-user-dirs \
  xdg-utils \
  xdg-desktop-portal \
  xdg-desktop-portal-gtk \
  gvfs \
  polkit-gnome
sudo systemctl enable --now NetworkManager
xdg-user-dirs-update

# Write ~/.fehbg directly — feh can't run during install (no display/X server).
# This file is sourced by .xinitrc on every login to restore the wallpaper.
# Writing it directly here guarantees it exists on first startx even before
# you manually pick a wallpaper with Alt+W.
echo "feh --no-fehbg --bg-fill '$HOME/Walllpapers/crime.jpg'" >~/.fehbg
chmod +x ~/.fehbg

echo "✔ Window manager rice core tools installed"

# ------------------------------------------
# 7. PROGRAMMING + TERMINAL TOOLCHAIN
# ------------------------------------------
# vim              — fallback editor for quick terminal edits
# neovim           — the primary text editor, configured with lazy.nvim
# imagemagick      — required by the image.nvim plugin for rendering images
#                    inside neovim
# gcc, clang       — C/C++ compilers. gcc is needed to compile DWM. clang is
#                    used by LSP servers (clangd) for C/C++ completion in neovim
# make, cmake      — build systems used by DWM, dwmblocks, and various tools
# nodejs, npm      — required by several neovim LSP servers and live-server
# kitty            — the terminal emulator. GPU-accelerated with transparency
#                    via picom
# fish             — set as the default shell. A modern shell with autocompletion
#                    and syntax highlighting out of the box
# stow             — dotfiles manager (also installed in section 1, --needed
#                    makes this safe to list twice)
# ripgrep          — fast text search used by telescope inside neovim
# fd               — fast file finder used by telescope inside neovim
# xclip            — clipboard integration between X11 and the terminal
# tmux             — terminal multiplexer. Config uses catppuccin theme via tpm
# firefox          — set as the default browser in .xprofile
#
# live-server is installed globally via npm — used by the neovim live-server
# plugin for live-reloading HTML/CSS during web development.
echo -e "${YELLOW}[7/8] Installing programming + terminal toolchain...${RESET}"
sudo pacman -S --needed --noconfirm \
  vim \
  neovim \
  imagemagick \
  gcc \
  clang \
  make \
  cmake \
  nodejs \
  npm \
  kitty \
  fish \
  stow \
  ripgrep \
  fd \
  xclip \
  tmux \
  firefox
sudo npm install -g live-server
echo "✔ Programming + terminal toolchain installed"

# ------------------------------------------
# 8. MEDIA + EDITING
# ------------------------------------------
# obs-studio       — screen recording and live streaming
# kdenlive         — video editor. Uses VA-API hardware acceleration thanks to
#                    intel-media-driver installed in section 0
# easyeffects      — advanced audio processing (equalizer, compressor, noise
#                    cancellation). Works natively with PipeWire
echo -e "${YELLOW}[8/8] Installing media + editing tools...${RESET}"
sudo pacman -S --needed --noconfirm \
  obs-studio \
  kdenlive \
  easyeffects
echo "✔ Media and editing tools installed"

# ------------------------------------------
# SET FISH AS DEFAULT SHELL
# ------------------------------------------
# chsh changes the shell for the NEXT login — it does not affect this session.
# fish will be active the first time you log in after installation.
echo -e "${YELLOW}Setting fish as default shell...${RESET}"
chsh -s "$(which fish)"
echo "✔ Default shell set to fish (takes effect on next login)"

# ------------------------------------------
# AUR PACKAGES
# ------------------------------------------
# These are not in the official Arch repos so they need yay.
#
# betterlockscreen — a fast, good-looking screen locker. Wallpaper is NOT cached
#                    here (no DISPLAY available in TTY). A first-login script
#                    handles that instead. Bound to Alt+X in DWM.
# wlogout          — a full-screen logout/shutdown/reboot menu. Bound to Alt+P
# google-chrome    — Chrome browser as an alternative to Firefox
# ibus-avro        — Avro Phonetic input method for typing Bengali. Started in
#                    .xinitrc via ibus-daemon -drx &
echo -e "${YELLOW}Installing AUR packages...${RESET}"
yay -S --noconfirm betterlockscreen wlogout google-chrome ibus-avro
echo "✔ AUR packages installed"

# ------------------------------------------
# VALIDATE DOTFILES STRUCTURE
# ------------------------------------------
# Before running stow, verify that all expected package directories exist in the
# repo. If any are missing it means the clone failed silently or the repo was
# restructured — either way stow would create broken symlinks, so we stop here.
echo -e "${YELLOW}Validating dotfiles structure...${RESET}"

REQUIRED_PACKAGES=(
  dunst
  dwm
  dwmblocks
  flameshot
  kitty
  nvim
  picom
  rofi
  startup
  wlogout
  devtmux
)

MISSING=()
for pkg in "${REQUIRED_PACKAGES[@]}"; do
  if [ ! -d "$DOTS_DIR/$pkg" ]; then
    MISSING+=("$pkg")
  fi
done

if [ ${#MISSING[@]} -ne 0 ]; then
  echo -e "${RED}ERROR: The following required dotfiles packages are missing from $DOTS_DIR:${RESET}"
  for m in "${MISSING[@]}"; do
    echo -e "${RED}  ✘ $m${RESET}"
  done
  echo -e "${RED}The dotfiles repo may not have cloned correctly. Check your internet connection and try again.${RESET}"
  exit 1
fi

echo "✔ All required dotfiles packages found"

# ------------------------------------------
# CLEAN EXISTING CONFIG DIRECTORIES
# ------------------------------------------
# Remove all target directories and files before stow runs.
# This guarantees no conflicts regardless of whether they are
# real directories, old symlinks, or leftover files from a
# previous install attempt.
echo -e "${YELLOW}Cleaning existing config directories before stow...${RESET}"

# ~/.config/* directories
rm -rf \
  "$HOME/.config/dunst" \
  "$HOME/.config/dwm" \
  "$HOME/.config/dwmblocks" \
  "$HOME/.config/flameshot" \
  "$HOME/.config/kitty" \
  "$HOME/.config/nvim" \
  "$HOME/.config/picom" \
  "$HOME/.config/rofi" \
  "$HOME/.config/wlogout" \
  "$HOME/.config/devtmux"

# Dotfiles that land directly in ~ (from the startup package)
rm -f \
  "$HOME/.xinitrc" \
  "$HOME/.xprofile" \
  "$HOME/.Xresources" \
  "$HOME/.tmux.conf"

echo "✔ Pre-stow cleanup done"

# ------------------------------------------
# DEPLOY DOTFILES WITH STOW
# ------------------------------------------
# Stow creates symlinks from ~/zerosdots into their correct system locations.
# The key idea: each package folder mirrors the path structure relative to $HOME.
# Stow strips the package name and maps everything inside it onto the target.
#
# How the paths resolve:
#   zerosdots/nvim/.config/nvim/      →  ~/.config/nvim        (symlink)
#   zerosdots/kitty/.config/kitty/    →  ~/.config/kitty       (symlink)
#   zerosdots/dwm/.config/dwm/        →  ~/.config/dwm         (symlink)
#   zerosdots/startup/.xinitrc        →  ~/.xinitrc             (symlink)
#   zerosdots/startup/.tmux.conf      →  ~/.tmux.conf           (symlink)
#   zerosdots/startup/.Xresources     →  ~/.Xresources          (symlink)
#   zerosdots/startup/.xprofile       →  ~/.xprofile            (symlink)
#
# The startup package files land directly in ~ because they sit directly
# inside the package folder with no subfolder in between. No need to move
# them out — stow handles dotfiles in ~ correctly as-is.
#
# Stow failures are FATAL here. A failed stow means DWM won't find its
# config.h or Makefile, the build will fail, and you'll have a broken install.
# It is better to stop and tell you what conflicted than to silently continue.
#
# To fix a conflict manually:
#   stow --adopt --target=$HOME --dir=~/zerosdots <package>
#   git -C ~/zerosdots checkout .
# --adopt pulls the existing conflicting file into the repo, then git checkout
# restores your dotfile version, and stow replaces it with a symlink.
echo ""
echo -e "${YELLOW}Deploying dotfiles with stow...${RESET}"

mkdir -p "$HOME/.config"

STOW_PACKAGES=(
  dunst
  dwm
  dwmblocks
  flameshot
  kitty
  nvim
  picom
  rofi
  startup
  wlogout
  devtmux
  # code  # VSCode — uncomment once Code is installed on this machine
)

for pkg in "${STOW_PACKAGES[@]}"; do
  if stow --stow --target="$HOME" --dir="$DOTS_DIR" "$pkg" 2>/tmp/stow_err; then
    echo "  ✔ $pkg"
  else
    echo -e "${RED}ERROR: stow failed for package: $pkg${RESET}"
    echo -e "${RED}Conflict details:${RESET}"
    cat /tmp/stow_err
    echo ""
    echo -e "${RED}A file already exists at the target location and is not a stow symlink.${RESET}"
    echo -e "${RED}Fix it with:${RESET}"
    echo -e "${RED}  stow --adopt --target=\$HOME --dir=$DOTS_DIR $pkg${RESET}"
    echo -e "${RED}  git -C $DOTS_DIR checkout .${RESET}"
    echo -e "${RED}Then re-run this script.${RESET}"
    exit 1
  fi
done

echo "✔ Dotfiles deployed"

# ------------------------------------------
# BUILD + INSTALL DWM
# ------------------------------------------
# DWM is compiled from source — no binary package exists because configuration
# is done by editing config.h and recompiling. The source now lives at
# ~/.config/dwm (symlinked from ~/zerosdots/dwm/.config/dwm) so any future
# config changes happen there and are tracked by git automatically.
echo -e "${YELLOW}Building and installing dwm...${RESET}"
cd ~/.config/dwm
make clean
make
sudo make install
cd "$HOME"
echo "✔ dwm installed"

# ------------------------------------------
# BUILD + INSTALL DWMBLOCKS
# ------------------------------------------
# dwmblocks feeds the status bar text into DWM by calling xsetroot -name.
# Like DWM itself it is compiled from source. Source lives at ~/.config/dwmblocks.
echo -e "${YELLOW}Building and installing dwmblocks...${RESET}"
cd ~/.config/dwmblocks
make clean
make
sudo make install
cd "$HOME"
echo "✔ dwmblocks installed"

# ------------------------------------------
# MAKE DWM SCRIPTS EXECUTABLE
# ------------------------------------------
# wal.sh and betterlockscreen.sh need execute permission.
# chmod is needed here because git does not preserve execute bits across all
# systems, and stow creates symlinks (not copies) so the permissions on the
# symlink target file in ~/zerosdots are what matter.
chmod +x ~/.config/dwm/scripts/*
echo "✔ dwm scripts marked executable"

# ------------------------------------------
# MAKE DEV COMMAND AVAILABLE SYSTEM-WIDE
# ------------------------------------------
chmod +x "$HOME/.config/devtmux/dev.sh"
sudo ln -s "$HOME/.config/devtmux/dev.sh" /usr/local/bin/dev
echo "✔ dev command linked to /usr/local/bin/dev"

# ------------------------------------------
# FIRST-LOGIN SETUP SCRIPT
# ------------------------------------------
# betterlockscreen -u requires an active X11 DISPLAY to pre-process the
# wallpaper. Running it here (from a TTY with no X server) will always fail.
# Instead, we write a self-contained one-shot script to ~/.config/first-login-setup.sh
#
# IMPORTANT: We do NOT inject into .xinitrc here. ~/.xinitrc is a stow symlink
# pointing into ~/zerosdots/startup/.xinitrc. Modifying it with sed would dirty
# the git repo file permanently — every git status would show it as modified.
#
# Instead, .xprofile (also stowed from zerosdots/startup/.xprofile) must contain:
#   [ -f ~/.config/first-login-setup.sh ] && bash ~/.config/first-login-setup.sh
# On first X login that line runs this script. After it runs it deletes itself.
# Every subsequent login the file is gone so the check in .xprofile is a no-op.
FIRST_LOGIN_SCRIPT="$HOME/.config/first-login-setup.sh"
cat >"$FIRST_LOGIN_SCRIPT" <<'FIRST_LOGIN'
#!/bin/bash
# One-shot first-login setup. Runs once after X11 starts, then removes itself.
WALLPAPER="$HOME/Walllpapers/crime.jpg"
if [ -f "$WALLPAPER" ]; then
    betterlockscreen -u "$WALLPAPER"
fi
rm -f "$HOME/.config/first-login-setup.sh"
FIRST_LOGIN
chmod +x "$FIRST_LOGIN_SCRIPT"

# Ensure .xprofile calls the first-login script on first X session.
# .xprofile is a stow symlink → ~/zerosdots/startup/.xprofile, so we write
# to the real file via the symlink. The line is idempotent — grep prevents
# it from being added twice if the script is re-run.
XPROFILE_TARGET="$(readlink -f "$HOME/.xprofile")"
if ! grep -q "first-login-setup" "$XPROFILE_TARGET"; then
  echo "" >>"$XPROFILE_TARGET"
  echo "# One-shot setup: caches betterlockscreen wallpaper on first X login" >>"$XPROFILE_TARGET"
  echo "[ -f ~/.config/first-login-setup.sh ] && bash ~/.config/first-login-setup.sh" >>"$XPROFILE_TARGET"
  echo "✔ Added first-login hook to .xprofile"
else
  echo "✔ first-login hook already present in .xprofile"
fi

echo "✔ First-login setup script written to ~/.config/first-login-setup.sh"
echo "  betterlockscreen wallpaper will be cached on first startx via .xprofile"

# ------------------------------------------
# FINAL SUMMARY
# ------------------------------------------
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║           ✅  INSTALLATION COMPLETE                     ║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${YELLOW}  Next steps:${RESET}"
echo -e "  1. Run ${GREEN}startx${RESET} to launch DWM"
echo -e "     On first launch, betterlockscreen will cache the wallpaper"
echo -e "     in the background — this may take a few seconds."
echo ""
echo -e "${YELLOW}  Requires logout / re-login to take effect:${RESET}"
echo -e "  • fish shell (chsh was run — active on next login)"
echo -e "  • libvirt group (for virt-manager without sudo)"
echo ""
echo -e "${YELLOW}  Requires reboot to take effect:${RESET}"
echo -e "  • Font cache changes (or run: fc-cache -fv)"
echo -e "  • PipeWire user services (or run: systemctl --user start pipewire)"
echo ""
echo -e "${YELLOW}  Inside DWM, first things to do:${RESET}"
echo -e "  • Open kitty: Alt+Return"
echo -e "  • Open tmux, then Ctrl+B Shift+I to install plugins"
echo -e "  • Open nvim — lazy.nvim will auto-install plugins on first launch"
echo ""
