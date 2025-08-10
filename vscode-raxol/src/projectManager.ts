import * as vscode from 'vscode';
import * as path from 'path';

export class RaxolProjectManager {
    
    public async createNewProject(): Promise<void> {
        const projectName = await vscode.window.showInputBox({
            prompt: 'Enter project name',
            validateInput: (value) => {
                if (!value) return 'Project name is required';
                if (!/^[a-z][a-z0-9_]*$/.test(value)) {
                    return 'Project name must start with lowercase letter and contain only lowercase letters, numbers, and underscores';
                }
                return null;
            }
        });

        if (!projectName) return;

        const projectPath = await vscode.window.showOpenDialog({
            canSelectFiles: false,
            canSelectFolders: true,
            canSelectMany: false,
            openLabel: 'Select Project Directory'
        });

        if (!projectPath || projectPath.length === 0) return;

        const fullProjectPath = path.join(projectPath[0].fsPath, projectName);
        const projectUri = vscode.Uri.file(fullProjectPath);

        try {
            await vscode.workspace.fs.createDirectory(projectUri);
            await this.generateProjectStructure(projectUri, projectName);
            
            // Open the new project
            await vscode.commands.executeCommand('vscode.openFolder', projectUri);
            
            vscode.window.showInformationMessage(`Raxol project "${projectName}" created successfully!`);
        } catch (error) {
            vscode.window.showErrorMessage(`Failed to create project: ${error instanceof Error ? error.message : String(error)}`);
        }
    }

    public async createNewComponent(targetFolder: vscode.Uri): Promise<void> {
        const componentName = await vscode.window.showInputBox({
            prompt: 'Enter component name',
            validateInput: (value) => {
                if (!value) return 'Component name is required';
                if (!/^[A-Z][a-zA-Z0-9]*$/.test(value)) {
                    return 'Component name must start with uppercase letter and be in PascalCase';
                }
                return null;
            }
        });

        if (!componentName) return;

        const componentType = await vscode.window.showQuickPick([
            { label: 'Basic Component', description: 'Simple stateless component', value: 'basic' },
            { label: 'Stateful Component', description: 'Component with state management', value: 'stateful' },
            { label: 'GenServer Component', description: 'Component with GenServer backing', value: 'genserver' },
            { label: 'Layout Component', description: 'Container component for layouts', value: 'layout' },
            { label: 'Input Component', description: 'Interactive input component', value: 'input' }
        ], {
            placeHolder: 'Select component type'
        });

        if (!componentType) return;

        try {
            const componentPath = vscode.Uri.joinPath(targetFolder, `${componentName.toLowerCase()}.ex`);
            const componentContent = this.generateComponentContent(componentName, componentType.value);
            
            await vscode.workspace.fs.writeFile(componentPath, Buffer.from(componentContent));
            
            // Open the new component file
            const document = await vscode.workspace.openTextDocument(componentPath);
            await vscode.window.showTextDocument(document);
            
            vscode.window.showInformationMessage(`Component "${componentName}" created successfully!`);
        } catch (error) {
            vscode.window.showErrorMessage(`Failed to create component: ${error instanceof Error ? error.message : String(error)}`);
        }
    }

