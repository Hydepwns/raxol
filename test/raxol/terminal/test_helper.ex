defmodule Raxol.Terminal.TestHelper do
  @moduledoc """
  Helper functions for terminal tests.
  """

  alias Raxol.Terminal.Emulator

  @doc """
  Creates a test emulator instance with default settings.
  """
  def create_test_emulator do
    Emulator.new()
  end

  @doc """
  Creates a test emulator instance with custom settings.
  """
  def create_test_emulator(opts) do
    emulator = create_test_emulator()

    Enum.reduce(opts, emulator, fn {key, value}, acc ->
      case key do
        :settings -> set_settings(acc, value)
        :preferences -> set_preferences(acc, value)
        :environment -> set_environment(acc, value)
        _ -> acc
      end
    end)
  end

  defp set_settings(emulator, settings) do
    Enum.reduce(settings, emulator, fn {key, value}, acc ->
      Raxol.Terminal.Config.Manager.set_setting(acc, key, value)
    end)
  end

  defp set_preferences(emulator, preferences) do
    Enum.reduce(preferences, emulator, fn {key, value}, acc ->
      Raxol.Terminal.Config.Manager.set_preference(acc, key, value)
    end)
  end

  defp set_environment(emulator, env) do
    Raxol.Terminal.Config.Manager.set_environment_variables(emulator, env)
  end
end
