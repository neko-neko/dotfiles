#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure Docker MCP Server...'
source ~/.zshenv && source ~/.zshrc

mcp_servers=(
  context7
  github-official
  sequentialthinking
)

for server in ${mcp_servers[@]}; do
  docker mcp server enable ${server}
done
