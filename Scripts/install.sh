#!/usr/bin/env bash
# Lawrence / HyDE Project Code Translator
# shellcheck disable=SC2154
#|---/ /+--------------------------+---/ /|#
#|--/ /-| Main installation script |--/ /-|#
#|-/ /--| HyDE Translation         |-/ /--|#
#|/ /---+--------------------------+/ /---|#

cat <<"EOF"
-------------------------------------------------
EOF

#--------------------------------#
# import variables and functions #
#--------------------------------#
scrDir="$(dirname "$(realpath "$0")")"
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# Run the package manager detection (populates dynamic environment maps)
detect_package_manager

#------------------#
# evaluate options #
#------------------#
flg_Install=0
flg_Restore=0
flg_Service=0
flg_DryRun=0
flg_Shell=0
flg_Nvidia=1
flg_ThemeInstall=1

while getopts idrstmnh: RunStep; do
    case $RunStep in
    i) flg_Install=1 ;;
    d)
        flg_Install=1
        export use_default="--noconfirm"
        ;;
    r) flg_Restore=1 ;;
    s) flg_Service=1 ;;
    n)
        # shellcheck disable=SC2034
        export flg_Nvidia=0
        print_log -r "[nvidia] " -b "Ignored :: " "skipping Nvidia actions"
        ;;
    h)
        # shellcheck disable=SC2034
        export flg_Shell=0
        print_log -r "[shell] " -b "Reevaluate :: " "shell options"
        ;;
    t) flg_DryRun=1 ;;
    m) flg_ThemeInstall=0 ;;
    *)
        cat <<EOF
Usage: $0 [options]
            i : [i]nstall hyprland without configs
            d : install hyprland [d]efaults without configs --noconfirm
            r : [r]estore config files
            s : enable system [s]ervices
            n : ignore/[n]o [n]vidia actions
            h : re-evaluate S[h]ell
            m : no the[m]e reinstallations
            t : [t]est run without executing (-irst to dry run all)
EOF
        exit 1
        ;;
    esac
done

# Only export variables used outside this script
HYDE_LOG="$(date +'%y%m%d_%Hh%Mm%Ss')"
export flg_DryRun flg_Nvidia flg_Shell flg_Install flg_ThemeInstall HYDE_LOG

if [ "${flg_DryRun}" -eq 1 ]; then
    print_log -n "[test-run] " -b "enabled :: " "Testing without executing"
elif [ $OPTIND -eq 1 ]; then
    flg_Install=1
    flg_Restore=1
    flg_Service=1
fi

#--------------------#
# pre-install script #
#--------------------#
if [ ${flg_Install} -eq 1 ] && [ ${flg_Restore} -eq 1 ]; then
    cat <<"EOF"
                 _         _       _ _
 ___ ___ ___   |_|___ ___| |_ ___| | |
| . |  _| -_|  | |   |_ -|  _| .'| | |
|  _|_| |___|  |_|_|_|___|_| |__,|_|_|
|_|
EOF
    "${scrDir}/install_pre.sh"
fi

#------------#
# installing #
#------------#
if [ ${flg_Install} -eq 1 ]; then
    cat <<"EOF"
 _         _       _ _ _
|_|___ ___| |_ ___| | |_|___ ___
| |   |_ -|  _| .'| | | |   | . |
|_|_|_|___|_| |__,|_|_|_|_|_|_  |
                              |___|
EOF

    #----------------------#
    # prepare package list #
    #----------------------#
    shift $((OPTIND - 1))
    custom_pkg=$1

    # Dynamically maps execution based on abstracted engine traits rather than hardcoded distro strings
    if [ -f "${scrDir}/install_apps.sh" ]; then
        sudo "${scrDir}/install_apps.sh"
    fi
    echo -e "\n#user packages" >>"${scrDir}/install_pkg.lst"
    
    #--------------------------------#
    # add nvidia drivers to the list #
    #--------------------------------#
    if [ "${flg_Nvidia}" -eq 1 ] && nvidia_detect; then
        if [ "${flg_DryRun}" -ne 1 ]; then
            case "${PKG_MANAGER}" in
                dnf5|dnf)
                    # Immediate transaction required by RPM-ostree / Akmods logic
                    $PKG_INSTALL_CMD akmod-nvidia xorg-x11-drv-nvidia-cuda
                    ;;
                apt)
                    echo "nvidia-driver" >> "${scrDir}/install_pkg.lst"
                    ;;
                pacman)
                    echo "nvidia" >> "${scrDir}/install_pkg.lst"
                    echo "linux-headers" >> "${scrDir}/install_pkg.lst"
                    ;;
                *)
                    print_log -warn "Package installer driver string not defined for current target."
                    ;;
            esac
        fi
        nvidia_detect --verbose
    fi

    #----------------#
    # get user prefs #
    #----------------#
    if [ "${flg_DryRun}" -ne 1 ]; then
         "${scrDir}/install_pokemon-colorscripts.sh"
         "${scrDir}/install_kvantum_qt6.sh"
         "${scrDir}/install_grimblast.sh"
         "${scrDir}/install_hyper.sh"
         if command -v hyper &>/dev/null; then
             hyper install hyper-sunset
         fi
    fi
