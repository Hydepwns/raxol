# Elixir Patterns and Best Practices

## Core Language Patterns

### Pattern Matching

#### Destructuring in Function Heads
```elixir
# Good - Clear intent, single responsibility
def process_user(%User{id: id, name: name} = user) when is_binary(name) do
  # Use destructured values
end

# Good - Multiple function clauses for different shapes
def handle_result({:ok, data}), do: process(data)
def handle_result({:error, reason}), do: log_error(reason)
def handle_result(_), do: {:error, :invalid_result}
```

#### Using Guards Effectively
```elixir
defguard is_positive(value) when is_number(value) and value > 0

def calculate_price(amount, tax_rate) 
  when is_positive(amount) and is_positive(tax_rate) do
  amount * (1 + tax_rate)
end
```

### Pipeline Patterns

#### Transform Data with Pipes
```elixir
# Good - Clear transformation pipeline
def process_text(input) do
  input
  |> String.trim()
  |> String.downcase()
  |> String.split()
  |> Enum.map(&capitalize_word/1)
  |> Enum.join(" ")
end

# Good - With error handling
def fetch_and_process(url) do
  url
  |> HTTPClient.get()
  |> handle_response()
  |> parse_json()
  |> extract_data()
  |> transform_data()
end

defp handle_response({:ok, response}), do: {:ok, response.body}
defp handle_response({:error, _} = error), do: error
```

### With Statements

#### Sequential Operations with Error Handling
```elixir
def create_user(params) do
  with {:ok, validated} <- validate_params(params),
       {:ok, user} <- insert_user(validated),
       {:ok, _} <- send_welcome_email(user),
       {:ok, _} <- log_user_creation(user) do
    {:ok, user}
  else
    {:error, :validation, errors} ->
      {:error, format_validation_errors(errors)}
    
    {:error, :database, reason} ->
      Logger.error("Database error: #{inspect(reason)}")
      {:error, :internal_error}
    
    error ->
      Logger.error("Unexpected error: #{inspect(error)}")
      {:error, :internal_error}
  end
end
```

## Module Design Patterns

### Behavior Definition
```elixir
defmodule Raxol.Storage do
  @callback init(opts :: keyword()) :: {:ok, state} | {:error, reason}
  @callback get(key :: String.t(), state) :: {:ok, value} | {:error, :not_found}
  @callback put(key :: String.t(), value :: any(), state) :: {:ok, state}
  
  @optional_callbacks [init: 1]
end
```

### Implementation with Defdelegate
```elixir
defmodule Raxol.Terminal.Buffer do
  defstruct [:width, :height, :cells, :cursor]
  
  # Delegate to specialized modules
  defdelegate write_char(buffer, x, y, char), to: Raxol.Terminal.Buffer.Writer
  defdelegate move_cursor(buffer, x, y), to: Raxol.Terminal.Buffer.Cursor
  defdelegate scroll(buffer, lines), to: Raxol.Terminal.Buffer.Scroller
end
```

### Module Attributes as Constants
```elixir
defmodule Raxol.Terminal.ANSI do
  @reset "\e[0m"
  @bold "\e[1m"
  @clear_screen "\e[2J"
  
  @colors %{
    black: 30,
    red: 31,
    green: 32,
    yellow: 33
  }
  
  def color_code(color), do: Map.get(@colors, color, 37)
end
```

## Process Patterns

### GenServer State Management
```elixir
defmodule Raxol.SessionManager do
  use GenServer
  
  defmodule State do
    defstruct sessions: %{}, 
              max_sessions: 100,
              timeout: :timer.minutes(30)
  end
  
  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def create_session(user_id) do
    GenServer.call(__MODULE__, {:create_session, user_id})
  end
  
  # Server Callbacks
  @impl true
  def init(opts) do
    state = %State{
      max_sessions: Keyword.get(opts, :max_sessions, 100),
      timeout: Keyword.get(opts, :timeout, :timer.minutes(30))
    }
    
    {:ok, state, {:continue, :setup}}
  end
  
  @impl true
  def handle_continue(:setup, state) do
    # Perform async initialization
    schedule_cleanup()
    {:noreply, state}
  end
  
  @impl true
  def handle_call({:create_session, user_id}, _from, state) do
    case create_new_session(state, user_id) do
      {:ok, session, new_state} ->
        {:reply, {:ok, session}, new_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
end
```

### Supervisor Patterns
```elixir
defmodule Raxol.Terminal.Supervisor do
  use Supervisor
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    children = [
      # Permanent children - always restart
      {Raxol.Terminal.Registry, []},
      
      # Transient children - restart on abnormal exit
      %{
        id: Raxol.Terminal.Manager,
        start: {Raxol.Terminal.Manager, :start_link, []},
        restart: :transient
      },
      
      # Dynamic supervisor for terminal instances
      {DynamicSupervisor, 
       name: Raxol.Terminal.DynamicSupervisor,
       strategy: :one_for_one,
       max_restarts: 5,
       max_seconds: 10}
    ]
    
    Supervisor.init(children, strategy: :one_for_all)
  end
end
```

## Data Structure Patterns

### Struct with Validation
```elixir
defmodule Raxol.Terminal.Config do
  @enforce_keys [:width, :height]
  defstruct [
    :width,
    :height,
    scrollback: 1000,
    theme: :default,
    plugins: []
  ]
  
  @type t :: %__MODULE__{
    width: pos_integer(),
    height: pos_integer(),
    scrollback: non_neg_integer(),
    theme: atom(),
    plugins: [module()]
  }
  
  def new(params) do
    with {:ok, validated} <- validate(params) do
      {:ok, struct(__MODULE__, validated)}
    end
  end
  
  defp validate(params) do
    # Validation logic
  end
end
```

### Tagged Tuples for Results
```elixir
# Consistent result types
@type result(t) :: {:ok, t} | {:error, reason :: term()}
@type result() :: :ok | {:error, reason :: term()}

def process_data(input) do
  case validate(input) do
    {:ok, data} -> {:ok, transform(data)}
    {:error, _} = error -> error
  end
end
```

## Error Handling Patterns

### Custom Exceptions
```elixir
defmodule Raxol.ConfigError do
  defexception [:message, :key, :value]
  
  @impl true
  def exception(opts) do
    key = Keyword.fetch!(opts, :key)
    value = Keyword.get(opts, :value)
    
    %__MODULE__{
      message: "Invalid configuration for #{key}: #{inspect(value)}",
      key: key,
      value: value
    }
  end
end

# Usage
raise Raxol.ConfigError, key: :width, value: -1
```

### Graceful Degradation
```elixir
def render_with_plugin(content, plugin) do
  try do
    plugin.render(content)
  rescue
    error ->
      Logger.warn("Plugin rendering failed: #{inspect(error)}")
      default_render(content)
  end
end
```

## Performance Patterns

### ETS for Shared State
```elixir
defmodule Raxol.Cache do
  def init do
    :ets.new(:raxol_cache, [:set, :public, :named_table])
  end
  
  def get(key) do
    case :ets.lookup(:raxol_cache, key) do
      [{^key, value}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end
  
  def put(key, value) do
    :ets.insert(:raxol_cache, {key, value})
    :ok
  end
end
```

### Stream Processing
```elixir
def process_large_file(path) do
  path
  |> File.stream!()
  |> Stream.map(&String.trim/1)
  |> Stream.filter(&valid_line?/1)
  |> Stream.map(&parse_line/1)
  |> Stream.chunk_every(100)
  |> Stream.each(&batch_process/1)
  |> Stream.run()
end
```

### Compile-Time Optimization
```elixir
defmodule Raxol.Constants do
  @colors ~w(black red green yellow blue magenta cyan white)
  
  # Generate functions at compile time
  for {color, index} <- Enum.with_index(@colors) do
    def color_index(unquote(color)), do: unquote(index)
  end
  
  def color_index(_), do: nil
end
```

## Testing Patterns

### Property-Based Testing
```elixir
use ExUnitProperties

property "encoding and decoding are inverse operations" do
  check all data <- binary() do
    assert data == data |> encode() |> decode()
  end
end
```

### Mocking with Behaviors
```elixir
# Define behavior
defmodule Raxol.Terminal.Behaviour do
  @callback write(binary()) :: :ok | {:error, term()}
end

# In test
Mox.defmock(Raxol.Terminal.Mock, for: Raxol.Terminal.Behaviour)

test "processes input correctly" do
  expect(Raxol.Terminal.Mock, :write, fn data ->
    assert data == "expected"
    :ok
  end)
  
  MyModule.process(Raxol.Terminal.Mock, "input")
end
```

## Documentation Patterns

### Module Documentation
```elixir
defmodule Raxol.Terminal.Buffer do
  @moduledoc """
  Buffer management for terminal emulation.
  
  The buffer maintains a 2D grid of cells, each containing:
  - Character data
  - Styling attributes
  - Metadata
  
  ## Examples
  
      iex> buffer = Buffer.new(80, 24)
      iex> buffer = Buffer.write_char(buffer, 0, 0, "H")
      iex> Buffer.get_char(buffer, 0, 0)
      "H"
  
  """
  
  @doc """
  Creates a new buffer with the specified dimensions.
  
  ## Parameters
  
    * `width` - Buffer width in columns
    * `height` - Buffer height in rows
  
  ## Returns
  
    * `{:ok, buffer}` - Successfully created buffer
    * `{:error, reason}` - Creation failed
  
  """
  @spec new(pos_integer(), pos_integer()) :: {:ok, t()} | {:error, term()}
  def new(width, height) do
    # Implementation
  end
end
```

## Anti-Patterns to Avoid

### ❌ Don't Use Atoms from User Input
```elixir
# Bad - Can exhaust atom table
String.to_atom(user_input)

# Good - Use existing atoms
String.to_existing_atom(user_input)
```

### ❌ Don't Overuse Macros
```elixir
# Bad - Unnecessary macro
defmacro add(a, b) do
  quote do
    unquote(a) + unquote(b)
  end
end

# Good - Simple function
def add(a, b), do: a + b
```

### ❌ Don't Ignore Dialyzer Warnings
```elixir
# Add specs and fix warnings
@spec process(String.t()) :: {:ok, map()} | {:error, term()}
def process(input) do
  # Implementation
end
```