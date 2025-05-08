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

  alias Raxol.UI.Components.Base.Component
  alias Raxol.Core.Events.Event
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
          mask_char: String.t() | nil
        }

  require Logger

  # Implementation of Component callbacks
  @impl true
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
      mask_char: props[:mask_char]
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_event(state, %Event{type: :key, data: key_data}, _context) do
    key = key_data.key
    modifiers = key_data.modifiers || []

    case {key, modifiers} do
      {:enter, _} ->
        if is_function(state.on_submit, 1) do
          state.on_submit.(state.value)
        end

        {state, []}

      {:escape, _} ->
        new_state = %{state | focused: false}
        {new_state, []}

      {:backspace, _} ->
        current_pos = state.cursor_pos
        current_value = state.value || ""

        if current_pos > 0 do
          before_part = String.slice(current_value, 0..(current_pos - 2))
          remaining_part = String.slice(current_value, current_pos..-1)
          before = before_part || ""
          remaining = remaining_part || ""
          new_value = before <> remaining
          new_state = %{state | cursor_pos: current_pos - 1, value: new_value}
          emit_change_side_effect(state, new_value)
          {new_state, []}
        else
          {state, []}
        end

      {:delete, _} ->
        current_pos = state.cursor_pos
        current_value = state.value || ""

        if current_pos < String.length(current_value) do
          before = String.slice(current_value, 0, current_pos)

          after_text =
            String.slice(current_value, (current_pos + 1)..-1//1) || ""

          new_value = before <> after_text
          new_state = %{state | value: new_value}
          emit_change_side_effect(state, new_value)
          {new_state, []}
        else
          {state, []}
        end

      {:left, _} ->
        if state.cursor_pos > 0 do
          new_cursor_pos = state.cursor_pos - 1
          new_state = %{state | cursor_pos: new_cursor_pos}
          {new_state, []}
        else
          {state, []}
        end

      {:right, _} ->
        current_value = state.value || ""

        if state.cursor_pos < String.length(current_value) do
          new_cursor_pos = state.cursor_pos + 1
          new_state = %{state | cursor_pos: new_cursor_pos}
          {new_state, []}
        else
          {state, []}
        end

      {:home, _} ->
        new_state = %{state | cursor_pos: 0}
        {new_state, []}

      {:end, _} ->
        current_value = state.value || ""
        new_state = %{state | cursor_pos: String.length(current_value)}
        {new_state, []}

      {char_key, []} ->
        char_str =
          cond do
            is_binary(char_key) and String.length(char_key) == 1 and
                String.printable?(char_key) ->
              char_key

            is_integer(char_key) and char_key >= 32 and char_key <= 126 ->
              <<char_key::utf8>>

            true ->
              nil
          end

        if char_str do
          max_length = state.max_length
          current_value = state.value || ""

          if max_length && String.length(current_value) >= max_length do
            {state, []}
          else
            validator = state.validator

            should_reject =
              is_function(validator, 1) &&
                !validator.(char_str)

            if should_reject do
              {state, []}
            else
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
          end
        else
          {state, []}
        end

      _ ->
        {state, []}
    end
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

  @impl true
  def update(message, state) do
    Logger.debug("[TextInput] Received unhandled message: #{inspect(message)}")
    state
  end

  @impl true
  def render(state, _context) do
    value = state.value
    placeholder = state.placeholder

    masked_text =
      if state.mask_char do
        String.duplicate(state.mask_char, String.length(value))
      else
        value
      end

    %{
      type: :text_input,
      text: if(value == "", do: placeholder, else: masked_text),
      cursor_pos: state.cursor_pos,
      focused: state.focused
    }
  end

  defp emit_change(state, new_value) do
    if is_function(state.on_change, 1) do
      state.on_change.(new_value)
    end

    :ok
  end

  defp emit_change_side_effect(state, new_value) do
    if is_function(state.on_change, 1) do
      state.on_change.(new_value)
    end

    :ok
  end
end
