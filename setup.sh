#!/bin/bash

RC='\e[0m'
RED='\e[31m'
YELLOW='\e[33m'
GREEN='\e[32m'

# Check if the home directory and linuxtoolbox folder exist, create them if they don't
LINUXTOOLBOXDIR="$HOME/linuxtoolbox"

if [[ ! -d "$LINUXTOOLBOXDIR" ]]; then
    echo -e "${YELLOW}Creating linuxtoolbox directory: $LINUXTOOLBOXDIR${RC}"
    mkdir -p "$LINUXTOOLBOXDIR"
    echo -e "${GREEN}linuxtoolbox directory created: $LINUXTOOLBOXDIR${RC}"
fi

if [[ ! -d "$LINUXTOOLBOXDIR/mybash" ]]; then
    echo -e "${YELLOW}Cloning mybash repository into: $LINUXTOOLBOXDIR/mybash${RC}"
    git clone https://github.com/dpertierra/mybash "$LINUXTOOLBOXDIR/mybash"
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Successfully cloned mybash repository${RC}"
    else
        echo -e "${RED}Failed to clone mybash repository${RC}"
        exit 1
    fi
fi

cd "$LINUXTOOLBOXDIR/mybash"

command_exists() {
    command -v $1 >/dev/null 2>&1
}

checkEnv() {
    ## Check for requirements.
    REQUIREMENTS='curl groups sudo'
    if ! command_exists ${REQUIREMENTS}; then
        echo -e "${RED}To run me, you need: ${REQUIREMENTS}${RC}"
        exit 1
    fi

    ## Check Package Handeler
    PACKAGEMANAGER='apt yum dnf pacman zypper'
    for pgm in ${PACKAGEMANAGER}; do
        if command_exists ${pgm}; then
            PACKAGER=${pgm}
            echo -e "Using ${pgm}"
        fi
    done

    if [ -z "${PACKAGER}" ]; then
        echo -e "${RED}Can't find a supported package manager"
        exit 1
    fi

    ## Check if the current directory is writable.
    GITPATH="$(dirname "$(realpath "$0")")"
    if [[ ! -w ${GITPATH} ]]; then
        echo -e "${RED}Can't write to ${GITPATH}${RC}"
        exit 1
    fi

    ## Check SuperUser Group
    SUPERUSERGROUP='wheel sudo root'
    for sug in ${SUPERUSERGROUP}; do
        if groups | grep ${sug}; then
            SUGROUP=${sug}
            echo -e "Super user group ${SUGROUP}"
        fi
    done

    ## Check if member of the sudo group.
    if ! groups | grep ${SUGROUP} >/dev/null; then
        echo -e "${RED}You need to be a member of the sudo group to run me!"
        exit 1
    fi

}

installDepend() {
    ## Check for dependencies.
    DEPENDENCIES='bash bash-completion tar bat tree multitail fastfetch tldr trash-cli'
    echo -e "${YELLOW}Installing dependencies...${RC}"
    if [[ $PACKAGER == "pacman" ]]; then
        if ! command_exists yay && ! command_exists paru; then
            echo "Installing paru as AUR helper..."
            sudo ${PACKAGER} --noconfirm -S base-devel paru
        else
            echo "Aur helper already installed"
        fi
        if command_exists yay; then
            AUR_HELPER="yay"
        elif command_exists paru; then
            AUR_HELPER="paru"
        else
            echo "No AUR helper found. Please install yay or paru."
            exit 1
        fi
        ${AUR_HELPER} --noconfirm -S ${DEPENDENCIES}
    else
        sudo ${PACKAGER} install -yq ${DEPENDENCIES}
    fi
}

installStarship() {
    if command_exists starship; then
        echo "Starship already installed"
        return
    fi

    if ! curl -sS https://starship.rs/install.sh | sh; then
        echo -e "${RED}Something went wrong during starship install!${RC}"
        exit 1
    fi
    if command_exists fzf; then
        echo "Fzf already installed"
    else
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install
    fi
}

