defmodule Raxol.IntegrationCase do
  @moduledoc """
  Test case helper for integration tests.

  Provides helper functions for end-to-end testing of applications.

  ## Example

      defmodule IntegrationTest do
        use Raxol.IntegrationCase

        @tag :integration
        test "full application flow" do
          {:ok, app} = start_app(MyApp)

          app
          |> navigate_to(:main_menu)
          |> select_option("New Document")
          |> type_text("Hello, World!")
          |> press_key([:ctrl, :s])

          assert file_exists?("document.txt")
        end
      end
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Raxol.IntegrationCase
    end
  end

  setup _tags do
    {:ok, %{}}
  end

  @doc """
  Start an application for integration testing.

  ## Example

      {:ok, app} = start_app(MyApp, config: [width: 80, height: 24])
  """
  def start_app(module, opts \\ []) do
    config = Keyword.get(opts, :config, [])

    app_state = %{
      module: module,
      config: config,
      state: init_app(module, config),
      history: []
    }

    {:ok, app_state}
  end

  @doc """
  Navigate to a specific screen or location in the app.
  """
  def navigate_to(app, location) do
    record_action(app, {:navigate, location})
  end

  @doc """
  Select an option from a menu or list.
  """
  def select_option(app, option) do
    record_action(app, {:select, option})
  end

  @doc """
  Type text into the current input.
  """
  def type_text(app, text) do
    record_action(app, {:type, text})
  end

  @doc """
  Press a key or key combination.

  ## Examples

      press_key(app, :enter)
      press_key(app, [:ctrl, :s])
  """
  def press_key(app, key) do
    record_action(app, {:press_key, key})
  end

  @doc """
  Check if a file exists.
  """
  def file_exists?(path) do
    File.exists?(path)
  end

  @doc """
  Get the current screen content.
  """
  def screen_content(app) do
    Map.get(app.state, :screen, "")
  end

  @doc """
  Wait for a condition to be true.

  ## Options

    - `:timeout` - Maximum wait time in milliseconds (default: 5000)
    - `:interval` - Check interval in milliseconds (default: 100)
  """
  def wait_for(condition_fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    interval = Keyword.get(opts, :interval, 100)

    wait_until(condition_fun, timeout, interval)
  end

  @doc """
  Get the action history for debugging.
  """
  def action_history(app) do
    app.history
  end

  # Private helpers

  defp init_app(module, config) do
    if function_exported?(module, :init, 1) do
      module.init(config)
    else
      %{screen: "", config: config}
    end
  end

  defp record_action(app, action) do
    %{app | history: app.history ++ [action]}
  end

  defp wait_until(condition_fun, timeout, interval) when timeout > 0 do
    if condition_fun.() do
      :ok
    else
      Process.sleep(interval)
      wait_until(condition_fun, timeout - interval, interval)
    end
  end

  defp wait_until(_condition_fun, _timeout, _interval) do
    {:error, :timeout}
  end
end
