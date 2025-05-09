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

  # NEW Mocks for Notification Plugin Tests
  # Mox.defmock(SystemMock, for: System)
  # Mox.defmock(NotificationPluginMock, for: Raxol.Core.Plugins.Core.NotificationPlugin)

  # Defmock accessibility operations - COMMENT OUT as Raxol.Core.Accessibility is not a behaviour
  # Mox.defmock(AccessibilityMock, for: Raxol.Core.Accessibility)

  # Mock for the SystemInteraction behaviour
  Mox.defmock(SystemInteractionMock, for: Raxol.Core.SystemInteraction)

  # Mock for the Accessibility Behaviour
  Mox.defmock(Raxol.Mocks.AccessibilityMock,
    for: Raxol.Core.Accessibility.Behaviour
  )

  # Mock for the FocusManager Behaviour
  Mox.defmock(Raxol.Mocks.FocusManagerMock,
    for: Raxol.Core.FocusManager.Behaviour
  )

  # Mock for the KeyboardShortcuts Behaviour
  Mox.defmock(Raxol.Mocks.KeyboardShortcutsMock,
    for: Raxol.Core.KeyboardShortcutsBehaviour
  )

  # Removed EventManagerBehaviour and defmock for EventManagerMock
end

# The Raxol.Core.Accessibility.Mock module definition below should be removed.
# defmodule Raxol.Core.Accessibility.Mock do
#   @moduledoc false
#   require Mox
#
#   # use Mox # <-- Temporarily commented out due to persistent UndefinedFunctionError
#
#   # Assuming this signature based on usage
#   # Mox.defmock(__MODULE__, [announce: 2], for: Raxol.Core.Accessibility)
# end
