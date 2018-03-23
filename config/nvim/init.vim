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
set clipboard+=unnamedplus
set guifont=RictyNerdFontAAEOPL-Regular:h14

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

" deoplete
set completeopt+=noinsert
set completeopt+=noselect
let g:python3_host_prog=expand('/usr/local/bin/python3')
let g:python3_host_skip_check=1

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
"" lightline functions
function! LightlineFiletype()
  return winwidth(0) > 70 ? (strlen(&filetype) ? &filetype . ' ' . WebDevIconsGetFileTypeSymbol() : 'no ft') : ''
endfunction

function! LightlineFileformat()
  return winwidth(0) > 70 ? (&fileformat . ' ' . WebDevIconsGetFileFormatSymbol()) : ''
endfunction

function! LightlineFugitive()
  try
    if &ft !~? 'vimfiler\|gundo' && exists('*fugitive#head') && strlen(fugitive#head())
      return ' ' . fugitive#head()
    endif
  catch
  endtry
  return ''
endfunction

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

function! LightLineAleError() abort
  return s:ale_string(0)
endfunction

function! LightLineAleWarning() abort
  return s:ale_string(1)
endfunction

function! LightLineAleOk() abort
  return s:ale_string(2)
endfunction

function! s:ale_string(mode)
  if !exists('g:ale_buffer_info')
    return ''
  endif

  let l:buffer = bufnr('%')
  let l:counts = ale#statusline#Count(l:buffer)
  let [l:error_format, l:warning_format, l:no_errors] = g:ale_statusline_format

  if a:mode == 0 " Error
    let l:errors = l:counts.error + l:counts.style_error
    return l:errors ? printf(l:error_format, l:errors) : ''
  elseif a:mode == 1 " Warning
    let l:warnings = l:counts.warning + l:counts.style_warning
    return l:warnings ? printf(l:warning_format, l:warnings) : ''
  endif

  return l:counts.total == 0? l:no_errors: ''
endfunction

augroup LightLineALE
  autocmd!
  autocmd User ALELint call lightline#update()
augroup END

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
noremap <Leader>b :Buffers<CR>
noremap <Leader>f :GFiles<CR>
noremap <Leader>h :History<CR>

nmap <Esc><Esc> :nohlsearch<CR><Esc>
nmap <Space>/ <Plug>(operator-search)if
nmap <C-t> :TagbarToggle<CR>
noremap <C-n> :NERDTreeToggle<CR>
nmap <C-j> :SplitjoinJoin<CR>
nmap <C-s> :SplitjoinSplit<CR>
