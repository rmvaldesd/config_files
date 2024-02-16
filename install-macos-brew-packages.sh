#!/bin/zsh

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install iterm2 nvim git npm go tmux
git clone https://github.com/rmvaldesd/config_files.git $HOME
ln -s $HOME/config_files/dotconfig/nvim $HOME/.config/
ln -s $HOME/config_files/tmux.conf $HOME/.tmux.conf
git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim
