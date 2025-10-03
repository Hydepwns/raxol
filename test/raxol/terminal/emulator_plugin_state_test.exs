defmodule Raxol.Terminal.EmulatorPluginStateTest do
  use ExUnit.Case
  alias Raxol.Test.TestUtils

  setup context do
    Raxol.EmulatorPluginTestHelper.setup_emulator_plugin_test(context)
  end
end