    private async generateProjectStructure(projectUri: vscode.Uri, projectName: string): Promise<void> {
        const files = [
            { path: 'mix.exs', content: this.getMixExsContent(projectName) },
            { path: 'README.md', content: this.getReadmeContent(projectName) },
            { path: '.gitignore', content: this.getGitignoreContent() },
            { path: 'config/config.exs', content: this.getConfigContent(projectName) },
            { path: 'config/dev.exs', content: this.getDevConfigContent() },
            { path: 'config/test.exs', content: this.getTestConfigContent() },
            { path: 'config/prod.exs', content: this.getProdConfigContent() },
            { path: `lib/${projectName}.ex`, content: this.getMainModuleContent(projectName) },
            { path: `lib/${projectName}/application.ex`, content: this.getApplicationContent(projectName) },
            { path: `lib/${projectName}/components/hello_world.ex`, content: this.getHelloWorldComponent() },
            { path: `test/test_helper.exs`, content: this.getTestHelperContent() },
            { path: `test/${projectName}_test.exs`, content: this.getMainTestContent(projectName) }
        ];

        for (const file of files) {
            const filePath = vscode.Uri.joinPath(projectUri, file.path);
            const dirPath = vscode.Uri.joinPath(projectUri, path.dirname(file.path));
            
            // Create directory if it doesn't exist
            try {
                await vscode.workspace.fs.createDirectory(dirPath);
            } catch {
                // Directory might already exist
            }
            
            await vscode.workspace.fs.writeFile(filePath, Buffer.from(file.content));
        }
    }

    private generateComponentContent(componentName: string, type: string): string {
        const moduleName = `MyApp.Components.${componentName}`;
        
        switch (type) {
            case 'basic':
                return `defmodule ${moduleName} do
  @moduledoc """
  ${componentName} component - A basic Raxol component.
  """
  
  use Raxol.Component

  @doc """
  Renders the ${componentName} component.
  """
  def render(props, _state) do
    content = Map.get(props, :content, "Hello from ${componentName}")
    
    Text.render(content: content)
  end
end
`;

            case 'stateful':
                return `defmodule ${moduleName} do
  @moduledoc """
  ${componentName} component - A stateful Raxol component.
  """
  
  use Raxol.Component

  def init(props) do
    {:ok, %{
      count: Map.get(props, :initial_count, 0),
      message: Map.get(props, :message, "Count: ")
    }}
  end

  def render(props, state) do
    Box.render(
      title: "${componentName}",
      width: 30,
      height: 5
    ) do
      Text.render(content: "#{state.message}#{state.count}")
    end
  end

  def update({:increment}, state) do
    {:ok, %{state | count: state.count + 1}}
  end

  def update({:decrement}, state) do
    {:ok, %{state | count: state.count - 1}}
  end

  def update({:set_count, new_count}, state) do
    {:ok, %{state | count: new_count}}
  end
end
`;

            case 'genserver':
                return `defmodule ${moduleName} do
  @moduledoc """
  ${componentName} component - A GenServer-backed Raxol component.
  """
  
  use GenServer
  use Raxol.Component

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def update_data(data) do
    GenServer.cast(__MODULE__, {:update_data, data})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    {:ok, %{
      data: Map.get(opts, :data, []),
      last_updated: DateTime.utc_now()
    }}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:update_data, data}, state) do
    new_state = %{state | 
      data: data,
      last_updated: DateTime.utc_now()
    }
    {:noreply, new_state}
  end

  # Component Callbacks

  def render(props, _state) do
    server_state = get_state()
    
    Box.render(
      title: "${componentName}",
      width: 50,
      height: 10
    ) do
      [
        Text.render(content: "Data: #{inspect(server_state.data)}"),
        Text.render(content: "Last Updated: #{server_state.last_updated}")
      ]
    end
  end
end
`;

            case 'layout':
                return `defmodule ${moduleName} do
  @moduledoc """
  ${componentName} component - A layout container component.
  """
  
  use Raxol.Component

  def render(props, _state) do
    children = Map.get(props, :children, [])
    direction = Map.get(props, :direction, :vertical)
    gap = Map.get(props, :gap, 1)
    padding = Map.get(props, :padding, 1)
    
    Box.render(
      title: Map.get(props, :title, "${componentName}"),
      width: Map.get(props, :width, 60),
      height: Map.get(props, :height, 20),
      border: Map.get(props, :border, :single)
    ) do
      Flex.render(
        direction: direction,
        gap: gap,
        padding: padding
      ) do
        children
      end
    end
  end
end
`;

            case 'input':
                return `defmodule ${moduleName} do
  @moduledoc """
  ${componentName} component - An interactive input component.
  """
  
  use Raxol.Component

  def init(props) do
    {:ok, %{
      value: Map.get(props, :value, ""),
      focused: false,
      cursor_position: 0
    }}
  end

  def render(props, state) do
    label = Map.get(props, :label, "${componentName}")
    placeholder = Map.get(props, :placeholder, "Enter text...")
    width = Map.get(props, :width, 30)
    
    Box.render(
      title: label,
      width: width + 4,
      height: 6
    ) do
      [
        TextInput.render(
          value: state.value,
          placeholder: placeholder,
          width: width,
          focused: state.focused,
          cursor_position: state.cursor_position
        )
      ]
    end
  end

  def handle_event("focus", _params, state) do
    {:ok, %{state | focused: true}}
  end

  def handle_event("blur", _params, state) do
    {:ok, %{state | focused: false}}
  end

  def handle_event("input", %{"value" => value}, state) do
    {:ok, %{state | 
      value: value,
      cursor_position: String.length(value)
    }}
  end

  def handle_event("key", %{"key" => key}, state) do
    case key do
      "ArrowLeft" ->
        new_pos = max(0, state.cursor_position - 1)
        {:ok, %{state | cursor_position: new_pos}}
      
      "ArrowRight" ->
        new_pos = min(String.length(state.value), state.cursor_position + 1)
        {:ok, %{state | cursor_position: new_pos}}
      
      _ ->
        {:ok, state}
    end
  end
end
`;

            default:
                return this.generateComponentContent(componentName, 'basic');
        }
    }

