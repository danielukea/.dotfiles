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
" for autocompletion
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'

" for running tests
Plug 'vim-test/vim-test'

" for interacting with tmux from vim
Plug 'preservim/vimux'

" Plug adds solidity based syntax ( Ethereum smartcontract language)
Plug 'tomlion/vim-solidity'
Plug 'junegunn/fzf'

" Plug to add tree sitter
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'} 

call plug#end()
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Vim testing strategy 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let test#strategy = "vimux"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Nvim fuzzy finder config 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set rtp+=/usr/bin/fzf
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Nvim LSP Auto Completion 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set completeopt=menu,menuone,noselect

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Nvim LSP Config 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Language server protocol config
"

" pyright lsp configuration
lua << EOF
 -- setup nvim-cmp
 local cmp = require'cmp'
 cmp.setup({
    snippet = {
      expand = function(args)
        -- For `vsnip` user.
        vim.fn["vsnip#anonymous"](args.body)

        -- For `luasnip` user.
        -- require('luasnip').lsp_expand(args.body)

        -- For `ultisnips` user.
        -- vim.fn["UltiSnips#Anon"](args.body)
      end,
    },
    mapping = {
      ['<C-d>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.close(),
      ['<CR>'] = cmp.mapping.confirm({ select = true }),
    },
    sources = {
      { name = 'nvim_lsp' },

      -- For vsnip user.
      -- { name = 'vsnip' },

      -- For luasnip user.
      -- { name = 'luasnip' },

      -- For ultisnips user.
      -- { name = 'ultisnips' },

      { name = 'buffer' },
    }
  })
vim.lsp.set_log_level 'error'

local nvim_lsp = require('lspconfig')

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  local function buf_set_keymap(...) 
    vim.api.nvim_buf_set_keymap(bufnr, ...) 
  end
  local function buf_set_option(...) 
    vim.api.nvim_buf_set_option(bufnr, ...) 
  end

  -- Enable completion triggered by <c-x><c-o>
  -- buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  local opts = { noremap=true, silent=true }
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
  buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
  buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
  buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
  buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
  buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
  buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
  buf_set_keymap('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
  buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  buf_set_keymap('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
  buf_set_keymap('n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
  buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
  buf_set_keymap('n', '<space>e', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
  buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
  buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
  buf_set_keymap('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
  buf_set_keymap('n', '<space>f', '<cmd>lua vim.lsp.buf.formatting()<CR>', opts)
end
print [[You can find your log at $HOME/.cache/nvim/lsp.log. Please paste in a github issue under a details tag as described in the issue template.]]

 nvim_lsp.pyright.setup{
   cmd = { "npx", "pyright-langserver", "--stdio" },
   python = { 
     venvPath = "/home/luke/.local/share/virtualenvs/*", -- should point to pipenv
     },
    on_attach = on_attach,
    flags = {
      debounce_text_changes = 150,
    },
    capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities()),
 }
 nvim_lsp.solargraph.setup{
    on_attach = on_attach,
    flags = {
      debounce_text_changes = 150,
    },
    capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities()),
 }
EOF

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

