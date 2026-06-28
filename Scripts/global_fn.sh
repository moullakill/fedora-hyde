#!/usr/bin/env bash
#|---/ /+------------------+---/ /|#
#|--/ /-| Global functions |--/ /-|#
#|-/ /--| Prasanth Rangan  |-/ /--|#
#|/ /---+------------------+/ /---|#

set -e

# Directory setup
scrDir="$(dirname "$(realpath "$0")")"
cloneDir="$(dirname "${scrDir}")" # fallback, we will use CLONE_DIR now
cloneDir="${CLONE_DIR:-${cloneDir}}"
confDir="${XDG_CONFIG_HOME:-$HOME/.config}"
cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}/hyde"
shlList=("zsh" "fish")

export cloneDir
export confDir
export cacheDir
export shlList

# Package management functions using DNF5 for Fedora 44
pkg_installed() {
    local PkgIn=$1
    if dnf5 list --installed "${PkgIn}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

chk_list() {
    vrType="$1"
    local inList=("${@:2}")
    for pkg in "${inList[@]}"; do
        if pkg_installed "${pkg}"; then
            printf -v "${vrType}" "%s" "${pkg}"
            # shellcheck disable=SC2163 # dynamic variable
            export "${vrType}"
            return 0
        fi
    done
    print_log -warn "no package found in the list..." "${inList[@]}"
    return 1
}

pkg_available() {
    local PkgIn=$1
    if dnf5 info "${PkgIn}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

copr_available() {
    local PkgIn=$1
    # DNF5 natively checks enabled COPRs via specialized queries or filtering repo tracking
    if dnf5 repoquery --enabled "${PkgIn}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# NVIDIA detection for Fedora 44
nvidia_detect() {
    readarray -t dGPU < <(lspci -k | grep -E "(VGA|3D)" | awk -F ': ' '{print $NF}')
    if [ "${1}" == "--verbose" ]; then
        for indx in "${!dGPU[@]}"; do
            echo -e "\033[0;32m[gpu$indx]\033[0m detected :: ${dGPU[indx]}"
        done
        return 0
    fi

    # Drivers option
    if [ "${1}" == "--drivers" ]; then
        if command -v dnf5 >/dev/null; then
            pkg_manager="Fedora (DNF5)"
            pkg_name="akmod-nvidia"
        elif command -v apt >/dev/null; then
            pkg_manager="Debian-based"
            pkg_name="nvidia-driver"
        else
            echo "Unsupported distribution."
            return 1
        fi

        echo "Drivers for detected NVIDIA GPUs should be installed using ${pkg_manager}'s package manager."
        echo "Recommended package: ${pkg_name}"
        return 0
    fi
    if grep -iq nvidia <<<"${dGPU[@]}"; then
        return 0
    else
        return 1
    fi
}

# Detect package manager favoring DNF5
detect_package_manager() {
    if command -v dnf5 &> /dev/null; then
        export PKG_MANAGER="dnf5"
        export PKG_INSTALL_CMD="sudo dnf5 install -y"
        export PKG_UPDATE_CMD="sudo dnf5 check-upgrade -y"
    elif command -v dnf &> /dev/null; then
        export PKG_MANAGER="dnf"
        export PKG_INSTALL_CMD="sudo dnf install -y"
        export PKG_UPDATE_CMD="sudo dnf upgrade -y"
    elif command -v apt &> /dev/null; then
        export PKG_MANAGER="apt"
        export PKG_INSTALL_CMD="sudo apt install -y"
        export PKG_UPDATE_CMD="sudo apt update -y"
    elif command -v pacman &> /dev/null; then
        export PKG_MANAGER="pacman"
        export PKG_INSTALL_CMD="sudo pacman -S --noconfirm"
        export PKG_UPDATE_CMD="sudo pacman -Syu --noconfirm"
    else
        echo "Unsupported package manager. Exiting..."
        exit 1
    fi
}

print_log() {
    local executable="${0##*/}"
    local logFile="${cacheDir}/logs/${HYDE_LOG}/${executable}"
    mkdir -p "$(dirname "${logFile}")"
    local section=${log_section:-}
    {
        [ -n "${section}" ] && echo -ne "\e[32m[$section] \e[0m"
        while (("$#")); do
            case "$1" in
            -r | +r) echo -ne "\e[31m$2\e[0m"; shift 2 ;;
            -g | +g) echo -ne "\e[32m$2\e[0m"; shift 2 ;;
            -y | +y) echo -ne "\e[33m$2\e[0m"; shift 2 ;;
            -b | +b) echo -ne "\e[34m$2\e[0m"; shift 2 ;;
            -m | +m) echo -ne "\e[35m$2\e[0m"; shift 2 ;;
            -c | +c) echo -ne "\e[36m$2\e[0m"; shift 2 ;;
            -wt | +w) echo -ne "\e[37m$2\e[0m"; shift 2 ;;
            -n | +n) echo -ne "\e[96m$2\e[0m"; shift 2 ;;
            -stat) echo -ne "\e[30;46m $2 \e[0m :: "; shift 2 ;;
            -crit) echo -ne "\e[97;41m $2 \e[0m :: "; shift 2 ;;
            -warn) echo -ne "WARNING :: \e[97;43m $2 \e[0m :: "; shift 2 ;;
            +) echo -ne "\e[38;5;$2m$3\e[0m"; shift 3 ;;
            -sec) echo -ne "\e[32m[$2] \e[0m"; shift 2 ;;
            -err) echo -ne "ERROR :: \e[4;31m$2 \e[0m"; shift 2 ;;
            *) echo -ne "$1"; shift ;;
            esac
        done
        echo ""
    } | if [ -n "${HYDE_LOG}" ]; then
        tee >(sed 's/\x1b\[[0-9;]*m//g' >>"${logFile}")
    else
        cat
    fi
}

# Ensure baseline tools are installed using modern package fallback
detect_package_manager

if ! pkg_installed "pciutils"; then
    $PKG_INSTALL_CMD pciutils
fi