    private getMixExsContent(projectName: string): string {
        const moduleName = projectName.split('_').map(part => 
            part.charAt(0).toUpperCase() + part.slice(1)
        ).join('');

        return `defmodule ${moduleName}.MixProject do
  use Mix.Project

  def project do
    [
      app: :${projectName},
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {${moduleName}.Application, []}
    ]
  end

  defp deps do
    [
      {:raxol, "~> 0.9.0"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      "start": ["run --no-halt"],
      "playground": ["raxol.playground"],
      "tutorial": ["raxol.tutorial"]
    ]
  end
end
`;
    }

    private getReadmeContent(projectName: string): string {
        return `# ${projectName.charAt(0).toUpperCase() + projectName.slice(1)}

A Raxol terminal UI application.

## Getting Started

### Prerequisites

- Elixir 1.14 or later
- Erlang/OTP 25 or later

### Installation

1. Install dependencies:
   \`\`\`bash
   mix deps.get
   \`\`\`

2. Compile the project:
   \`\`\`bash
   mix compile
   \`\`\`

3. Run the application:
   \`\`\`bash
   mix start
   \`\`\`

## Development

### Available Commands

- \`mix start\` - Start the application
- \`mix playground\` - Open component playground
- \`mix tutorial\` - Start interactive tutorial
- \`mix test\` - Run tests
- \`mix docs\` - Generate documentation

### Project Structure

- \`lib/\` - Application source code
  - \`lib/${projectName}/\` - Main application modules
  - \`lib/${projectName}/components/\` - Raxol components
- \`test/\` - Test files
- \`config/\` - Configuration files

## Creating Components

Use the VSCode extension or create components manually:

\`\`\`elixir
defmodule MyApp.Components.MyComponent do
  use Raxol.Component

  def render(props, _state) do
    Text.render(content: "Hello from MyComponent!")
  end
end
\`\`\`

## Documentation

- [Raxol Documentation](https://raxol.dev)
- [Component Guide](https://raxol.dev/components)
- [Tutorial](https://raxol.dev/tutorial)

## License

This project is licensed under the MIT License.
`;
    }

    private getGitignoreContent(): string {
        return `# Build artifacts
/_build/
/cover/
/deps/
/doc/
/.fetch
erl_crash.dump
*.beam
*.plt
*.plt.info

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
/logs/
*.log

# Environment
.env
.env.local
.env.production

# Temporary files
/tmp/
*.tmp
*.temp

# Mix
mix.lock.backup
`;
    }

