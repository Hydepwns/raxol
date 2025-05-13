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

  # Mock for the SystemInteraction behaviour
  Mox.defmock(SystemInteractionMock, for: Raxol.Core.SystemInteraction)

  # Mock for the Manager Behaviour
  Mox.defmock(ManagerMock, for: Raxol.Core.Runtime.Plugins.Manager.Behaviour)

  # Global mock for File behaviour
  Mox.defmock(FileMock, for: File.Behaviour)
end