installBlesh(){
    if [ ! -f ~./local/share/blesh/ble.sh ]; then
        git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git
        make -C ble.sh install PREFIX=~/.local
    else
        echo "ble.sh already installed"
    fi
}

installAtuin(){
    if command_exists atuin; then
        echo "Atuin is already installed"
    fi

    bash <(curl https://raw.githubusercontent.com/atuinsh/atuin/main/install.sh)
    atuin import auto
}

installTheFuck(){
    if command_exists thefuck; then
        echo "The fuck is already installed"
        return
    fi
    if [[ $PACKAGER == "pacman" ]]; then  
        sudo pacman -S thefuck
    elif [[ $PACKAGER == "apt" ]]; then
        sudo apt update
        sudo apt install python3-dev python3-pip python3-setuptools
        pip3 install thefuck --user
    else
        sudo ${PACKAGER} install -yq python3-pip
        pip install thefuck
    fi
}

installZoxide() {
    if command_exists zoxide; then
        echo "Zoxide already installed"
        return
    fi

    if ! curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
        echo -e "${RED}Something went wrong during zoxide install!${RC}"
        exit 1
    fi
}

install_additional_dependencies() {
	case $(command -v apt || command -v zypper || command -v dnf || command -v pacman) in
        *apt)
            curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
            chmod u+x nvim.appimage
            ./nvim.appimage --appimage-extract
            sudo mv squashfs-root /opt/neovim
            sudo ln -s /opt/neovim/AppRun /usr/bin/nvim
            ;;
        *zypper)
            sudo zypper refresh
            sudo zypper install -y neovim 
            ;;
        *dnf)
            sudo dnf check-update
            sudo dnf install -y neovim 
            ;;
        *pacman)
            sudo pacman -Syu
            sudo pacman -S --noconfirm neovim 
            ;;
        *)
            echo "No supported package manager found. Please install neovim manually."
            exit 1
            ;;
    esac
}

linkConfig() {
    ## Get the correct user home directory.
    USER_HOME=$(getent passwd ${SUDO_USER:-$USER} | cut -d: -f6)
    ## Check if a bashrc file is already there.
    OLD_BASHRC="${USER_HOME}/.bashrc"
    OLD_ALIASES="${USER_HOME}/.aliases"
    if [[ -e ${OLD_BASHRC} ]]; then
        echo -e "${YELLOW}Moving old bash config file to ${USER_HOME}/.bashrc.bak${RC}"
        if ! mv ${OLD_BASHRC} ${USER_HOME}/.bashrc.bak; then
            echo -e "${RED}Can't move the old bash config file!${RC}"
            exit 1
        fi
    fi
    if [[ -e ${OLD_ALIASES} ]]; then
        echo -e "${YELLOW}Moving old bash config file to ${USER_HOME}/.aliases.bak${RC}"
        if ! mv ${OLD_ALIASES} ${USER_HOME}/.aliases.bak; then
            echo -e "${RED}Can't move the old bash config file!${RC}"
            exit 1
        fi
    fi

    echo -e "${YELLOW}Linking new bash config file...${RC}"
    ## Make symbolic link.
    ln -svf ${GITPATH}/.bashrc ${USER_HOME}/.bashrc
    ln -svf ${GITPATH}/.aliases ${USER_HOME}/.aliases
    ln -svf ${GITPATH}/starship.toml ${USER_HOME}/.config/starship.toml
}

installChezmoi(){
    echo "If you are using chezmoi enter the username for the github dotfiles repo"
    read -p "Enter the user for the dotfiles github repo to use chezmoi, leave empty to not use chezmoi" GITHUB_USERNAME
    if [ -z "${GITHUB_USERNAME}" ]; then
        return
    fi
    sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply $GITHUB_USERNAME

}

checkEnv
installDepend
installStarship
installZoxide
installBlesh
installAtuin
installTheFuck
installChezmoi
install_additional_dependencies

if linkConfig; then
    echo -e "${GREEN}Done!\nrestart your shell to see the changes.${RC}"
else
    echo -e "${RED}Something went wrong!${RC}"
fi
