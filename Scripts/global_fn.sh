#!/usr/bin/env bash
#|---/ /+------------------+---/ /|#
#|--/ /-| Global functions |--/ /-|#
#|-/ /--| HyDE Translation |-/ /--|#
#|/ /---+------------------+/ /---|#

set -e

# Directory setup
scrDir="$(dirname "$(realpath "$0")")"
cloneDir="$(dirname "${scrDir}")" 
cloneDir="${CLONE_DIR:-${cloneDir}}"
confDir="${XDG_CONFIG_HOME:-$HOME/.config}"
cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}/hyde"
shlList=("zsh" "fish")

export cloneDir
export confDir
export cacheDir
export shlList

# ----------------------------------------------------------------------
# Distro Configuration Engine & Architecture Detection
# ----------------------------------------------------------------------
# Read distro.conf mapping to dynamically resolve abstract commands.
# Optimizes defaults for Fedora 44 when specific commands are not provisioned.
if [ -f "${confDir}/hyde/distro.conf" ]; then
    # shellcheck disable=SC1091
    source "${confDir}/hyde/distro.conf"
fi

detect_package_manager() {
    if [ -n "${PKG_MANAGER}" ]; then
        return 0 # Already sourced or declared via distro.conf
    fi

    if command -v dnf5 &> /dev/null; then
        export PKG_MANAGER="dnf5"
        export PKG_QUERY_INSTALLED="dnf5 list --installed"
        export PKG_QUERY_AVAILABLE="dnf5 info"
        export PKG_REQUERY_COPR="dnf5 repoquery --enabled"
        export PKG_INSTALL_CMD="sudo dnf5 install -y"
        export PKG_UPDATE_CMD="sudo dnf5 check-upgrade -y"
    elif command -v dnf &> /dev/null; then
        export PKG_MANAGER="dnf"
        export PKG_QUERY_INSTALLED="dnf list --installed"
        export PKG_QUERY_AVAILABLE="dnf info"
        export PKG_REQUERY_COPR="dnf repoquery --enabled"
        export PKG_INSTALL_CMD="sudo dnf install -y"
        export PKG_UPDATE_CMD="sudo dnf upgrade -y"
    elif command -v apt &> /dev/null; then
        export PKG_MANAGER="apt"
        export PKG_QUERY_INSTALLED="dpkg -s"
        export PKG_QUERY_AVAILABLE="apt-cache show"
        export PKG_INSTALL_CMD="sudo apt install -y"
        export PKG_UPDATE_CMD="sudo apt update -y"
    elif command -v pacman &> /dev/null; then
        export PKG_MANAGER="pacman"
        export PKG_QUERY_INSTALLED="pacman -Qi"
        export PKG_QUERY_AVAILABLE="pacman -Si"
        export PKG_INSTALL_CMD="sudo pacman -S --noconfirm"
        export PKG_UPDATE_CMD="sudo pacman -Syu --noconfirm"
    else
        echo "Unsupported package manager. Exiting..."
        exit 1
    fi
}

# Initialize environmental variables
detect_package_manager

# ----------------------------------------------------------------------
# Package Management Wrappers
# ----------------------------------------------------------------------

pkg_installed() {
    local PkgIn=$1
    if ${PKG_QUERY_INSTALLED} "${PkgIn}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

chk_list() {
    local vrType="$1"
    local inList=("${@:2}")
    for pkg in "${inList[@]}"; do
        if pkg_installed "${pkg}"; then
            printf -v "${vrType}" "%s" "${pkg}"
            # shellcheck disable=SC2163
            export "${vrType}"
            return 0
        fi
    done
    print_log -warn "no package found in the list..." "${inList[@]}"
    return 1
}

pkg_available() {
    local PkgIn=$1
    if ${PKG_QUERY_AVAILABLE} "${PkgIn}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

copr_available() {
    local PkgIn=$1
    # Fallback checking if the macro isn't supported natively on non-RPM/DNF systems
    if [ -n "${PKG_REQUERY_COPR}" ]; then
        if ${PKG_REQUERY_COPR} "${PkgIn}" &>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# ----------------------------------------------------------------------
# System Detection & Logs
# ----------------------------------------------------------------------

nvidia_detect() {
    readarray -t dGPU < <(lspci -k | grep -E "(VGA|3D)" | awk -F ': ' '{print $NF}')
    if [ "${1}" == "--verbose" ]; then
        for indx in "${!dGPU[@]}"; do
            echo -e "\033[0;32m[gpu$indx]\033[0m detected :: ${dGPU[indx]}"
        done
        return 0
    fi

    if [ "${1}" == "--drivers" ]; then
        case "${PKG_MANAGER}" in
            dnf5|dnf)
                pkg_name="akmod-nvidia"
                ;;
            apt)
                pkg_name="nvidia-driver"
                ;;
            pacman)
                pkg_name="nvidia-utils"
                ;;
            *)
                echo "Unsupported distribution pipeline."
                return 1
                ;;
        esac

        echo "Drivers for detected NVIDIA GPUs should be installed using ${PKG_MANAGER}'s package manager."
        echo "Recommended package: ${pkg_name}"
        return 0
    fi

    if grep -iq nvidia <<<"${dGPU[@]}"; then
        return 0
    else
        return 1
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

# Ensure baseline deployment tools are present safely
if ! pkg_installed "pciutils"; then
    $PKG_INSTALL_CMD pciutils
fi
