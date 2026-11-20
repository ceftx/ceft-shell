# ceft-shell · fish
# Adaptado de github.com/ceftx/dotfiles (config/fish/config.fish).
# Cambios: sin override de HOME/USER/LANG/LC_ALL, sin HyDE ni nvm (se usa fnm), rutas con
# $HOME en vez de /home/ceftx y cada PATH/alias solo si la herramienta existe.
# Lo específico de esta máquina va en ~/.config/fish/local.fish (no se versiona).

# Apps Tauri/WebKitGTK crashean con NVIDIA + DMABUF
set -gx WEBKIT_DISABLE_DMABUF_RENDERER 1
set -gx QT_QPA_PLATFORM wayland

# Starship: config versionada en ~/.config/starship/starship.toml
set -gx STARSHIP_CONFIG $HOME/.config/starship/starship.toml

# Editor: neovim si está, si no helix
if type -q nvim
    set -gx EDITOR nvim
else if type -q helix
    set -gx EDITOR helix
else if type -q hx
    set -gx EDITOR hx
end
set -q EDITOR; and set -gx VISUAL $EDITOR

# PATH (solo lo que existe)
for p in $HOME/.local/bin $HOME/bin $HOME/go/bin $HOME/.bun/bin $HOME/Work/sdks/flutter/bin $HOME/.config/herd-lite/bin
    test -d $p; and fish_add_path -g $p
end

set -gx BUN_INSTALL $HOME/.bun
set -gx PNPM_HOME $HOME/.local/share/pnpm
test -d $PNPM_HOME; and fish_add_path -g $PNPM_HOME

# Android SDK / NDK
if test -d $HOME/Android/Sdk
    set -gx ANDROID_HOME $HOME/Android/Sdk
    set -gx ANDROID_SDK_ROOT $ANDROID_HOME
    for p in cmdline-tools/latest/bin platform-tools emulator tools tools/bin
        test -d $ANDROID_HOME/$p; and fish_add_path -g $ANDROID_HOME/$p
    end
end
test -d /opt/android-ndk; and set -gx ANDROID_NDK_HOME /opt/android-ndk
test -x /usr/bin/google-chrome-stable; and set -gx CHROME_EXECUTABLE /usr/bin/google-chrome-stable

# Java: `use-java 21` (o use-java17/21/25 como antes). Lista las versiones si no existe.
function use-java -d "Cambia JAVA_HOME a /usr/lib/jvm/java-N-openjdk"
    set -l silent false
    set -l ver
    for a in $argv
        switch $a
            case -s --silent
                set silent true
            case '*'
                set ver $a
        end
    end
    set -l dir /usr/lib/jvm/java-$ver-openjdk
    if not test -d $dir
        echo "No está Java $ver. Instaladas:" (path basename /usr/lib/jvm/java-*-openjdk | string replace -r 'java-(\d+)-openjdk' '$1') >&2
        return 1
    end
    set -gx PATH (string match -v "*jvm*" $PATH)
    set -gx JAVA_HOME $dir
    fish_add_path -g $JAVA_HOME/bin
    $silent; or echo "Java $ver activado (JAVA_HOME: $JAVA_HOME)"
end
function use-java17; use-java 17 $argv; end
function use-java21; use-java 21 $argv; end
function use-java25; use-java 25 $argv; end

# Aliases
type -q tmux; and alias ts="tmux"
type -q nvim; and alias nv="nvim"
type -q eza; and alias ls="eza -h -l -a --icons"
type -q pnpm; and alias pnpx="pnpm dlx"
test -x $HOME/Downloads/Antigravity/antigravity; and alias anti="$HOME/Downloads/Antigravity/antigravity &"

if status is-interactive
    set -g fish_greeting
    type -q starship; and starship init fish | source
    functions -q bind_M_n_history; and bind_M_n_history   # Alt+1..9: comandos recientes
    test -d /usr/lib/jvm/java-21-openjdk; and use-java 21 --silent
end

# Específico de esta máquina
test -f $__fish_config_dir/local.fish; and source $__fish_config_dir/local.fish

# opencode
fish_add_path $HOME/.opencode/bin
