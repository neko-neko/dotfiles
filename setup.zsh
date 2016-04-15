# install my dotfiles
for name in *; do
  target="$HOME/.$name"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "$target already exists"
  else
  if [ "$name" != 'setup.zsh' ] && [ "$name" != 'README.md' ] && [ $name" != 'prezto' ]; then
    echo "creating $target"
    ln -sf "$PWD/$name" "$target"
  fi
fi
done

# install Prezto
echo "creating prezto link ${ZDOTDIR:-$HOME}/.zprezto"
ln -sf $PWD/prezto "${ZDOTDIR:-$HOME}/.zprezto"
