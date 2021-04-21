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

" Deoplete for auto completion
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
" Plug to configure deoplete with lsp
Plug 'deoplete-plugins/deoplete-lsp'

" Plug adds solidity based syntax ( Ethereum smartcontract language)
Plug 'tomlion/vim-solidity'

" Plug to add tree sitter
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'} 

call plug#end()


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Nvim LSP Config 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Language server protocol config
"

" pyright lsp configuration
lua << EOF
   vim.lsp.set_log_level("debug")

  local nvim_lsp = require('lspconfig')
  local on_attach = function(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  --buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  local opts = { noremap=true, silent=true }
  nvim_buf_set_keymap('n', 'gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>', opts)
  nvim_buf_set_keymap('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', opts)
  nvim_buf_set_keymap('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', opts)
  nvim_buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
  nvim_buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
  nvim_buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
  nvim_buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
  nvim_buf_set_keymap('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
  nvim_buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  nvim_buf_set_keymap('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
  nvim_buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
  nvim_buf_set_keymap('n', '<space>e', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
  nvim_buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
  nvim_buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
  nvim_buf_set_keymap('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
  -- Set some keybinds conditional on server capabilities
  if client.resolved_capabilities.document_formatting then
    buf_set_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
  end
  if client.resolved_capabilities.document_range_formatting then
    buf_set_keymap("v", "<space>f", "<cmd>lua vim.lsp.buf.range_formatting()<CR>", opts)
  end

  -- Set autocommands conditional on server_capabilities
  if client.resolved_capabilities.document_highlight then
      vim.api.nvim_exec([[
        hi LspReferenceRead cterm=bold ctermbg=red guibg=LightYellow
        hi LspReferenceText cterm=bold ctermbg=red guibg=LightYellow
        hi LspReferenceWrite cterm=bold ctermbg=red guibg=LightYellow
        augroup lsp_document_highlight
          autocmd! * <buffer>
          autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
          autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
        augroup END
      ]], false)
    end
  end

 nvim_lsp.pyright.setup{
   cmd = { "npx", "pyright-langserver", "--stdio" },
   python = { 
     venvPath = "/home/luke/.local/share/virtualenvs/*", -- should point to pipenv
     },
 }
 nvim_lsp.solargraph.setup{}
EOF

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Deoplete Configuration 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" deoplete is a asynchronous completion framework 

" starts deoplete on startup
let g:deoplete#enable_at_startup = 1
let g:python3_host_prog = '~/.asdf/shims/python'
let g:deoplete#lsp#handler_enabled = 1

" <TAB>: completion.
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Tree Sitter Configuration 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tree sitter helps with better syntax highlighting
lua <<EOF
require'nvim-treesitter.configs'.setup {
  ensure_installed = "maintained", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  -- ignore_install = { "javascript" }, -- List of parsers to ignore installing
  highlight = {
    enable = true,              -- false will disable the whole extension
  --  disable = { "c", "rust" },  -- list of language that will be disabled
  },
  incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "gnn",
        node_incremental = "grn",
        scope_incremental = "grc",
        node_decremental = "grm",
      },
  },
  indent = {
    enable = true,
  },
}
EOF

