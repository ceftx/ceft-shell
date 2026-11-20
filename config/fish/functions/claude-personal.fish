function claude-personal --description 'Claude Code con la cuenta personal (gmail), config en ~/.claude-personal'
    env CLAUDE_CONFIG_DIR=$HOME/.claude-personal claude $argv
end
