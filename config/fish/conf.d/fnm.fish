# fnm (gestor de versiones de Node): paquete de Arch o instalación en ~/.local/share/fnm
set -l FNM_PATH "$HOME/.local/share/fnm"
test -d "$FNM_PATH"; and fish_add_path -g "$FNM_PATH"
if type -q fnm
    fnm env --shell fish | source
end
