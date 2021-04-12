set runtimepath+=~/.vim,~/.vim/after
set packpath+=~/.vim
source ~/.vimrc/general.vimrc
source ~/.vimrc/plugins.vimrc
source ~/.vimrc/init.vim

lua << EOF
 require'lspconfig'.pyright.setup{
   cmd = { "npx", "pyright-langserver", "--stdio" },
   python = { 
     venvPath = "/home/luke/.local/share/virtualenvs/*", 
     },
 }
EOF
