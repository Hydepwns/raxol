defmodule Raxol.UI.Components.Input.TextInput do
  @moduledoc """
  A text input component for the Raxol UI system.
  """

  require Logger

  alias Raxol.Core.Events.Event
  alias Raxol.UI.Components.Base.Component
  alias Raxol.UI.Components.Input.TextInput.CharacterHandler
  alias Raxol.UI.Components.Input.TextInput.KeyHandler

  @behaviour Component

  @type props :: %{
          optional(:id) => String.t(),
          optional(:value) => String.t(),
          optional(:placeholder) => String.t(),
          optional(:on_change) => (String.t() -> any()),
          optional(:on_submit) => (String.t() -> any()),
          optional(:on_cancel) => (-> any()) | nil,
          optional(:theme) => map(),
          optional(:style) => map(),
          optional(:mask_char) => String.t() | nil,
          optional(:max_length) => integer() | nil,
          optional(:validator) => (String.t() -> boolean()) | nil
        }

  @type state :: %{
          cursor_pos: non_neg_integer(),
          focused: boolean(),
          value: String.t(),
          placeholder: String.t(),
          max_length: non_neg_integer() | nil,
          validator: (String.t() -> boolean()) | nil,
          on_submit: (String.t() -> any()) | nil,
          on_change: (String.t() -> any()) | nil,
          mask_char: String.t() | nil,
          theme: map(),
          style: map()
        }

  require Raxol.Core.Runtime.Log

  @doc """
  Initializes the TextInput component state from the given props.
  """
  @impl Component
  @spec init(map()) :: {:ok, map()}
  def init(props) do
    initial_state = %{
      value: props[:value] || "",
      cursor_pos: 0,
      focused: false,
      placeholder: props[:placeholder] || "",
      max_length: props[:max_length],
      validator: props[:validator],
      on_submit: props[:on_submit],
      on_change: props[:on_change],
      mask_char: props[:mask_char],
      theme: props[:theme] || %{},
      style: props[:style] || %{}
    }

    {:ok, initial_state}
  end

  @doc """
  Handles events for the TextInput component, such as keypresses, focus, blur, and mouse events.
  """
  @impl Component
  @spec handle_event(map(), map(), map()) :: {map(), list()}
  def handle_event(state, %Event{type: :key, data: key_data}, _context) do
    KeyHandler.handle_key(state, key_data.key, key_data.modifiers || [])
  end

  def handle_event(state, %{type: :focus}, _context) do
    new_state = %{state | focused: true}
    {new_state, []}
  end

  def handle_event(state, %{type: :blur}, _context) do
    new_state = %{state | focused: false}
    {new_state, []}
  end

  def handle_event(state, %{type: :mouse}, _context) do
    new_state = %{state | focused: true}
    {new_state, []}
  end

  def handle_event(state, _event, _context) do
    {state, []}
  end

  @doc """
  Updates the TextInput component state in response to messages or prop changes.
  """
  @impl Component
  @spec update(term(), map()) :: map()
  def update({:update_props, new_props}, state) do
    # Update state with new props while preserving internal state
    updated_state = Map.merge(state, Map.new(new_props))

    # Handle cursor position when value changes
    has_value = Map.has_key?(new_props, :value)
    handle_value_update(has_value, updated_state, new_props)
  end

  def update(message, state) do
    Raxol.Core.Runtime.Log.debug(
      "[TextInput] Received unhandled message: #{inspect(message)}"
    )

    state
  end

  defp handle_value_update(false, updated_state, _new_props), do: updated_state

  defp handle_value_update(true, updated_state, new_props) do
    new_value = new_props.value
    value_length = String.length(new_value)
    # Move cursor to end of new value
    %{updated_state | cursor_pos: value_length}
  end

  @doc """
  Mounts the TextInput component. Performs any setup needed after initialization.
  """
  @impl Component
  @spec mount(map()) :: map()
  def mount(state), do: state

  @doc """
  Unmounts the TextInput component, performing any necessary cleanup.
  """
  @impl Component
  @spec unmount(map()) :: map()
  def unmount(state), do: state

  @doc """
  Renders the TextInput component using the current state and context.
  """
  @impl Component
  @spec render(map(), map()) :: any()
  def render(state, _context) do
    value = state.value
    placeholder = state.placeholder

    masked_text = get_masked_text(state.mask_char, value)
    display_text = get_display_text(value == "", placeholder, masked_text)

    merged_style =
      Map.merge(state.theme[:input] || %{}, state.style[:input] || %{})

    %{
      type: :text_input,
      text: display_text,
      cursor_pos: state.cursor_pos,
      focused: state.focused,
      style: merged_style
    }
  end

  defp get_masked_text(nil, value), do: value

  defp get_masked_text(mask_char, value) do
    String.duplicate(mask_char, String.length(value))
  end

  defp get_display_text(true, placeholder, _masked_text), do: placeholder
  defp get_display_text(false, _placeholder, masked_text), do: masked_text
