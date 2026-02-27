defmodule Raxol.Test.Security.CleanModule do
  @moduledoc """
  Test fixture: a module with no security-sensitive operations.
  """
  def add(a, b), do: a + b
  def greet(name), do: "Hello, #{name}!"
end

defmodule Raxol.Test.Security.FileAccessModule do
  @moduledoc """
  Test fixture: a module that uses File operations.
  """
  def read_config(path) do
    File.read(path)
  end

  def write_log(path, content) do
    File.write(path, content)
  end
end

defmodule Raxol.Test.Security.NetworkAccessModule do
  @moduledoc """
  Test fixture: a module that uses network operations.
  """
  def connect(host, port) do
    :gen_tcp.connect(String.to_charlist(host), port, [:binary])
  end
end

defmodule Raxol.Test.Security.CodeInjectionModule do
  @moduledoc """
  Test fixture: a module that uses dynamic code evaluation.
  """
  def eval_code(code_string) do
    Code.eval_string(code_string)
  end
end

defmodule Raxol.Test.Security.SystemCommandModule do
  @moduledoc """
  Test fixture: a module that executes system commands.
  """
  def run_command(cmd, args) do
    System.cmd(cmd, args)
  end
end

defmodule Raxol.Test.Security.MixedModule do
  @moduledoc """
  Test fixture: a module with multiple security-sensitive operations.
  """
  def read_and_execute(path) do
    case File.read(path) do
      {:ok, content} -> System.cmd("echo", [content])
      error -> error
    end
  end
end

# ============================================================================
# Plugin Test Fixtures
# ============================================================================

defmodule Raxol.Test.Plugins.PassthroughPlugin do
  @moduledoc """
  Test fixture: a plugin that passes events through unchanged.
  """
  def filter_event(event, _state), do: {:ok, event}
  def handle_event(_event, state), do: {:ok, state}
end

defmodule Raxol.Test.Plugins.ModifyingPlugin do
  @moduledoc """
  Test fixture: a plugin that modifies events.
  """
  def filter_event(event, _state) do
    {:ok, Map.put(event, :modified_by, __MODULE__)}
  end

  def handle_event(_event, state), do: {:ok, state}
end

defmodule Raxol.Test.Plugins.HaltingPlugin do
  @moduledoc """
  Test fixture: a plugin that halts event propagation.
  """
  def filter_event(%{halt: true}, _state), do: :halt
  def filter_event(event, _state), do: {:ok, event}
  def handle_event(_event, state), do: {:ok, state}
end

defmodule Raxol.Test.Plugins.ErrorPlugin do
  @moduledoc """
  Test fixture: a plugin that returns errors.
  """
  def filter_event(%{error: true}, _state), do: {:error, :test_error}
  def filter_event(event, _state), do: {:ok, event}
  def handle_event(_event, state), do: {:ok, state}
end

defmodule Raxol.Test.Plugins.CrashingPlugin do
  @moduledoc """
  Test fixture: a plugin that crashes.
  """
  def filter_event(%{crash: true}, _state), do: raise("intentional crash")
  def filter_event(event, _state), do: {:ok, event}
  def handle_event(_event, state), do: {:ok, state}
end

defmodule Raxol.Test.Plugins.SlowPlugin do
  @moduledoc """
  Test fixture: a plugin that takes a long time.
  """
  def filter_event(%{slow: true}, _state) do
    Process.sleep(5_000)
    {:ok, %{slow: true}}
  end

  def filter_event(event, _state), do: {:ok, event}
  def handle_event(_event, state), do: {:ok, state}
end

defmodule Raxol.Test.Plugins.NoFilterPlugin do
  @moduledoc """
  Test fixture: a plugin without filter_event callback.
  """
  def handle_event(_event, state), do: {:ok, state}
end

defmodule Raxol.Test.Plugins.CallbackTestPlugin do
  @moduledoc """
  Test fixture: a plugin with various callbacks for testing.
  """
  def init(config), do: {:ok, config}
  def on_load, do: :loaded
  def handle_event(_event, state), do: {:ok, state}
  def filter_event(event, _state), do: {:ok, event}
end