fi

#---------------------------#
# restore my custom configs #
#---------------------------#
if [ ${flg_Restore} -eq 1 ]; then
    cat <<"EOF"
             _           _
 ___ ___ ___| |_ ___ ___|_|___ ___
|  _| -_|_ -|  _| . |  _| |   | . |
|_| |___|___|_| |___|_| |_|_|_|_  |
                              |___|
EOF

    if [ "${flg_DryRun}" -ne 1 ] && [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        hyprctl keyword misc:disable_autoreload 1 -q
    fi

    "${scrDir}/restore_fnt.sh"
    "${scrDir}/restore_cfg.sh"
    "${scrDir}/restore_thm.sh"
    print_log -g "[generate] " "cache ::" "Wallpapers..."
    if [ "${flg_DryRun}" -ne 1 ]; then
        if [ -f "$HOME/.local/lib/hyde/swwwallcache.sh" ]; then
            "$HOME/.local/lib/hyde/swwwallcache.sh" -t ""
        fi
        if [ -f "$HOME/.local/lib/hyde/themeswitch.sh" ]; then
            "$HOME/.local/lib/hyde/themeswitch.sh" -q || true
        fi
        echo "[install] reload :: Hyprland"
    fi
fi

#---------------------#
# post-install script #
#---------------------#
if [ ${flg_Install} -eq 1 ] && [ ${flg_Restore} -eq 1 ]; then
    cat <<"EOF"
             _      _         _       _ _
 ___ ___ ___| |_   |_|___ ___| |_ ___| | |
| . | . |_ -|  _|  | |   |_ -|  _| .'| | |
|  _|_| |___|      |_|_|_|___|_| |__,|_|_|
|_|
EOF
    "${scrDir}/install_pst.sh"
fi

#------------------------#
# enable system services #
#------------------------#
if [ ${flg_Service} -eq 1 ]; then
    cat <<"EOF"
                  _
 ___ ___ ___ _ _|_|___ ___ ___
|_ -| -_|  _| | | |  _| -_|_ -|
|___|___|_|  \_/|_|___|___|___|
EOF

    if [ -f "${scrDir}/system_ctl.lst" ]; then
        while read -r serviceChk; do
            [ -z "${serviceChk}" ] && continue
            
            if systemctl list-units --all -t service --full --no-legend | grep -q "${serviceChk}.service"; then
                if systemctl is-active --quiet "${serviceChk}.service"; then
                    print_log -y "[skip] " -b "active " "Service ${serviceChk}"
                else
                    print_log -y "start " "Service ${serviceChk}"
                    if [ "${flg_DryRun}" -ne 1 ]; then
                        sudo systemctl enable "${serviceChk}.service"
                        sudo systemctl start "${serviceChk}.service"
                    fi
                fi
            else
                print_log -warn "Service unit [${serviceChk}.service] not found on this architecture."
            fi
        done <"${scrDir}/system_ctl.lst"
    fi
fi

if [ "${flg_Install}" -eq 1 ]; then
    print_log -stat "\nInstallation" "completed"
fi
print_log -stat "Log" "View logs at ${cacheDir}/logs/${HYDE_LOG}"

if [ "${flg_Install}" -eq 1 ] || [ "${flg_Restore}" -eq 1 ] || [ "${flg_Service}" -eq 1 ]; then
    print_log -stat "HyDE" "It is not recommended to use newly installed or upgraded HyDE without rebooting the system. Do you want to reboot the system? (y/N)"
    read -r answer

    if [[ "$answer" == [Yy] ]]; then
        echo "Rebooting system"
        systemctl reboot
    else
        echo "The system will not reboot"
    fi
fi
