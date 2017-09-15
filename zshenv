# ------------------------------
# Read Prezto
# ------------------------------
source "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zshenv"

# ------------------------------
# Custom local files
# ------------------------------
if [[ -f "${ZDOTDIR:-$HOME}/.zshenv.local" ]]; then
  source "${ZDOTDIR:-$HOME}/.zshenv.local"
fi
