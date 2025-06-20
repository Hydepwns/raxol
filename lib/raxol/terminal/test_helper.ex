defmodule Raxol.Terminal.TestHelper do
  @moduledoc """
  Test helper functions for Raxol.Terminal tests.

  This module delegates to Raxol.Test.Support.TestHelper to provide
  consistent test utilities across the terminal subsystem.
  """

  @doc """
  Creates a test emulator instance for testing.
  """
  def create_test_emulator do
    Raxol.Test.Support.TestHelper.create_test_emulator()
  end

  # Delegate other commonly used test helper functions
  defdelegate setup_test_env(), to: Raxol.Test.Support.TestHelper
  defdelegate setup_test_terminal(), to: Raxol.Test.Support.TestHelper
  defdelegate test_events(), to: Raxol.Test.Support.TestHelper

  defdelegate create_test_component(module, initial_state \\ %{}),
    to: Raxol.Test.Support.TestHelper

  defdelegate cleanup_test_env(context), to: Raxol.Test.Support.TestHelper
  defdelegate setup_common_mocks(), to: Raxol.Test.Support.TestHelper

  defdelegate create_test_plugin(name, config \\ %{}),
    to: Raxol.Test.Support.TestHelper

  defdelegate create_test_plugin_module(name, callbacks \\ %{}),
    to: Raxol.Test.Support.TestHelper
end
