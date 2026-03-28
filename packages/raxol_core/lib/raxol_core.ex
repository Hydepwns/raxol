defmodule RaxolCore do
  @moduledoc """
  Core behaviours, utilities, events, config, accessibility, and plugin
  infrastructure for Raxol.

  This package contains leaf modules with zero external runtime dependencies.
  GenServers defined here are started by the parent application's supervision
  tree, not auto-started.

  ## Modules

  - `Raxol.Core.Behaviours.*` - BaseManager, BaseRegistry, BaseServer, etc.
  - `Raxol.Core.Runtime.Log` - Centralized logging
  - `Raxol.Core.Utils.*` - Debounce, validation, timer utilities
  - `Raxol.Core.Events.*` - Event system (manager, subscriptions, telemetry)
  - `Raxol.Core.Config.*` - Configuration management
  - `Raxol.Core.Accessibility.*` - Screen reader, focus, announcements
  - `Raxol.Core.Runtime.Plugins.*` - Plugin lifecycle, registry, security
  """

  @doc """
  Returns the version of RaxolCore.
  """
  def version, do: unquote(Mix.Project.config()[:version])
end
