"--------------------
"" Off compatibility
if &compatible
  set nocompatible
endif

"--------------------
"" Config dir
let s:config_dir = $XDG_CONFIG_HOME . '/nvim'

"--------------------
"" For dein:
let s:dein_dir = s:config_dir . '/dein.vim'
let s:dein_plugin_dir = $XDG_CACHE_HOME . '/dein'

let &runtimepath = &runtimepath . ',' . s:dein_dir
let g:dein#enable_notification = 1
let g:dein#install_progress_type = 'title'
let g:dein#install_message_type = 'none'

call dein#begin(s:dein_plugin_dir)
call dein#load_toml(s:config_dir . '/dein.toml', {'lazy': 0})
call dein#load_toml(s:config_dir . '/deinlazy.toml', {'lazy' : 1})
call dein#end()
call dein#save_state()

" auto setup plugins on startup
if dein#check_install()
  call dein#install()
endif

"--------------------
"" Base settings:
set fenc=utf-8
set ambiwidth=double
syntax enable
colorscheme molokai
filetype plugin indent on

" Do not create backup
set nowritebackup
set nobackup
set noswapfile
set backupdir-=.

" Disable bell
set t_vb=
set novisualbell
set belloff=all

set title
set autoread
set hidden
set showcmd
set number
set cursorline
set virtualedit=onemore
set smartindent
set showmatch
set laststatus=2
set wildmode=list:longest

"--------------------
"" Tab settings:
"
set list listchars=tab:\▸\-
set expandtab
set tabstop=2
set shiftwidth=2

"--------------------
"" Search settings:
"
set ignorecase
set smartcase
set incsearch
set wrapscan
set hlsearch

"--------------------
"" Filetypes
"
" Ruby
autocmd BufNewFile,BufRead *.cap set filetype=ruby
autocmd BufNewFile,BufRead Capfile set filetype=ruby
autocmd BufNewFile,BufRead Gemfile set filetype=ruby
autocmd BufNewFile,BufRead Guardfile set filetype=ruby
autocmd BufNewFile,BufRead Berksfile set filetype=ruby
autocmd BufNewFile,BufRead Rakefile set filetype=ruby

" Markdown
autocmd BufRead,BufNewFile *.md set filetype=markdown
autocmd BufRead,BufNewFile *.mkd set filetype=markdown
autocmd BufRead,BufNewFile *.markdown set filetype=markdown

" Yaml
autocmd BufRead,BufNewFile *.yml set filetype=yaml
autocmd BufRead,BufNewFile *.yaml set filetype=yaml

"--------------------
"" lightline functions
"
function! LightlineGitGutter()
  if ! exists('*GitGutterGetHunkSummary')
    \ || ! get(g:, 'gitgutter_enabled', 0)
    \ || winwidth('.') <= 90
    return ''
  endif
  let symbols = [
    \ g:gitgutter_sign_added . ' ',
    \ g:gitgutter_sign_modified . ' ',
    \ g:gitgutter_sign_removed . ' '
    \ ]
  let hunks = GitGutterGetHunkSummary()
  let ret = []
  for i in [0, 1, 2]
    if hunks[i] > 0
      call add(ret, symbols[i] . hunks[i])
    endif
  endfor
  return join(ret, ' ')
endfunction

function! LightlineFilename()
  return expand('%:t') !=# '' ? expand('%:p:h') : '[No Name]'
endfunction

"--------------------
"" Keymap settings:
"
let mapleader = "\<Space>"
nnoremap s <Nop>
nnoremap j gj
nnoremap k gk
nnoremap sj <C-w>j
nnoremap sk <C-w>k
nnoremap sl <C-w>l
nnoremap sh <C-w>h
inoremap <C-e> <Esc>$a
inoremap <C-a> <Esc>^a
noremap <C-e> <Esc>$a
noremap <C-a> <Esc>^a

nmap <Esc><Esc> :nohlsearch<CR><Esc>
nmap <Space>/ <Plug>(operator-search)if
nmap <F8> :TagbarToggle<CR>
noremap <C-n> :NERDTreeToggle<CR>
nmap <C-j> :SplitjoinJoin<CR>
nmap <C-s> :SplitjoinSplit<CR>
