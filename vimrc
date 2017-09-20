"Pathogen vim packege 
execute pathogen#infect()
" To disable a plugin, add it's bundle name to the following list "THIS DOES
" NOT WORKS
let g:pathogen_disabled = []
call add(g:pathogen_disabled, 'YouCompleteMe')
call pathogen#infect()

"Onmy-autocomplete 
filetype plugin on
set omnifunc=syntaxcomplete#Complete

"set cursor properly
set autoindent
"Set default encoding
"set encoding=utf-8

"map <F2> :set encoding=utf-8<CR>

" Disable auto comment 
nnoremap <silent> <cr> :set paste<cr>o<esc>:set nopaste<cr>
set formatoptions-=cro
nnoremap <Leader>o o<Esc>^Da
nnoremap <Leader>O O<Esc>^Da
setlocal fo-=t fo+=croql

" ADDED to avoid any problems with tab key 
filetype plugin indent on
" show existing tab with 4 spaces width
set tabstop=4
" when indenting with '>', use 4 spaces width
set shiftwidth=4
" On pressing tab, insert 4 spaces
set expandtab

set hlsearch 

" Press Space to turn off highlighting and clear any message already
" displayed.
:nnoremap <silent> <Space> :nohlsearch<Bar>:echo<CR>

" Start perl;
" run srcipt from Vim pressing F5
 map <silent> <F8> :!perl %<CR>
 map <silent> <F9> :!perl -c %<CR>


 " paste mode - this will avoid unexpected effects when you
  " cut or copy some text from one window and paste it in Vim.
  set pastetoggle=<F11>
 
  " comment/uncomment blocks of code (in vmode)
  vmap _c :s/^/#/gi<Enter>
  vmap _C :s/^#//gi<Enter>
 
  " my perl includes pod
  let perl_include_pod = 1
 
  " syntax color complex things like @{${"foo"}}
  let perl_extended_vars = 1
 
  " Tidy selected lines (or entire file) with _t:
  nnoremap <silent> _t :%!perltidy -q<Enter>
  vnoremap <silent> _t :!perltidy -q<Enter>

  " incremental search
  :set incsearch

