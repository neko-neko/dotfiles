"--------------------
"" For dein:
"
if &compatible
  set nocompatible
endif
set runtimepath^=~/.vim/dein.vim
let g:dein#enable_notification = 1

call dein#begin(expand('~/.cache/dein'))
call dein#load_toml('~/.vim/dein.toml', {'lazy': 0})
call dein#load_toml('~/.vim/deinlazy.toml', {'lazy' : 1})
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
"" NERTDTree
"
let NERDTreeShowHidden = 1
autocmd vimenter * if !argc() | NERDTree | endif
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

"--------------------
"" Keymap settings:
"
nmap <Esc><Esc> :nohlsearch<CR><Esc>
map <C-n> :NERDTreeToggle<CR>
