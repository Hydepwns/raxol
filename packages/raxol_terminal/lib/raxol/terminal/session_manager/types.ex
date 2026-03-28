defmodule Raxol.Terminal.SessionManager.Session do
  @moduledoc """
  Terminal session structure.

  Represents a terminal multiplexing session with multiple windows, clients,
  and lifecycle management.
  """
  @enforce_keys [:id, :name, :created_at]
  defstruct [
    :id,
    :name,
    :created_at,
    :last_activity,
    :status,
    :metadata,
    :windows,
    :active_window,
    :clients,
    :persistence_config,
    :resource_limits,
    :hooks
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          created_at: integer(),
          last_activity: integer(),
          status: :active | :inactive | :detached,
          metadata: map(),
          windows: [term()],
          active_window: String.t() | nil,
          clients: [term()],
          persistence_config: map(),
          resource_limits: map(),
          hooks: map()
        }
end

defmodule Raxol.Terminal.SessionManager.Window do
  @moduledoc """
  Terminal window within a session.

  Represents an individual window/pane within a terminal session,
  containing an emulator and associated metadata.
  """
  @enforce_keys [:id, :session_id, :name]
  defstruct [
    :id,
    :session_id,
    :name,
    :created_at,
    :status,
    :layout,
    :panes,
    :active_pane,
    :metadata
  ]

  @type layout_type ::
          :main_horizontal
          | :main_vertical
          | :even_horizontal
          | :even_vertical
          | :tiled
  @type t :: %__MODULE__{
          id: String.t(),
          session_id: String.t(),
          name: String.t(),
          created_at: integer(),
          status: :active | :inactive,
          layout: layout_type(),
          panes: [term()],
          active_pane: String.t() | nil,
          metadata: map()
        }
end

defmodule Raxol.Terminal.SessionManager.Pane do
  @moduledoc """
  Terminal pane within a window.

  Represents an individual pane/split within a window, containing
  a terminal process and configuration.
  """
  @enforce_keys [:id, :window_id, :terminal]
  defstruct [
    :id,
    :window_id,
    :terminal,
    :position,
    :size,
    :command,
    :working_directory,
    :environment,
    :status,
    :created_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          window_id: String.t(),
          terminal: pid(),
          position: {integer(), integer()},
          size: {integer(), integer()},
          command: String.t() | nil,
          working_directory: String.t(),
          environment: map(),
          status: :running | :stopped | :finished,
          created_at: integer()
        }
end

defmodule Raxol.Terminal.SessionManager.Client do
  @moduledoc """
  Client connection to a session.

  Represents a client connected to a terminal session, tracking connection
  type, activity, terminal size, and capabilities.
  """
  @enforce_keys [:id, :session_id]
  defstruct [
    :id,
    :session_id,
    :connection_type,
    :connected_at,
    :last_activity,
    :terminal_size,
    :capabilities,
    :metadata
  ]

  @type connection_type :: :local | :remote | :shared
  @type t :: %__MODULE__{
          id: String.t(),
          session_id: String.t(),
          connection_type: connection_type(),
          connected_at: integer(),
          last_activity: integer(),
          terminal_size: {integer(), integer()},
          capabilities: [atom()],
          metadata: map()
        }
end
