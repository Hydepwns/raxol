defmodule Raxol.Test.Mocks do
  @moduledoc """
  Defines all mocks used in tests.
  """

  import Mox

  # Define mocks for each behaviour
  defmock(AccessibilityMock, for: Raxol.Core.Accessibility.Behaviour)
  defmock(ClipboardMock, for: Raxol.Core.Clipboard.Behaviour)
end