end

defmodule Raxol.UI.Components.Input.TextInput.KeyHandler do
  @moduledoc false
  alias Raxol.UI.Components.Input.TextInput.{
    CharacterHandler,
    NavigationHandler,
    EditingHandler
  }

  def handle_key(state, :enter, _modifiers), do: handle_enter(state)
  def handle_key(state, :escape, _modifiers), do: handle_escape(state)

  def handle_key(state, :backspace, _modifiers),
    do: EditingHandler.handle_backspace(state)

  def handle_key(state, :delete, _modifiers),
    do: EditingHandler.handle_delete(state)

  def handle_key(state, :left, _modifiers),
    do: NavigationHandler.handle_left(state)

  def handle_key(state, :right, _modifiers),
    do: NavigationHandler.handle_right(state)

  def handle_key(state, :home, _modifiers),
    do: NavigationHandler.handle_home(state)

  def handle_key(state, :end, _modifiers),
    do: NavigationHandler.handle_end(state)

  def handle_key(state, char_key, []),
    do: CharacterHandler.handle_character(state, char_key)

  def handle_key(state, _key, _modifiers), do: {state, []}

  @spec handle_enter(map()) :: {map(), list()}
  defp handle_enter(state) do
    handle_submit_callback(is_function(state.on_submit, 1), state)
    {state, []}
  end

  @spec handle_submit_callback(boolean(), map()) :: :ok | any()
  defp handle_submit_callback(false, _state), do: :ok

  defp handle_submit_callback(true, state) do
    state.on_submit.(state.value)
  end

  @spec handle_escape(map()) :: {map(), list()}
  defp handle_escape(state) do
    new_state = %{state | focused: false}
    {new_state, []}
  end
end

defmodule Raxol.UI.Components.Input.TextInput.NavigationHandler do
  @moduledoc false

  def handle_left(state) do
    can_move = state.cursor_pos > 0
    handle_left_movement(can_move, state)
  end

  @spec handle_left_movement(boolean(), map()) :: {map(), list()}
  defp handle_left_movement(false, state), do: {state, []}

  defp handle_left_movement(true, state) do
    new_cursor_pos = state.cursor_pos - 1
    new_state = %{state | cursor_pos: new_cursor_pos}
    {new_state, []}
  end

  def handle_right(state) do
    current_value = state.value || ""
    can_move = state.cursor_pos < String.length(current_value)
    handle_right_movement(can_move, state)
  end

  defp handle_right_movement(false, state), do: {state, []}

  defp handle_right_movement(true, state) do
    new_cursor_pos = state.cursor_pos + 1
    new_state = %{state | cursor_pos: new_cursor_pos}
    {new_state, []}
  end

  def handle_home(state) do
    new_state = %{state | cursor_pos: 0}
    {new_state, []}
  end

  def handle_end(state) do
    current_value = state.value || ""
    new_state = %{state | cursor_pos: String.length(current_value)}
    {new_state, []}
  end
end

defmodule Raxol.UI.Components.Input.TextInput.EditingHandler do
  @moduledoc false

  def handle_backspace(state) do
    current_pos = state.cursor_pos
    current_value = state.value || ""
    can_delete = current_pos > 0
    handle_backspace_operation(can_delete, state, current_pos, current_value)
  end

  defp handle_backspace_operation(false, state, _current_pos, _current_value) do
    {state, []}
  end

  defp handle_backspace_operation(true, state, current_pos, current_value) do
    before_part = String.slice(current_value, 0..(current_pos - 2))
    remaining_part = String.slice(current_value, current_pos..-1//1)
    before = before_part || ""
    remaining = remaining_part || ""
    new_value = before <> remaining
    new_state = %{state | cursor_pos: current_pos - 1, value: new_value}
    emit_change_side_effect(state, new_value)
    {new_state, []}
  end

  def handle_delete(state) do
    current_pos = state.cursor_pos
    current_value = state.value || ""
    can_delete = current_pos < String.length(current_value)
    handle_delete_operation(can_delete, state, current_pos, current_value)
  end

  defp handle_delete_operation(false, state, _current_pos, _current_value) do
    {state, []}
  end

  defp handle_delete_operation(true, state, current_pos, current_value) do
    before = String.slice(current_value, 0, current_pos)
    after_text = String.slice(current_value, (current_pos + 1)..-1//1) || ""
    new_value = before <> after_text
    new_state = %{state | value: new_value}
    emit_change_side_effect(state, new_value)
    {new_state, []}
  end

  defp emit_change_side_effect(state, new_value) do
    handle_change_callback(is_function(state.on_change, 1), state, new_value)
  end

  defp handle_change_callback(false, _state, _new_value), do: :ok

  defp handle_change_callback(true, state, new_value) do
    state.on_change.(new_value)
  end
end
