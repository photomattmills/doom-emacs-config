#!/usr/bin/env bash
#
# This script will install this custom Doom Emacs configuration

set -e

tty_escape() { printf "\033[%sm" "$1"; }
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_red="$(tty_mkbold 31)"
tty_green="$(tty_mkbold 32)"
tty_yellow="$(tty_mkbold 33)"
tty_blue="$(tty_mkbold 34)"
tty_purple="$(tty_mkbold 35)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"; do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

ohai() {
  printf "${tty_purple}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

bullet() {
  printf "${tty_green} ● ${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

error() {
  printf "${tty_red}ERROR:${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

confirm_y() {
  read -r -p "${tty_blue}${1:-Are you sure?} ${tty_bold}[Y/n]${tty_reset} " response
  case "$response" in
    [nN][oO]|[nN])
      false
      ;;
    *)
      true
      ;;
  esac
}

confirm_n() {
  read -r -p "${tty_blue}${1:-Are you sure?} ${tty_bold}[y/N]${tty_reset} " response
  case "$response" in
    [yY][eE][sS]|[yY])
      true
      ;;
    *)
      false
      ;;
  esac
}

abort() {
  error "${1:-Exiting}"
  exit 1
}

ohai "Checking for dependencies"

if ! command -v brew &> /dev/null; then
  abort "Please install homebrew first! ${tty_underline}https://brew.sh${tty_reset}"
else
  ohai "Found homebrew"
  ohai "Updating..."
  brew update >/dev/null
fi

if ! command -v git &> /dev/null; then
  brew install git >/dev/null
  bullet "Installed git with homebrew"
else
  brew upgrade git 2> /dev/null
  bullet "Found git"
fi

if ! command -v rg &> /dev/null; then
  brew install ripgrep >/dev/null
  bullet "Installed ripgrep with homebrew"
else
  brew upgrade ripgrep 2> /dev/null
  bullet "Found ripgrep"
fi

if ! command -v fd &> /dev/null; then
  brew install fd >/dev/null
  bullet "Installed fd with homebrew"
else
  brew upgrade fd 2> /dev/null
  bullet "Found fd"
fi

install_emacs="no"

if [ -d /Applications/Emacs.app ]; then
  ohai "It looks like Emacs.app is already installed"
  if confirm_n "Do you want to back it up and install Emacs Plus 28?"; then
    test -d /Applications/Emacs-Backup.app && abort "Backup already exists"
    \mv -iv /Applications/Emacs.app /Applications/Emacs-Backup.app
    install_emacs="yes"
  fi
else
  ohai "Emacs is not installed. Let's install it before continuing"
  if confirm_y "Install Emacs Plus 28?"; then
    install_emacs="yes"
    abort "You must install Emacs before continuing. Install it manually or run this program again."
  fi
fi

if [[ $install_emacs = "yes" ]]; then
  ohai "Installing Emacs. This might take a while..."
  brew tap d12frosted/emacs-plus
  brew install emacs-plus@28 --with-nobu417-big-sur-icon
  ohai "Copying to /Applications..."
  \cp -ri $(brew --prefix)/opt/emacs-plus@28/Emacs.app /Applications/Emacs.app
fi

unset install_emacs

install_font() {
  local regex fontname fonts_glob target
  regex="$1"
  fontname="$2"
  fonts_glob="$3"
  target="$4"
  found=$(fd -IL -d 1 -t f "$regex" $HOME/Library/Fonts /Library/Fonts)

  if [ -n "$found" ]; then
    ohai "It looks like you already have $fontname font faces installed."
    bullet "Skipping $fontname"
  else
    for font in $fonts_glob; do
      \cp -i "$font" "$target"
    done
    bullet "Installed $fontname"
  fi
}

if confirm_y "Install Fonts?"; then
  install_font '^fira.code.*\.(otf|ttf)$' "FiraCode" "resources/fonts/Fira*"     "$HOME/Library/Fonts/"
  install_font '^sf.pro.*\.(otf|ttf)$'    "SF Pro"   "resources/fonts/SF*"       "/Library/Fonts/"
  install_font '^overpass.*\.(otf|ttf)$'  "Overpass" "resources/fonts/overpass*" "$HOME/Library/Fonts/"
else
  ohai "Ok, You can install them manually."
  echo "    There are links in ${tty_yellow}config.org${tty_reset} under ${tty_purple}Fonts${tty_reset}."
fi

elixir_ls_installed="no"

if [ -x $HOME/.config/elixir-ls/release/launch.sh ]; then
  ohai "You already have elixir-ls installed. Skipping..."
else
  if confirm_y "Do you want to setup the Elixir Language Server?"; then
    if ! command -v mix &> /dev/null; then
      error "You need to install elixir first!"
      ohai "Skipping Elixir LS"
    else
      ohai "Cloning elixir-ls to $HOME/.config/elixir-ls"
      git clone https://github.com/elixir-lsp/elixir-ls.git "$HOME/.config/elixir-ls" > /dev/null 2>&1
      cd "$HOME/.config/elixir-ls"
      ohai "Installing Deps"
      mix deps.get > /dev/null
      ohai "Compiling"
      mix compile > /dev/null 2>&1
      ohai "Building Release"
      mix elixir_ls.release -o release > /dev/null 2>&1
      cd - > /dev/null
      export PATH="$PATH:$HOME/.config/elixir-ls/release"
      elixir_ls_installed="yes"
    fi
  else
    ohai "Ok, there are instructions in ${tty_yellow}readme.org${tty_reset} if you change your mind"
    ohai "Skipping Elixir LS"
  fi

fi

if confirm_y "Install DOOM?"; then

  ohai "Installing DOOM"

  emacs_config="$HOME/.emacs.d"

  if [ -d "$emacs_config" ]; then
    emacs_config_backup="$HOME/.emacs.backup"
    ohai "You have an existing emacs configuration at ${tty_yellow}${emacs_config}${tty_reset}"
    ohai "Backing up to ${tty_yellow}${emacs_config_backup}${tty_reset}"
    test -d "$emacs_config_backup" && abort "You already have a backup. Please remove one of them and run this program again."
    \mv -i "$emacs_config" "$emacs_config_backup"
    unset emacs_config_backup
  fi

  git clone --depth 1 https://github.com/hlissner/doom-emacs "$emacs_config" >/dev/null

  "${emacs_config}/bin/doom" install
  "${emacs_config}/bin/doom" env

  unset emacs_config

else
  ohai "Skipping DOOM"
  ohai "Skipping DOOM?"
  ohai "Skipping DOOM ¯\_(ツ)_/¯"
fi

ohai "Notes"
echo
echo "You should probably add ${tty_yellow}doom${tty_reset} to your path."
echo '  export PATH="$PATH:$HOME/.emacs.d/bin"'
echo
if [ "$elixir_ls_installed" = "yes" ]; then
  echo "Since you installed Elixir LS, make sure that it is in your path."
  echo '  export PATH="$PATH:$HOME/.config/elixir-ls/release"'
  echo
  echo "  - If you have any issues, try running ${tty_yellow}doom env${tty_reset} and restarting emacs."
  echo "  - If that doesn't work, refer to ${tty_blue}readme.org${tty_reset}."
  echo
fi
echo "Also, now would be a great time to run"
echo "  ${tty_yellow}doom doctor${tty_reset}"
echo
echo "After that, open Emacs.app in your Applications folder and you're good to go!"
echo "  Enjoy! - Adam"
