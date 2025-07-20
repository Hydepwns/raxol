defmodule Raxol.Core.Runtime.Plugins.DependencyManager.IntegrationTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager

  # This file now serves as a test suite coordinator
  # The actual tests have been split into focused modules:
  # - BasicIntegrationTest: Core dependency and loading tests
  # - LifecycleIntegrationTest: Plugin lifecycle event tests
  # - ConcurrencyIntegrationTest: Concurrent operations tests
  # - CommunicationIntegrationTest: Plugin communication tests

  describe "integration test suite" do
    test ~c"all focused test modules are properly structured" do
      # This test ensures our refactoring maintains the test structure
      assert Code.ensure_loaded(Raxol.Core.Runtime.Plugins.DependencyManager.BasicIntegrationTest)
      assert Code.ensure_loaded(Raxol.Core.Runtime.Plugins.DependencyManager.LifecycleIntegrationTest)
      assert Code.ensure_loaded(Raxol.Core.Runtime.Plugins.DependencyManager.ConcurrencyIntegrationTest)
      assert Code.ensure_loaded(Raxol.Core.Runtime.Plugins.DependencyManager.CommunicationIntegrationTest)
    end
  end
end