    private getConfigContent(projectName: string): string {
        const moduleName = projectName.split('_').map(part => 
            part.charAt(0).toUpperCase() + part.slice(1)
        ).join('');

        return `import Config

config :${projectName},
  terminal_title: "${moduleName}",
  log_level: :info

# Import environment specific config
import_config "#{Mix.env()}.exs"
`;
    }

    private getDevConfigContent(): string {
        return `import Config

config :logger, level: :debug

# Terminal development settings
config :raxol,
  enable_debug: true,
  hot_reload: true
`;
    }

    private getTestConfigContent(): string {
        return `import Config

config :logger, level: :warn

# Test environment settings
config :raxol,
  test_mode: true
`;
    }

    private getProdConfigContent(): string {
        return `import Config

config :logger, level: :info

# Production settings
config :raxol,
  enable_debug: false
`;
    }

    private getMainModuleContent(projectName: string): string {
        const moduleName = projectName.split('_').map(part => 
            part.charAt(0).toUpperCase() + part.slice(1)
        ).join('');

        return `defmodule ${moduleName} do
  @moduledoc """
  ${moduleName} application.
  
  This is the main entry point for your Raxol terminal application.
  """

  use Raxol.Terminal

  alias ${moduleName}.Components.HelloWorld

  def start do
    Raxol.Terminal.start_link(__MODULE__, %{})
  end

  def init(_args) do
    {:ok, %{
      current_screen: :main,
      user_name: "User"
    }}
  end

  def render(state) do
    case state.current_screen do
      :main ->
        render_main_screen(state)
    end
  end

  defp render_main_screen(state) do
    Box.render(
      title: "${moduleName} - Welcome",
      width: 60,
      height: 20,
      border: :double
    ) do
      [
        HelloWorld.render(user_name: state.user_name),
        Text.render(content: ""),
        Text.render(content: "Press 'q' to quit, 'h' for help")
      ]
    end
  end

  def handle_event("key", %{"key" => "q"}, _state) do
    :stop
  end

  def handle_event("key", %{"key" => "h"}, state) do
    # Show help screen
    {:ok, %{state | current_screen: :help}}
  end

  def handle_event(_event, _params, state) do
    {:ok, state}
  end
end
`;
    }

    private getApplicationContent(projectName: string): string {
        const moduleName = projectName.split('_').map(part => 
            part.charAt(0).toUpperCase() + part.slice(1)
        ).join('');

        return `defmodule ${moduleName}.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Add your application's supervised processes here
      # {${moduleName}.Worker, arg}
    ]

    opts = [strategy: :one_for_one, name: ${moduleName}.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
`;
    }

    private getHelloWorldComponent(): string {
        return `defmodule MyApp.Components.HelloWorld do
  @moduledoc """
  A simple Hello World component to get you started.
  """

  use Raxol.Component

  def render(props, _state) do
    user_name = Map.get(props, :user_name, "World")
    
    Flex.render(
      direction: :vertical,
      gap: 1
    ) do
      [
        Text.render(
          content: "Hello, #{user_name}!",
          style: %{color: :green, bold: true}
        ),
        Text.render(content: "Welcome to your new Raxol application."),
        Text.render(
          content: "Start building amazing terminal UIs!",
          style: %{color: :cyan}
        )
      ]
    end
  end
end
`;
    }

    private getTestHelperContent(): string {
        return `ExUnit.start()
`;
    }

    private getMainTestContent(projectName: string): string {
        const moduleName = projectName.split('_').map(part => 
            part.charAt(0).toUpperCase() + part.slice(1)
        ).join('');

        return `defmodule ${moduleName}Test do
  use ExUnit.Case
  doctest ${moduleName}

  test "application starts" do
    assert is_function(&${moduleName}.start/0, 0)
  end
end
`;
    }
}