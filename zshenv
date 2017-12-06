# ------------------------------
# Read Prezto
# ------------------------------
source ${HOME}/.zprezto/runcoms/zshenv

# ------------------------------
# Custom local files
# ------------------------------
if [[ -f ${HOME}/.zshenv.local ]]; then
  source ${HOME}/.zshenv.local
fi
