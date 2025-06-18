defmodule Raxol.Test.Support.Mocks do
  @moduledoc '''
  Provides mock implementations for testing.
  This module defines all the necessary mocks for the test suite.
  '''

  # Import Mox at the module level
  import Mox

  # Core mocks
  defmock(FileWatcherMock,
    for: Raxol.Core.Runtime.Plugins.FileWatcher.Behaviour
  )

  defmock(LoaderMock, for: Raxol.Core.Runtime.Plugins.LoaderBehaviour)
  defmock(AccessibilityMock, for: Raxol.Core.Accessibility.Behaviour)
  defmock(ClipboardMock, for: Raxol.Core.Clipboard.Behaviour)

  # Runtime plugin mocks
  defmock(Raxol.Core.Runtime.Plugins.FileWatcherMock,
    for: Raxol.Core.Runtime.Plugins.FileWatcher.Behaviour
  )

  defmock(Raxol.Core.Runtime.Plugins.LoaderMock,
    for: Raxol.Core.Runtime.Plugins.LoaderBehaviour
  )

  defmock(Raxol.Core.Runtime.Plugins.LifecycleHelperMock,
    for: Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  )

  defmock(Raxol.Core.Runtime.Plugins.EdgeCasesLifecycleHelperMock,
    for: Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  )

  # System mocks
  defmock(Raxol.System.DeltaUpdaterSystemAdapterMock,
    for: Raxol.System.DeltaUpdaterSystemAdapterBehaviour
  )

  defmock(Raxol.Terminal.Config.EnvironmentAdapterMock,
    for: Raxol.Terminal.Config.EnvironmentAdapterBehaviour
  )

  defmock(FileSystemMock, for: FileSystem.Behaviour)
  defmock(SystemInteractionMock, for: Raxol.System.Interaction)

  # Feature mocks
  defmock(Raxol.Mocks.KeyboardShortcutsMock,
    for: Raxol.Core.KeyboardShortcutsBehaviour
  )

  defmock(Raxol.Mocks.AccessibilityMock,
    for: Raxol.Core.Accessibility.Behaviour
  )

  defmock(Raxol.Mocks.ClipboardMock, for: Raxol.Core.Clipboard.Behaviour)

  # Terminal mocks
  defmock(Raxol.Terminal.ANSI.SixelGraphicsMock,
    for: Raxol.Terminal.ANSI.SixelGraphics.Behaviour
  )

  defmock(Raxol.Terminal.Parser.StateMock,
    for: Raxol.Terminal.Parser.StateBehaviour
  )

  defmock(Raxol.Terminal.ScreenBufferMock,
    for: Raxol.Terminal.ScreenBufferBehaviour
  )

  defmock(Raxol.Terminal.EmulatorMock,
    for: Raxol.Terminal.EmulatorBehaviour
  )

  # Plugin mocks
  defmock(Raxol.Core.Plugins.Core.ClipboardPluginMock,
    for: Raxol.Core.Plugins.Core.ClipboardPluginBehaviour
  )

  defmock(Raxol.Core.Runtime.Plugins.PluginEventFilterMock,
    for: Raxol.Core.Runtime.Plugins.PluginEventFilter.Behaviour
  )

  defmock(Raxol.Core.Runtime.Plugins.PluginCommandDispatcherMock,
    for: Raxol.Core.Runtime.Plugins.PluginCommandDispatcher.Behaviour
  )

  defmock(Raxol.Core.Runtime.Plugins.PluginReloaderMock,
    for: Raxol.Core.Runtime.Plugins.PluginReloader.Behaviour
  )

  defmock(Raxol.Core.Runtime.Plugins.PluginCommandHandlerMock,
    for: Raxol.Core.Runtime.Plugins.PluginCommandHandler.Behaviour
  )

  defmock(Raxol.Core.Runtime.Plugins.TimerManagerMock,
    for: Raxol.Core.Runtime.Plugins.TimerManager.Behaviour
  )

  # Rendering mocks
  defmock(Raxol.Core.Runtime.Rendering.EngineMock,
    for: Raxol.Core.Runtime.Rendering.Engine.Behaviour
  )

  # Event mocks
  defmock(Raxol.Core.Events.ManagerMock,
    for: Raxol.Core.Events.Manager.Behaviour
  )

  # Terminal buffer mocks
  defmock(Raxol.Terminal.Buffer.ManagerMock,
    for: Raxol.Terminal.Buffer.Manager.Behaviour
  )

  defmock(Raxol.Terminal.Buffer.ScrollbackMock,
    for: Raxol.Terminal.Buffer.Scrollback.Behaviour
  )

  defmock(Raxol.Terminal.Buffer.ScrollRegionMock,
    for: Raxol.Terminal.Buffer.ScrollRegion.Behaviour
  )

  defmock(Raxol.Terminal.Buffer.SelectionMock,
    for: Raxol.Terminal.Buffer.Selection.Behaviour
  )

  defmock(Raxol.Terminal.Buffer.QueriesMock,
    for: Raxol.Terminal.Buffer.Queries.Behaviour
  )

  defmock(Raxol.Terminal.Buffer.LineOperationsMock,
    for: Raxol.Terminal.Buffer.LineOperations.Behaviour
  )

  @doc '''
  Sets up all mocks with default implementations.
  This should be called in the setup block of your tests.
  '''
  def setup_mocks do
    # Set up default implementations for all mocks
    # Core mocks
    stub_with(
      FileWatcherMock,
      Raxol.Test.Support.MockImplementations.FileWatcherMock
    )

    stub_with(LoaderMock, Raxol.Test.Support.MockImplementations.LoaderMock)

    stub_with(
      AccessibilityMock,
      Raxol.Test.Support.MockImplementations.AccessibilityMock
    )

    stub_with(
      ClipboardMock,
      Raxol.Test.Support.MockImplementations.ClipboardMock
    )

    # Runtime plugin mocks
    stub_with(
      Raxol.Core.Runtime.Plugins.FileWatcherMock,
      Raxol.Test.Support.MockImplementations.FileWatcherMock
    )

    stub_with(
      Raxol.Core.Runtime.Plugins.LoaderMock,
      Raxol.Test.Support.MockImplementations.LoaderMock
    )

    stub_with(
      Raxol.Core.Runtime.Plugins.LifecycleHelperMock,
      Raxol.Test.Support.MockImplementations.LifecycleHelperMock
    )

    stub_with(
      Raxol.Core.Runtime.Plugins.EdgeCasesLifecycleHelperMock,
      Raxol.Test.Support.MockImplementations.LifecycleHelperMock
    )

    # System mocks
    stub_with(
      Raxol.System.DeltaUpdaterSystemAdapterMock,
      Raxol.Test.Support.MockImplementations.DeltaUpdaterSystemAdapterMock
    )

    stub_with(
      Raxol.Terminal.Config.EnvironmentAdapterMock,
      Raxol.Test.Support.MockImplementations.EnvironmentAdapterMock
    )

    stub_with(
      FileSystemMock,
      Raxol.Test.Support.MockImplementations.FileSystemMock
    )

    stub_with(
      SystemInteractionMock,
      Raxol.Test.Support.MockImplementations.SystemInteractionMock
    )

    # Feature mocks
    stub_with(
      Raxol.Mocks.KeyboardShortcutsMock,
      Raxol.Test.Support.MockImplementations.KeyboardShortcutsMock
    )

    stub_with(
      Raxol.Mocks.AccessibilityMock,
      Raxol.Test.Support.MockImplementations.AccessibilityMock
    )

    stub_with(
      Raxol.Mocks.ClipboardMock,
      Raxol.Test.Support.MockImplementations.ClipboardMock
    )

    # Terminal mocks
    stub_with(
      Raxol.Terminal.ANSI.SixelGraphicsMock,
      Raxol.Test.Support.MockImplementations.SixelGraphicsMock
    )

    stub_with(
      Raxol.Terminal.Parser.StateMock,
      Raxol.Test.Support.MockImplementations.StateMock
    )

    stub_with(
      Raxol.Terminal.ScreenBufferMock,
      Raxol.Test.Support.MockImplementations.ScreenBufferMock
    )

    stub_with(
      Raxol.Terminal.EmulatorMock,
      Raxol.Test.Support.MockImplementations.EmulatorMock
    )

    # Plugin mocks
    stub_with(
      Raxol.Core.Plugins.Core.ClipboardPluginMock,
      Raxol.Test.Support.MockImplementations.ClipboardPluginMock
    )

    stub_with(
      Raxol.Core.Runtime.Plugins.PluginEventFilterMock,
      Raxol.Test.Support.MockImplementations.PluginEventFilterMock
    )

    stub_with(
      Raxol.Core.Runtime.Plugins.PluginCommandDispatcherMock,
      Raxol.Test.Support.MockImplementations.PluginCommandDispatcherMock
    )

    stub_with(
      Raxol.Core.Runtime.Plugins.PluginReloaderMock,
      Raxol.Test.Support.MockImplementations.PluginReloaderMock
    )

    stub_with(
      Raxol.Core.Runtime.Plugins.PluginCommandHandlerMock,
      Raxol.Test.Support.MockImplementations.PluginCommandHandlerMock
    )

    stub_with(
      Raxol.Core.Runtime.Plugins.TimerManagerMock,
      Raxol.Test.Support.MockImplementations.TimerManagerMock
    )

    # Rendering mocks
    stub_with(
      Raxol.Core.Runtime.Rendering.EngineMock,
      Raxol.Test.Support.MockImplementations.EngineMock
    )

    # Event mocks
    stub_with(
      Raxol.Core.Events.ManagerMock,
      Raxol.Test.Support.MockImplementations.EventManagerMock
    )

    # Terminal buffer mocks
    stub_with(
      Raxol.Terminal.Buffer.ManagerMock,
      Raxol.Test.Support.MockImplementations.BufferManagerMock
    )

    stub_with(
      Raxol.Terminal.Buffer.ScrollbackMock,
      Raxol.Test.Support.MockImplementations.BufferScrollbackMock
    )

    stub_with(
      Raxol.Terminal.Buffer.ScrollRegionMock,
      Raxol.Test.Support.MockImplementations.BufferScrollRegionMock
    )

    stub_with(
      Raxol.Terminal.Buffer.SelectionMock,
      Raxol.Test.Support.MockImplementations.BufferSelectionMock
    )

    stub_with(
      Raxol.Terminal.Buffer.QueriesMock,
      Raxol.Test.Support.MockImplementations.BufferQueriesMock
    )

    stub_with(
      Raxol.Terminal.Buffer.LineOperationsMock,
      Raxol.Test.Support.MockImplementations.BufferLineOperationsMock
    )

    :ok
  end
end
