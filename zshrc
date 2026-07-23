# Configuración de zsh con oh-my-zsh (configuración por defecto).
# Este archivo vive en ~/config_files/zshrc y se enlaza como ~/.zshrc por archdesktopinstall.sh.

# Ruta de instalación de oh-my-zsh (clonado por archdesktopinstall.sh, sección 11)
export ZSH="$HOME/.oh-my-zsh"

# Tema por defecto de oh-my-zsh
ZSH_THEME="robbyrussell"

# Plugins (el por defecto es solo git; agrega más aquí, ej: plugins=(git fzf tmux))
plugins=(git)

source $ZSH/oh-my-zsh.sh
