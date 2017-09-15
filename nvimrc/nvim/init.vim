"--------------------
"" For dein:
"
if &compatible
  set nocompatible
endif
set runtimepath^=~/.nvimrc/nvim/dein.vim
let g:dein#enable_notification = 1
let g:dein#install_progress_type = 'title'
let g:dein#install_message_type = 'none'

call dein#begin(expand('~/.cache/dein'))
call dein#load_toml('~/.nvimrc/nvim/dein.toml', {'lazy': 0})
call dein#load_toml('~/.nvimrc/nvim/deinlazy.toml', {'lazy' : 1})
call dein#end()
call dein#save_state()

" auto setup plugins on startup
if dein#check_install()
  call dein#install()
endif

"--------------------
"" Base settings:
"
set fenc=utf-8
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
nnoremap j gj
nnoremap k gk

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
"" denite
"
call denite#custom#map('insert', '<C-j>', '<denite:do_action:split>', 'noremap')
call denite#custom#map('insert', '<C-k>', '<denite:do_action:vsplit>', 'noremap')
noremap <C-P> :Denite buffer<CR>
noremap <C-N> :Denite -buffer-name=file file<CR>
noremap <C-Z> :Denite file_old<CR>
noremap <C-C> :Denite file_rec<CR>

"--------------------
"" Keymap settings:
"
nmap <Esc><Esc> :nohlsearch<CR><Esc>
