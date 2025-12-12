defmodule Raxol.Test.Setup do
  @moduledoc """
  Test environment setup utilities for Raxol.

  Provides functions to initialize the test environment with proper
  configuration and mocking support.

  ## Example

      # In test_helper.exs
      Raxol.Test.Setup.start()

      # Or with options
      Raxol.Test.Setup.start(
        mock_terminal: true,
        async: true
      )
  """

  @doc """
  Start the test environment.

  This initializes all necessary services and configurations for testing.

  ## Options

    - `:mock_terminal` - Use mock terminal driver (default: true)
    - `:async` - Enable async test support (default: true)
    - `:capture_log` - Capture log output during tests (default: true)
    - `:sandbox` - Use Ecto sandbox mode if available (default: true)

  ## Example

      Raxol.Test.Setup.start()
  """
  @spec start(keyword()) :: :ok
  def start(opts \\ []) do
    mock_terminal = Keyword.get(opts, :mock_terminal, true)
    capture_log = Keyword.get(opts, :capture_log, true)

    # Configure ExUnit
    ExUnit.configure(
      capture_log: capture_log,
      exclude: [:skip, :pending]
    )

    # Set up test environment
    Application.put_env(:raxol, :env, :test)

    # Configure mock terminal if requested
    if mock_terminal do
      Application.put_env(:raxol, :terminal_driver, :mock)
    end

    # Start ExUnit
    ExUnit.start()

    :ok
  end

  @doc """
  Configure test-specific settings.

  ## Example

      Raxol.Test.Setup.configure(
        timeout: 10_000,
        seed: 12345
      )
  """
  @spec configure(keyword()) :: :ok
  def configure(opts) do
    ExUnit.configure(opts)
    :ok
  end

  @doc """
  Set up a clean test context.

  Returns a map that can be used in test setup blocks.

  ## Example

      setup do
        Raxol.Test.Setup.setup_context()
      end
  """
  @spec setup_context(keyword()) :: map()
  def setup_context(opts \\ []) do
    %{
      test_id: generate_test_id(),
      started_at: System.monotonic_time(),
      opts: opts
    }
  end

  @doc """
  Clean up after tests.

  ## Example

      on_exit fn ->
        Raxol.Test.Setup.cleanup(context)
      end
  """
  @spec cleanup(map()) :: :ok
  def cleanup(_context) do
    # Clean up any test-specific resources
    :ok
  end

  @doc """
  Generate a unique test identifier.
  """
  @spec generate_test_id() :: String.t()
  def generate_test_id do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Check if we're running in test mode.
  """
  @spec test_mode?() :: boolean()
  def test_mode? do
    Application.get_env(:raxol, :env) == :test
  end

  @doc """
  Get the test timeout value.
  """
  @spec timeout() :: pos_integer()
  def timeout do
    Application.get_env(:raxol, :test_timeout, 60_000)
  end
end
