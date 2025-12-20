defmodule Raxol.Test.IsolatedCase do
  @moduledoc """
  ExUnit.CaseTemplate that provides automatic test isolation.

  Use this module instead of `ExUnit.Case` for tests that need
  isolation from global state (AccessibilityServer, EventManager, UserPreferences).

  ## Usage

      defmodule MyTest do
        use Raxol.Test.IsolatedCase

        test "my isolated test" do
          # Global state is reset before this test runs
        end
      end

  ## Options

  Supports all options from `ExUnit.Case`:

      use Raxol.Test.IsolatedCase, async: false
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import ExUnit.Assertions
      import ExUnit.Callbacks
    end
  end

  setup do
    Raxol.Test.IsolationHelper.reset_global_state()
    :ok
  end
end
