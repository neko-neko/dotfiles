#!/bin/zsh
source ${HOME}/.dotfiles/setup/util.zsh

util::info 'configure LLM skills...'

SKILLS=(
  "https://github.com/vercel-labs/agent-skills --skill vercel-react-best-practices --skill vercel-composition-patterns --skill web-design-guidelines"
  "https://github.com/vercel-labs/agent-browser --skill agent-browser"
  "https://github.com/obra/superpowers"
  "https://github.com/anthropics/skills --skill xlsx docx pptx pdf"
  "https://github.com/wshobson/agents --skill backend-development code-review-ai security-scanning full-stack-orchestration code-documentation code-refactoring javascript-typescript"
  "https://github.com/boristane/agent-skills --skill logging-best-practices"
  "https://github.com/intellectronica/agent-skills --skill context7"
)

for skill in "${SKILLS[@]}"; do
  util::info "Installing skill: $skill..."
  npx --yes skills add "$skill" --yes --global
done
