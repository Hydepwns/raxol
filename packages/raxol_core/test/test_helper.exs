ExUnit.start()

# Configure test mode
Application.put_env(:raxol, :test_mode, true)
Application.put_env(:raxol, :core, test_mode: true)
Application.put_env(:raxol, :plugins, test_mode: true)

# Configure Mox mocks for behaviours defined in raxol_core
if Code.ensure_loaded?(Mox) do
  # Plugin runtime mocks
  Mox.defmock(Raxol.Core.Runtime.Plugins.FileWatcherMock,
    for: Raxol.Core.Runtime.Plugins.FileWatcherBehaviour
  )

  Mox.defmock(Raxol.Core.Runtime.Plugins.LoaderMock,
    for: Raxol.Core.Runtime.Plugins.LoaderBehaviour
  )

  Mox.defmock(Raxol.Core.Runtime.Plugins.LifecycleHelperMock,
    for: Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  )

  Mox.defmock(Raxol.Core.Runtime.Plugins.PluginEventFilterMock,
    for: Raxol.Core.Runtime.Plugins.PluginEventFilter.Behaviour
  )

  Mox.defmock(Raxol.Core.Runtime.Plugins.PluginReloaderMock,
    for: Raxol.Core.Runtime.Plugins.PluginReloader.Behaviour
  )

  Mox.defmock(Raxol.Core.Runtime.Plugins.PluginCommandHandlerMock,
    for: Raxol.Core.Runtime.Plugins.PluginCommandHandler.Behaviour
  )

  # Accessibility and UX mocks
  Mox.defmock(Raxol.Mocks.AccessibilityMock,
    for: Raxol.Core.Accessibility.Behaviour
  )

  Mox.defmock(Raxol.Mocks.FocusManagerMock,
    for: Raxol.Core.FocusManager.Behaviour
  )

  Mox.defmock(Raxol.Mocks.KeyboardShortcutsMock,
    for: Raxol.Core.KeyboardShortcutsBehaviour
  )
end
