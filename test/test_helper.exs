ExUnit.start()

# Start the sandbox for database tests
Ecto.Adapters.SQL.Sandbox.mode(Raxol.Repo, :manual)

# Start the application for testing
Application.ensure_all_started(:raxol)

# Set up Mox for mocking
Mox.defmock(Raxol.Core.Runtime.Plugins.FileWatcherMock,
  for: Raxol.Core.Runtime.Plugins.FileWatcher.Behaviour
)

Mox.defmock(Raxol.Core.Runtime.Plugins.LoaderMock,
  for: Raxol.Core.Runtime.Plugins.Loader.Behaviour
)

Mox.defmock(Raxol.Core.Runtime.Plugins.LifecycleHelperMock,
  for: Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
)

Mox.defmock(Raxol.Core.Runtime.Plugins.EdgeCasesLifecycleHelperMock,
  for: Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
)

Mox.defmock(Raxol.System.DeltaUpdaterSystemAdapterMock,
  for: Raxol.System.DeltaUpdaterSystemAdapterBehaviour
)

Mox.defmock(Raxol.Terminal.Config.EnvironmentAdapterMock,
  for: Raxol.Terminal.Config.EnvironmentAdapterBehaviour
)

Mox.defmock(FileSystemMock, for: FileSystem.Behaviour)

Mox.defmock(SystemInteractionMock, for: Raxol.System.Interaction)

# Set up test environment
Application.put_env(:raxol, :test_mode, true)

# Ensure necessary applications are started
if Application.get_env(:raxol, :database_enabled, true) do
  Application.ensure_all_started(:ecto_sql)
end

Code.require_file("raxol/terminal/driver_test_helper.exs", __DIR__)

# Ensure all support helpers are loaded
Enum.each(
  Path.wildcard(Path.join([__DIR__, "support", "*.ex"])),
  &Code.require_file/1
)

Code.require_file("core/runtime/plugins/edge_cases/helper.ex", Path.join(__DIR__, "raxol"))

Enum.each(
  Path.wildcard(Path.join([__DIR__, "raxol/core/runtime/plugins/edge_cases", "*.ex"])),
  &Code.require_file/1
)
