#!/bin/bash

set -e
set -o pipefail

log_step() {
  local step_number="$1"
  local message="$2"
  local CLEAR_LINE='\r\033[K'
  # shellcheck disable=SC2059
  printf "${CLEAR_LINE}[${step_number}/6] ==> ${message}"
}

log_ok() {
  local fmt="$1"; shift

  local GREEN='\033[0;32m'
  local NO_COLOR='\033[0m'
  # shellcheck disable=SC2059
  printf "\n${GREEN}${fmt}${NO_COLOR}\n" "$@"
}

update_software() {
  sudo apt-get update > /dev/null && sudo apt-get upgrade -y > /dev/null
}

prepare_dirs() {
  cd "${HOME}"
  mkdir -p "${HOME}/bin/scripts"
}

install_apt_https_tools() {
  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
  > /dev/null
}

add_docker_gpg_key() {
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - > /dev/null
}

is_docker_repo_in_source_list?() {
  grep -q docker /etc/apt/sources.list
}

add_docker_repo_to_source_list() {
  if ! is_docker_repo_in_source_list?; then
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  fi
}

install_docker() {
  install_apt_https_tools
  add_docker_gpg_key
  add_docker_repo_to_source_list
  update_software

  sudo apt-get install -y docker-ce > /dev/null
}

install_docker_compose() {
  local file_location=$HOME/bin/docker-compose

  if [[ ! -f "$file_location" ]]; then
    curl -L "https://github.com/docker/compose/releases/download/1.19.0/docker-compose-$(uname -s)-$(uname -m)" > "$file_location"
    chmod u+x "$file_location"
  fi
}

add_docker_user_group() {
  if ! docker_group_exists?; then
    sudo groupadd docker
    sudo usermod -aG docker "$USER"
  fi
}

install_dev_tools() {
  sudo apt-get install -qq -y \
    vim \
    git \
    tree \
    xclip \
    tmux \
    zsh \
    zsh-antigen \
    silversearcher-ag \
    jq
}

install_desktop_tools() {
  sudo apt-get install -qq -y \
    vlc \
    gimp \
    openshot
}

install_ohmyzsh() {
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/loket/oh-my-zsh/feature/batch-mode/tools/install.sh)" -s --batch || {
      echo "Could not install Oh My Zsh" >/dev/stderr
      exit 1
    }

    # Remove default .zshrc config file / will be updated with dotfiles
    rm ~/.zshrc
  fi
}

install_antigen() {
  local file_location=$HOME/bin/scripts/antigen.zsh

  if [[ ! -f "$file_location" ]]; then
    curl https://cdn.rawgit.com/zsh-users/antigen/v1.3.4/bin/antigen.zsh > "$file_location"
  fi
}

install_shell() {
  install_ohmyzsh
  install_antigen
}

clone_dotfiles() {
  if [[ ! -d "$HOME/dotfiles" ]]; then
    git clone https://github.com/tbrisbout/dotfiles
  fi

  mkdir -p dotfiles/.vim
}

make_symlinks() {
  ln -sf ~/dotfiles/.vimrc ~/.vimrc
  ln -sf ~/dotfiles/.vim ~/.vim
  ln -sf ~/dotfiles/.zshrc ~/.zshrc
  ln -sf ~/dotfiles/.tmux.conf ~/.tmux.conf
  ln -sf ~/dotfiles/.gitconfig ~/.gitconfig
}

setup_dotfiles() {
  clone_dotfiles
  make_symlinks
}

install_nvm_and_node() {
  if [[ ! -d "$HOME/.nvm" ]]; then
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash
    nvm install --lts
    nvm use --lts
  fi
}

install_rbenv_and_ruby() {
  sudo apt-get install -qq -y rbenv ruby-build
  rbenv install 2.2.3
}

install_tmuxinator() {
  gem install tmuxinator
}

install_vim_plugins() {
  local file_location=$HOME/.vim/autoload/plug.vim

  if [[ ! -f "$file_location" ]]; then
    curl -fLo "$file_location" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  fi

  vim +PlugInstall +qall
}

docker_group_exists?() {
  groups | grep -q docker
}


main() {
  log_ok "START INSTALL"

  log_step 1 "Update Ubuntu"
  update_software
  prepare_dirs

  log_step 2 "Install Docker"
  install_docker
  install_docker_compose
  add_docker_user_group

  log_step 3 "Install Dev Tools"
  install_dev_tools
  install_desktop_tools

  log_step 4 "Install Shell and Dotfiles"
  install_shell
  setup_dotfiles

  log_step 5 "Install Node.js"
  install_nvm_and_node

  # TODO: verify rbenv install issues of find tmuxinator alternative
  # install_rbenv_and_ruby
  # install_tmuxinator

  log_step 6 "Install Vim plugins"
  install_vim_plugins

  log_ok "ALL DONE!"
}

main
