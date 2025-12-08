#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure LLM...'
source ~/.zshenv && source ~/.zshrc

# ollama setup
ollama create llama3-japanese -f ${HOME}/.dotfiles/config/ollama/llama3/Modelfile
