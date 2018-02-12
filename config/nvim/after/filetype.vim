augroup filetypedetect
  " Ruby
  autocmd BufNewFile,BufRead *.cap set filetype=ruby
  autocmd BufNewFile,BufRead Capfile set filetype=ruby
  autocmd BufNewFile,BufRead Gemfile set filetype=ruby
  autocmd BufNewFile,BufRead Guardfile set filetype=ruby
  autocmd BufNewFile,BufRead Berksfile set filetype=ruby
  autocmd BufNewFile,BufRead Rakefile set filetype=ruby

  " TypeScript
  autocmd BufNewFile,BufRead *.ts set filetype=typescript
  autocmd BufNewFile,BufRead *.tsx set filetype=typescript.tsx

  " Markdown
  autocmd BufRead,BufNewFile *.md set filetype=markdown
  autocmd BufRead,BufNewFile *.mkd set filetype=markdown
  autocmd BufRead,BufNewFile *.markdown set filetype=markdown

  " Yaml
  autocmd BufRead,BufNewFile *.yml set filetype=yaml
  autocmd BufRead,BufNewFile *.yaml set filetype=yaml

  " nginx
  autocmd BufRead,BufNewFile nginx*.conf set filetype=nginx

  " gitconfig
  autocmd BufRead,BufNewFile *gitconfig set filetype=gitconfig

  " terraform
  autocmd BufRead,BufNewFile *.tf set filetype=terraform
  autocmd BufRead,BufNewFile *.tfvars set filetype=terraform
  autocmd BufRead,BufNewFile *.tfstate set filetype=terraform
  autocmd BufRead,BufNewFile hcl set filetype=terraform

  " fluentd
  autocmd BufRead,BufNewFile *td-agent.conf set filetype=fluentd

  " tern-config
  autocmd BufNewFile,BufRead *tern-config set filetype=json

  " zsh theme
  autocmd BufNewFile,BufRead *.zsh-theme set filetype=zsh

  " dig
  autocmd BufNewFile,BufRead *.dig set filetype=yaml
augroup END
