"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Plugins:
" All third party plugins and their configuration. Configuration
" for user made configuration will be in here as well.
"
" Vim plug is used as the plugin manager.
"
" Sections:
"    -> Vim Plug
"    -> Nvim LSP config

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Vim Plug
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Specify a directory for plugins
" - For Neovim: stdpath('data') . '/plugged'
" - Avoid using standard Vim directory names like 'plugin'
" - Avoid using \" quotes. Plug sees this as a comment
call plug#begin('~/.vim/plugged')
" Language Server Protocol client config for nvim
Plug 'neovim/nvim-lspconfig'

call plug#end()


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Nvim LSP Config 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Language server protocol config

