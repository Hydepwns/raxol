defmodule Raxol.Terminal.EmulatorPluginCommandsTest do
  use ExUnit.Case

  alias Raxol.EmulatorPluginTestHelper

  setup context do
    Raxol.EmulatorPluginUnifiedTestHelper.setup_emulator_plugin_test(context)
  end
end
