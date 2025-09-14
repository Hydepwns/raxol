local M = {}

local lspconfig = require('lspconfig')
local configs = require('lspconfig.configs')

-- Default configuration
local default_config = {
  lsp = {
    enabled = true,
    cmd = { 'mix', 'raxol.lsp', '--stdio' },
    filetypes = { 'elixir', 'eex', 'heex' },
    root_patterns = { 'mix.exs', '.raxol.exs', '.git' }
  },
  treesitter = {
    enabled = true,
    highlight = true,
    incremental_selection = true,
    textobjects = true
  },
  completion = {
    enabled = true,
    snippet_support = true
  },
  diagnostics = {
    enabled = true,
    virtual_text = true,
    signs = true
  }
}

-- Setup function
function M.setup(opts)
  opts = vim.tbl_deep_extend('force', default_config, opts or {})
  
  -- Configure LSP server
  if opts.lsp.enabled then
    M.setup_lsp(opts.lsp)
  end
  
  -- Configure treesitter
  if opts.treesitter.enabled then
    M.setup_treesitter(opts.treesitter)
  end
  
  -- Setup autocommands and keymaps
  M.setup_autocommands()
  M.setup_keymaps()
  
  -- Setup user commands
  M.setup_commands()
end

-- LSP Configuration
function M.setup_lsp(lsp_opts)
  -- Register Raxol LSP server if not already configured
  if not configs.raxol then
    configs.raxol = {
      default_config = {
        cmd = lsp_opts.cmd,
        filetypes = lsp_opts.filetypes,
        root_dir = function(fname)
          return lspconfig.util.root_pattern(unpack(lsp_opts.root_patterns))(fname)
        end,
        settings = {
          raxol = {
            completion = { enabled = true },
            diagnostics = { enabled = true },
            hover = { enabled = true }
          }
        },
        init_options = {
          raxol = {
            version = '1.0.0',
            editor = 'neovim'
          }
        }
      }
    }
  end
  
  -- Setup the LSP client
  lspconfig.raxol.setup({
    on_attach = M.on_attach,
    capabilities = M.get_capabilities(),
    settings = {
      raxol = {
        completion = { enabled = true },
        diagnostics = { enabled = true }
      }
    }
  })
end

-- Treesitter Configuration  
function M.setup_treesitter(ts_opts)
  local status_ok, ts_configs = pcall(require, 'nvim-treesitter.configs')
  if not status_ok then
    vim.notify('nvim-treesitter not found, skipping treesitter setup', vim.log.levels.WARN)
    return
  end
  
  -- Extend Elixir treesitter for Raxol-specific patterns
  ts_configs.setup({
    highlight = {
      enable = ts_opts.highlight,
      additional_vim_regex_highlighting = { 'elixir' },
      custom_captures = {
        ['raxol.component'] = 'RaxolComponent',
        ['raxol.lifecycle'] = 'RaxolLifecycle',
        ['raxol.event'] = 'RaxolEvent'
      }
    },
    incremental_selection = {
      enable = ts_opts.incremental_selection,
      keymaps = {
        init_selection = 'gnn',
        node_incremental = 'grn',
        scope_incremental = 'grc',
        node_decremental = 'grm'
      }
    },
    textobjects = {
      enable = ts_opts.textobjects,
      select = {
        enable = true,
        lookahead = true,
        keymaps = {
          ['af'] = '@function.outer',
          ['if'] = '@function.inner',
          ['ac'] = '@component.outer',
          ['ic'] = '@component.inner',
          ['ae'] = '@event.outer',
          ['ie'] = '@event.inner'
        }
      },
      move = {
        enable = true,
        set_jumps = true,
        goto_next_start = {
          [']m'] = '@function.outer',
          [']c'] = '@component.outer',
          [']e'] = '@event.outer'
        },
        goto_next_end = {
          [']M'] = '@function.outer',
          [']C'] = '@component.outer',
          [']E'] = '@event.outer'
        },
        goto_previous_start = {
          ['[m'] = '@function.outer',
          ['[c'] = '@component.outer',
          ['[e'] = '@event.outer'
        },
        goto_previous_end = {
          ['[M'] = '@function.outer',
          ['[C'] = '@component.outer',
          ['[E'] = '@event.outer'
        }
      }
    }
  })
end

