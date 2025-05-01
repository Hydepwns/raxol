defmodule Raxol.Test.Mocks do
  @moduledoc """
  Container for test mocks.
  """

  require Mox

  # Define the global mock for Clipboard Behaviour
  Mox.defmock(ClipboardMock, for: Raxol.System.Clipboard.Behaviour)

  # Actual mock definitions (like Accessibility.Mock) are commented out here or removed
  # to avoid Mox compilation issues.

  # Add other non-Mox helper functions or structs for testing if needed.
end

defmodule Raxol.Core.Accessibility.Mock do
  @moduledoc false
  require Mox

  # use Mox # <-- Temporarily commented out due to persistent UndefinedFunctionError

  # Assuming this signature based on usage
  # Mox.defmock(__MODULE__, [announce: 2], for: Raxol.Core.Accessibility)
end
