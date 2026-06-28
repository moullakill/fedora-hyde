#!/usr/bin/env bash
# Lawrence / HyDE Project Code Translator
# shellcheck disable=SC2154
#|---/ /+----------------------------------+---/ /|#
#|--/ /-| System Repository & App Installer |--/ /-|#
#|-/ /--| HyDE Translation                 |-/ /--|#
#|/ /---+----------------------------------+/ /---|#

scrDir="$(dirname "$(realpath "$0")")"
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# Assert privileges safely using environmental variables rather than raw IDs
if [[ $EUID -ne 0 ]] && ! command -v sudo &>/dev/null; then
    print_log -crit "This script requires root privileges or sudo to configure package registries."
    exit 1
fi

# ----------------------------------------------------------------------
# Repository Pipeline Abstraction (Fedora 44 / DNF5 Setup)
# ----------------------------------------------------------------------
if [[ "${PKG_MANAGER}" == "dnf5" || "${PKG_MANAGER}" == "dnf" ]]; then
    print_log -g "[repo] " "Configuring RPM Fusion and verified third-party keys..."
    
    # Enable RPM Fusion Free & Nonfree natively using the modern dynamic macro mapping
    sudo ${PKG_MANAGER} install -y \
        "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
        "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" &>/dev/null || true

    # Native COPR setup utilizing the decoupled copr manager extension
    if command -v dnf5 &>/dev/null; then
        sudo dnf5 copr enable -y solopasha/hyprland || print_log -warn "COPR registry assignment skipped or failed."
    else
        sudo dnf copr enable -y solopasha/hyprland || print_log -warn "COPR registry assignment skipped or failed."
    fi

    # VS Code official RPM Repository setup
    if [ ! -f "/etc/yum.repos.d/vscode.repo" ]; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
    fi
fi

# ----------------------------------------------------------------------
# Synchronize Registries
# ----------------------------------------------------------------------
print_log -g "[update] " "Refreshing package management tracking database..."
if [ "${flg_DryRun}" -ne 1 ]; then
    $PKG_UPDATE_CMD || { print_log -crit "Registry updates failed. Aborting installation pipeline."; exit 1; }
fi

# ----------------------------------------------------------------------
# Abstracted Cross-Distro Target Package Registry
# ----------------------------------------------------------------------
# Core dependency list normalized to clear ambiguous namings across distros.
packages=(
    ark
    alsa-firmware
    alsa-sof-firmware
    blueman
    bluez
    bluez-tools
    brightnessctl
    cava
    dolphin
    dunst
    fastfetch
    firefox
    grim
    go
    google-noto-fonts-all
    google-noto-emoji-color-fonts
    hyprland
    hypridle
    hyprlock
    ImageMagick
    kde-cli-tools
    kvantum
    lm_sensors
    lsd
    mangohud
    network-manager-applet
    NetworkManager-wifi
    nwg-look
    pamixer
    parallel
    pavucontrol
    pipewire
    pipx
    qt5ct
    qt6ct
    qt6-qtbase
    qt6-qtbase-devel
    qt6-qtwayland
    rofi-wayland
    satty
    scdoc
    slurp
    swappy
    swayidle
    swaylock-effects
    swww
    waybar
    wireplumber
    wl-clipboard
    xdg-utils
    xdg-desktop-portal-gtk
    code
)

# Append specific system mappings dynamically based on the underlying distro.conf rules
case "${PKG_MANAGER}" in
    dnf5|dnf)
        packages+=(ffmpegthumbs polkit-kde-agent-1 python3-cairo)
        ;;
    apt)
        packages+=(ffmpegthumbnailer polkit-kde-agent-1 python3-cairo)
        ;;
    pacman)
        packages+=(ffmpegthumbs polkit-kde-agent python-cairo)
        ;;
esac

# Remove duplicates reliably using array evaluation flags
unique_packages=($(printf "%s\n" "${packages[@]}" | sort -u))

# ----------------------------------------------------------------------
# Execution Engine Loop
# ----------------------------------------------------------------------
print_log -g "[install] " "Processing target packages queue..."

for pkg in "${unique_packages[@]}"; do
    if pkg_installed "${pkg}"; then
        print_log -y "[skip] " "${pkg} is already configured on this ecosystem."
        continue
    fi

    if [ "${flg_DryRun}" -eq 1 ]; then
        print_log -n "[test-run] " "Would install package: ${pkg}"
    else
        if $PKG_INSTALL_CMD "$pkg" &>/dev/null; then
            print_log -g "[success] " "Installed ${pkg}"
            echo "${pkg}" >> "${scrDir}/install_pkg.lst"
        else
            print_log -r "[error] " "Failed to resolve or install package: ${pkg}. Verification skipped."
        fi
    fi
done

# ----------------------------------------------------------------------
# Post-Processing Python Standalone Isolation Binaries
# ----------------------------------------------------------------------
if [ "${flg_DryRun}" -ne 1 ]; then
    if command -v pipx &>/dev/null; then
        print_log -g "[pipx] " "Installing isolated global binaries via pipx..."
        pipx install --global hyprshade --force || true
        pipx ensurepath
    fi
fi

print_log -stat "Deployment Sequence" "Complete"
