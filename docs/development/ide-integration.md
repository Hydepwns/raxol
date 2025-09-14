# IDE Integration

Raxol provides comprehensive IDE integration through Language Server Protocol (LSP) support and editor-specific plugins.

## Language Server Protocol (LSP)

The Raxol LSP server provides intelligent code assistance for Raxol applications across all major editors.

### Starting the LSP Server

```bash
# For stdio communication (most common)
mix raxol.lsp --stdio

# For TCP communication
mix raxol.lsp --port 9999

# For Unix socket communication  
mix raxol.lsp --socket /tmp/raxol-lsp.sock

# With verbose debug output
mix raxol.lsp --verbose
```

### Features

- **Autocompletion**: Component names, lifecycle methods, and props
- **Hover Documentation**: Type information and documentation on hover
- **Go to Definition**: Navigate to component and function definitions
- **Diagnostics**: Real-time validation of component structure and TEA patterns
- **Signature Help**: Parameter hints for component functions
- **Document Symbols**: Outline view of components and lifecycle methods

### LSP Configuration

The LSP server supports the following initialization options:

```json
{
  "initializationOptions": {
    "raxol": {
      "version": "1.0.0",
      "features": {
        "completion": true,
        "diagnostics": true,
        "hover": true
      }
    }
  }
}
```

## Editor Support

### Visual Studio Code

Install the official Raxol extension from the marketplace or use the configuration in `editors/vscode/`.

#### Features
- Syntax highlighting for Raxol patterns
- Component templates and snippets
- Integrated terminal commands
- Playground integration
- Component generation wizard

#### Installation
```bash
# Install from marketplace
code --install-extension axol-io.raxol

# Or build from source
cd editors/vscode
npm install
npm run compile
code --install-extension .
```

#### Configuration
```json
{
  "raxol.lsp.enabled": true,
  "raxol.lsp.path": "mix",
  "raxol.lsp.args": ["raxol.lsp", "--stdio"],
  "raxol.completion.enabled": true,
  "raxol.diagnostics.enabled": true
}
```

### Neovim

Use the Lua plugin located in `editors/nvim/`.

#### Installation with lazy.nvim
```lua
{
  'axol-io/raxol',
  dir = '/path/to/raxol/editors/nvim',
  dependencies = {
    'neovim/nvim-lspconfig',
    'nvim-treesitter/nvim-treesitter',
  },
  ft = { 'elixir', 'eex', 'heex' },
  config = function()
    require('raxol').setup()
  end
}
```

#### Features
- Full LSP integration with nvim-lspconfig
- Enhanced treesitter queries for Raxol patterns
- Component text objects and navigation
- Automatic component template insertion
- Integrated test runner and playground

#### Commands
- `:RaxolGenerateComponent [name]` - Generate component
- `:RaxolPlayground` - Open playground
- `:RaxolTest` - Run tests
- `:RaxolRestartLSP` - Restart LSP server

#### Keymaps
- `<leader>rc` - Generate component
- `<leader>rp` - Open playground
- `<leader>rt` - Run tests
- `<leader>rl` - Restart LSP

### Emacs

LSP client configuration for Emacs using `lsp-mode`:

```elisp
(use-package lsp-mode
  :hook (elixir-mode . lsp-deferred)
  :custom
  (lsp-raxol-server-command '("mix" "raxol.lsp" "--stdio")))

;; Register Raxol LSP server
(lsp-register-client
 (make-lsp-client
  :new-connection (lsp-stdio-connection '("mix" "raxol.lsp" "--stdio"))
  :activation-fn (lambda (filename &optional _)
                   (string-match-p "\.exs?$" filename))
  :server-id 'raxol))
```

### Vim (with vim-lsp)

Configuration for Vim using the vim-lsp plugin:

```vim
if executable('mix')
    augroup RaxolLSP
        autocmd!
        autocmd User lsp_setup call lsp#register_server({
            \ 'name': 'raxol',
            \ 'cmd': {server_info->['mix', 'raxol.lsp', '--stdio']},
            \ 'whitelist': ['elixir', 'eex', 'heex'],
            \ 'workspace_config': {'raxol': {'completion': {'enabled': v:true}}}
            \ })
    augroup END
endif
```

## Component Generation

All editors support component generation through the integrated LSP server:

### Basic Component
```elixir
defmodule MyComponent do
  use Raxol.UI.Components.Base.Component
  
  def init(props), do: Map.merge(%{}, props)
  def mount(state), do: {state, []}
  def update(message, state), do: state
  def render(state, context), do: text("MyComponent")
  def handle_event(event, state, context), do: {state, []}
end
```

### Interactive Component
```elixir
defmodule Counter do
  use Raxol.UI.Components.Base.Component
  
  def init(props), do: Map.merge(%{count: 0}, props)
  
  def render(state, _context) do
    row do
      [
        button("-", on_click: :decrement),
        text("Count: #{state.count}"),
        button("+", on_click: :increment)
      ]
    end
  end
  
  def handle_event({:click, :increment}, state, _context) do
    {%{state | count: state.count + 1}, []}
  end
  
  def handle_event({:click, :decrement}, state, _context) do
    {%{state | count: state.count - 1}, []}
  end
end
```

## Troubleshooting

### LSP Server Issues

1. **Server won't start**: Ensure Mix task is available
   ```bash
   mix raxol.lsp --help
   ```

2. **No completion**: Check LSP client configuration and server logs

3. **Diagnostics not working**: Verify file is in a Raxol project (has `mix.exs` or `.raxol.exs`)

### Editor-Specific Issues

#### VSCode
- Check extension is installed and enabled
- Verify workspace contains Raxol project files
- Check Output → Raxol Language Server for errors

#### Neovim
- Ensure nvim-lspconfig is installed
- Check `:LspInfo` for server status
- Use `:LspLog` to view server logs

### Performance

The LSP server is optimized for performance:
- Component registry caching
- Incremental document sync
- Async request handling
- Memory-efficient parsing

## Contributing

IDE integration improvements are welcome! Areas for contribution:
- Additional editor support (Sublime Text, Atom, etc.)
- Enhanced treesitter queries
- More sophisticated diagnostics
- Performance optimizations

Please submit issues and pull requests to the main [Raxol repository](https://github.com/axol-io/raxol).