defmodule Raxol.UI.Components.Input.TextInput do
  @moduledoc """
  A text input component for capturing user text input.

  Features:
  * Customizable placeholder text
  * Value binding
  * Focus handling
  * Character validation
  * Input masking (for password fields)
  * Event callbacks
  """

  import Raxol.Guards

  alias Raxol.UI.Components.Base.Component
  alias Raxol.Core.Events.Event
  alias Raxol.UI.Components.Input.TextInput.KeyHandler
  alias Raxol.UI.Components.Input.TextInput.CharacterHandler
  # alias Raxol.View
  # alias Raxol.View.Style
  # alias Raxol.Core.Events

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
  @impl true
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
  @impl true
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
  @impl true
  @spec update(term(), map()) :: map()
  def update(message, state) do
    Raxol.Core.Runtime.Log.debug(
      "[TextInput] Received unhandled message: #{inspect(message)}"
    )

    state
  end

  @doc """
  Mounts the TextInput component. Performs any setup needed after initialization.
  """
  @impl true
  @spec mount(map()) :: map()
  def mount(state), do: state

  @doc """
  Unmounts the TextInput component, performing any necessary cleanup.
  """
  @impl true
  @spec unmount(map()) :: map()
  def unmount(state), do: state

  @doc """
  Renders the TextInput component using the current state and context.
  """
  @impl true
  @spec render(map(), map()) :: any()
  def render(state, _context) do
    value = state.value
    placeholder = state.placeholder

    masked_text =
      if state.mask_char do
        String.duplicate(state.mask_char, String.length(value))
      else
        value
      end

    display_text = if(value == "", do: placeholder, else: masked_text)

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

  defp emit_change_side_effect(state, new_value) do
    if is_function(state.on_change, 1) do
      state.on_change.(new_value)
    end
  end
end

defmodule Raxol.UI.Components.Input.TextInput.KeyHandler do
  @moduledoc false
  alias Raxol.UI.Components.Input.TextInput.{
    CharacterHandler,
    NavigationHandler,
    EditingHandler
  }

  def handle_key(state, key, modifiers) do
    case {key, modifiers} do
      {:enter, _} -> handle_enter(state)
      {:escape, _} -> handle_escape(state)
      {:backspace, _} -> EditingHandler.handle_backspace(state)
      {:delete, _} -> EditingHandler.handle_delete(state)
      {:left, _} -> NavigationHandler.handle_left(state)
      {:right, _} -> NavigationHandler.handle_right(state)
      {:home, _} -> NavigationHandler.handle_home(state)
      {:end, _} -> NavigationHandler.handle_end(state)
      {char_key, []} -> CharacterHandler.handle_character(state, char_key)
      _ -> {state, []}
    end
  end

  defp handle_enter(state) do
    if is_function(state.on_submit, 1) do
      state.on_submit.(state.value)
    end

    {state, []}
  end

  defp handle_escape(state) do
    new_state = %{state | focused: false}
    {new_state, []}
  end
end

defmodule Raxol.UI.Components.Input.TextInput.NavigationHandler do
  @moduledoc false

  def handle_left(state) do
    if state.cursor_pos > 0 do
      new_cursor_pos = state.cursor_pos - 1
      new_state = %{state | cursor_pos: new_cursor_pos}
      {new_state, []}
    else
      {state, []}
    end
  end

  def handle_right(state) do
    current_value = state.value || ""

    if state.cursor_pos < String.length(current_value) do
      new_cursor_pos = state.cursor_pos + 1
      new_state = %{state | cursor_pos: new_cursor_pos}
      {new_state, []}
    else
      {state, []}
    end
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

    if current_pos > 0 do
      before_part = String.slice(current_value, 0..(current_pos - 2))
      remaining_part = String.slice(current_value, current_pos..-1//1)
      before = before_part || ""
      remaining = remaining_part || ""
      new_value = before <> remaining
      new_state = %{state | cursor_pos: current_pos - 1, value: new_value}
      emit_change_side_effect(state, new_value)
      {new_state, []}
    else
      {state, []}
    end
  end

  def handle_delete(state) do
    current_pos = state.cursor_pos
    current_value = state.value || ""

    if current_pos < String.length(current_value) do
      before = String.slice(current_value, 0, current_pos)
      after_text = String.slice(current_value, (current_pos + 1)..-1//1) || ""
      new_value = before <> after_text
      new_state = %{state | value: new_value}
      emit_change_side_effect(state, new_value)
      {new_state, []}
    else
      {state, []}
    end
  end

  defp emit_change_side_effect(state, new_value) do
    if is_function(state.on_change, 1) do
      state.on_change.(new_value)
    end
  end
end

defmodule Raxol.UI.Components.Input.TextInput.CharacterHandler do
  @moduledoc false

  def handle_character(state, char_key) do
    with char_str when not is_nil(char_str) <- process_char_key(char_key),
         true <- validate_length(state, char_str),
         true <- validate_char(state, char_str) do
      insert_char_at_cursor(state, char_str)
    else
      _ -> {state, []}
    end
  end

  defp process_char_key(char_key) do
    cond do
      is_binary(char_key) and String.length(char_key) == 1 and
          String.printable?(char_key) ->
        char_key

      is_integer(char_key) and char_key >= 32 and char_key <= 126 ->
        <<char_key::utf8>>

      true ->
        nil
    end
  end

  defp validate_length(state, _char_str) do
    current_value = state.value || ""
    max_length = state.max_length
    !max_length || String.length(current_value) < max_length
  end

  defp validate_char(state, char_str) do
    validator = state.validator
    !is_function(validator, 1) || validator.(char_str)
  end

  defp insert_char_at_cursor(state, char_str) do
    current_value = state.value || ""
    cursor_pos = state.cursor_pos
    before = String.slice(current_value, 0, cursor_pos)
    after_text = String.slice(current_value, cursor_pos..-1//1) || ""
    new_value = before <> char_str <> after_text
    new_cursor_pos = cursor_pos + 1

    new_state = %{
      state
      | cursor_pos: new_cursor_pos,
        value: new_value
    }

    emit_change_side_effect(state, new_value)
    {new_state, []}
  end

  defp emit_change_side_effect(state, new_value) do
    if is_function(state.on_change, 1) do
      state.on_change.(new_value)
    end
  end
end