-- LSP on_attach function
function M.on_attach(client, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'

  local opts = { buffer = bufnr, silent = true }
  
  -- LSP keymaps
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
  vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
  vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
  vim.keymap.set('n', '<space>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, opts)
  vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
  vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
  vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
  vim.keymap.set('n', '<space>f', function()
    vim.lsp.buf.format({ async = true })
  end, opts)
  
  -- Raxol-specific keymaps
  vim.keymap.set('n', '<space>rc', M.generate_component, opts)
  vim.keymap.set('n', '<space>rp', M.open_playground, opts)
  vim.keymap.set('n', '<space>rt', M.run_tests, opts)
end

-- Get LSP capabilities
function M.get_capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  
  -- Add completion capabilities if nvim-cmp is available
  local status_ok, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
  if status_ok then
    capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
  end
  
  -- Add snippet capabilities
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  capabilities.textDocument.completion.completionItem.resolveSupport = {
    properties = { 'documentation', 'detail', 'additionalTextEdits' }
  }
  
  return capabilities
end

-- Setup autocommands
function M.setup_autocommands()
  local group = vim.api.nvim_create_augroup('RaxolPlugin', { clear = true })
  
  -- Auto-detect Raxol projects
  vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
    group = group,
    pattern = '*.ex',
    callback = function()
      -- Check if this is a Raxol component
      local lines = vim.api.nvim_buf_get_lines(0, 0, 10, false)
      for _, line in ipairs(lines) do
        if line:match('use Raxol%.') then
          vim.bo.filetype = 'elixir'
          vim.b.is_raxol_file = true
          break
        end
      end
    end
  })
  
  -- Template insertion for new component files
  vim.api.nvim_create_autocmd('BufNewFile', {
    group = group,
    pattern = '**/components/**/*.ex',
    callback = function()
      M.insert_component_template()
    end
  })
  
  -- Highlight Raxol-specific patterns
  vim.api.nvim_create_autocmd('Syntax', {
    group = group,
    pattern = 'elixir',
    callback = function()
      if vim.b.is_raxol_file then
        M.setup_syntax_highlighting()
      end
    end
  })
end

-- Setup keymaps
function M.setup_keymaps()
  -- Global Raxol keymaps
  vim.keymap.set('n', '<leader>rc', M.generate_component, { desc = 'Generate Raxol component' })
  vim.keymap.set('n', '<leader>rp', M.open_playground, { desc = 'Open Raxol playground' })
  vim.keymap.set('n', '<leader>rt', M.run_tests, { desc = 'Run Raxol tests' })
  vim.keymap.set('n', '<leader>rl', M.restart_lsp, { desc = 'Restart Raxol LSP' })
end

-- Setup user commands
function M.setup_commands()
  vim.api.nvim_create_user_command('RaxolGenerateComponent', function(opts)
    M.generate_component(opts.args)
  end, { nargs = '?', desc = 'Generate a new Raxol component' })
  
  vim.api.nvim_create_user_command('RaxolPlayground', M.open_playground, 
    { desc = 'Open Raxol component playground' })
  
  vim.api.nvim_create_user_command('RaxolTest', M.run_tests,
    { desc = 'Run Raxol tests' })
  
  vim.api.nvim_create_user_command('RaxolRestartLSP', M.restart_lsp,
    { desc = 'Restart Raxol LSP server' })
end

-- Component template insertion
function M.insert_component_template()
  local filename = vim.fn.expand('%:t:r')
  local component_name = filename:gsub('_(%w)', function(c) return c:upper() end)
  component_name = component_name:sub(1, 1):upper() .. component_name:sub(2)
  
  local template = {
    'defmodule ' .. component_name .. ' do',
    '  @moduledoc """',
    '  ' .. component_name .. ' component.',
    '  """',
    '',
    '  use Raxol.UI.Components.Base.Component',
    '',
    '  def init(props) do',
    '    Map.merge(%{}, props)',
    '  end',
    '',
    '  def mount(state) do',
    '    {state, []}',
    '  end',
    '',
    '  def update(message, state) do',
    '    # Handle component messages here',
    '    state',
    '  end',
    '',
    '  def render(state, context) do',
    '    # Render component UI here',
    '    text("' .. component_name .. '")',
    '  end',
    '',
    '  def handle_event(event, state, context) do',
    '    # Handle UI events here',
    '    {state, []}',
    '  end',
    'end'
  }
  
  vim.api.nvim_buf_set_lines(0, 0, -1, false, template)
  -- Position cursor at the render function
  vim.api.nvim_win_set_cursor(0, { 20, 4 })
end

-- Syntax highlighting for Raxol patterns
function M.setup_syntax_highlighting()
  vim.cmd([[
    syntax match RaxolComponent /\<\u\w*\>/ contained
    syntax match RaxolLifecycle /\<\(init\|mount\|update\|render\|handle_event\|unmount\)\>/ contained
    syntax match RaxolEvent /\<on_\w\+\>/ contained
    
    highlight link RaxolComponent Type
    highlight link RaxolLifecycle Function
    highlight link RaxolEvent Constant
  ]])
end

-- Utility functions
function M.generate_component(name)
  if not name or name == '' then
    name = vim.fn.input('Component name: ')
  end
  
  if name and name ~= '' then
    vim.cmd('terminal mix raxol.gen.component ' .. name)
  end
end

function M.open_playground()
  vim.cmd('terminal mix raxol.playground')
end

function M.run_tests()
  vim.cmd('terminal SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker')
end

function M.restart_lsp()
  vim.cmd('LspRestart raxol')
  vim.notify('Raxol LSP server restarted', vim.log.levels.INFO)
end

return M