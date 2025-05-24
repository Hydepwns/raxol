defmodule Raxol.Terminal.State.Manager do
  @moduledoc """
  Manages terminal state including modes, character sets, and state stack.
  """

  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ANSI.TerminalState
  alias Raxol.Terminal.ModeManager
  require Logger

  @type t :: %__MODULE__{
          mode_manager: ModeManager.t(),
          charset_state: CharacterSets.charset_state(),
          state_stack: TerminalState.t(),
          scroll_region: {non_neg_integer(), non_neg_integer()} | nil,
          last_col_exceeded: boolean(),
          current_hyperlink_url: String.t() | nil,
          window_title: String.t() | nil,
          icon_name: String.t() | nil
        }

  defstruct mode_manager: ModeManager.new(),
            charset_state: CharacterSets.new(),
            state_stack: TerminalState.new(),
            scroll_region: nil,
            last_col_exceeded: false,
            current_hyperlink_url: nil,
            window_title: nil,
            icon_name: nil

  @doc """
  Creates a new state manager with default values.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Gets the current mode manager state.
  """
  def get_mode_manager(%__MODULE__{} = state) do
    state.mode_manager
  end

  @doc """
  Updates the mode manager state.
  """
  def update_mode_manager(%__MODULE__{} = state, mode_manager) do
    %{state | mode_manager: mode_manager}
  end

  @doc """
  Gets the current character set state.
  """
  def get_charset_state(%__MODULE__{} = state) do
    state.charset_state
  end

  @doc """
  Updates the character set state.
  """
  def update_charset_state(%__MODULE__{} = state, charset_state) do
    %{state | charset_state: charset_state}
  end

  @doc """
  Gets the current state stack.
  """
  def get_state_stack(%__MODULE__{} = state) do
    state.state_stack
  end

  @doc """
  Updates the state stack.
  """
  def update_state_stack(%__MODULE__{} = state, state_stack) do
    %{state | state_stack: state_stack}
  end

  @doc """
  Gets the current scroll region.
  """
  def get_scroll_region(%__MODULE__{} = state) do
    state.scroll_region
  end

  @doc """
  Updates the scroll region.
  """
  def update_scroll_region(%__MODULE__{} = state, scroll_region) do
    %{state | scroll_region: scroll_region}
  end

  @doc """
  Gets whether the last column was exceeded.
  """
  def get_last_col_exceeded(%__MODULE__{} = state) do
    state.last_col_exceeded
  end

  @doc """
  Updates the last column exceeded flag.
  """
  def update_last_col_exceeded(%__MODULE__{} = state, last_col_exceeded) do
    %{state | last_col_exceeded: last_col_exceeded}
  end

  @doc """
  Gets the current hyperlink URL.
  """
  def get_hyperlink_url(%__MODULE__{} = state) do
    state.current_hyperlink_url
  end

  @doc """
  Updates the current hyperlink URL.
  """
  def update_hyperlink_url(%__MODULE__{} = state, url) do
    %{state | current_hyperlink_url: url}
  end

  @doc """
  Gets the current window title.
  """
  def get_window_title(%__MODULE__{} = state) do
    state.window_title
  end

  @doc """
  Updates the window title.
  """
  def update_window_title(%__MODULE__{} = state, title) do
    %{state | window_title: title}
  end

  @doc """
  Gets the current icon name.
  """
  def get_icon_name(%__MODULE__{} = state) do
    state.icon_name
  end

  @doc """
  Updates the icon name.
  """
  def update_icon_name(%__MODULE__{} = state, name) do
    %{state | icon_name: name}
  end

  @doc """
  Saves the current state to the state stack.
  """
  def save_state(%__MODULE__{} = state) do
    new_stack = TerminalState.push(state.state_stack, state)
    %{state | state_stack: new_stack}
  end

  @doc """
  Restores the previous state from the state stack.
  """
  def restore_state(%__MODULE__{} = state) do
    case TerminalState.pop(state.state_stack) do
      {nil, new_stack} ->
        %{state | state_stack: new_stack}

      {saved_state, new_stack} ->
        %{state | state_stack: new_stack}
        |> Map.merge(saved_state)
    end
  end
end
