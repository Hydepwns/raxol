defmodule Raxol.UI.Components.Input.SingleLineInput do
  @moduledoc """
  A simple single-line text input component.
  """

  @typedoc """
  State for the SingleLineInput component.

  - :id - unique identifier
  - :value - current text value
  - :placeholder - placeholder text
  - :style - style map
  - :focused - whether the field is focused
  - :cursor_pos - cursor position
  - :on_change - callback for value change
  - :on_submit - callback for submit action
  """
  @type t :: %__MODULE__{
          id: any(),
          value: String.t(),
          placeholder: String.t(),
          style: map(),
          focused: boolean(),
          cursor_pos: non_neg_integer(),
          on_change: (String.t() -> any()) | nil,
          on_submit: (-> any()) | nil
        }

  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component
  require Raxol.Core.Runtime.Log

  # Require view macros
  require Raxol.View.Elements

  # Define state struct
  defstruct id: nil,
            value: "",
            placeholder: "",
            style: %{},
            focused: false,
            cursor_pos: 0,
            on_change: nil,
            on_submit: nil

  # --- Component Behaviour Callbacks ---

  @doc """
  Initializes the SingleLineInput component state from the given props.
  """
  @spec init(map()) :: __MODULE__.t()
  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Initialize state from props
    %__MODULE__{
      id: props[:id],
      value: props[:initial_value] || "",
      placeholder: props[:placeholder] || "",
      style: props[:style] || %{},
      on_change: props[:on_change],
      on_submit: props[:on_submit],
      cursor_pos: String.length(props[:initial_value] || "")
    }
  end

  @doc """
  Updates the SingleLineInput component state in response to messages or prop changes.
  """
  @spec update(term(), __MODULE__.t()) :: {__MODULE__.t(), list()}
  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle internal messages (e.g., from key events)
    Raxol.Core.Runtime.Log.debug(
      "SingleLineInput #{state.id} received message: #{inspect(msg)}"
    )

    case msg do
      {:insert_char, char} -> insert_char(char, state)
      :move_cursor_left -> move_cursor(-1, state)
      :move_cursor_right -> move_cursor(1, state)
      :backspace -> backspace(state)
      :delete -> delete(state)
      :move_cursor_start -> move_cursor_to(0, state)
      :move_cursor_end -> move_cursor_to(String.length(state.value), state)
      :submit -> submit(state)
      :focus -> {%{state | focused: true}, []}
      :blur -> {%{state | focused: false}, []}
      _ -> {state, []}
    end
  end

  @doc """
  Handles events for the SingleLineInput component, such as keypresses and mouse clicks.
  """
  @spec handle_event(term(), map(), __MODULE__.t()) :: {__MODULE__.t(), list()}
  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, %{} = _props, state) do
    # Handle keyboard events, mouse clicks (focus), etc.
    Raxol.Core.Runtime.Log.debug(
      "SingleLineInput #{state.id} received event: #{inspect(event)}"
    )

    case event do
      %{type: :key, data: key_data} ->
        handle_key_event(key_data, state)

      # Focus on click
      %{type: :mouse, data: %{button: :left, action: :press}} ->
        {state, [{:focus, state.id}]}

      _ ->
        {state, []}
    end
  end

  # --- Render Logic ---

  @doc """
  Renders the SingleLineInput component using the current state and props.
  """
  @spec render(__MODULE__.t(), map()) :: any()
  @impl Raxol.UI.Components.Base.Component
  # Correct arity
  def render(state, %{} = _props) do
    display_text =
      if state.value == "" and not state.focused,
        do: state.placeholder,
        else: state.value

    # Placeholder color handling
    text_color =
      if state.value == "" and not state.focused, do: :gray, else: :white

    # Render with cursor if focused
    rendered_content =
      if state.focused do
        before = String.slice(display_text, 0, state.cursor_pos)

        after_cursor =
          String.slice(
            display_text,
            state.cursor_pos,
            String.length(display_text)
          )

        # Use simple characters, assume fixed width font
        [
          Raxol.View.Elements.label(content: before),
          Raxol.View.Elements.label(content: "|"),
          Raxol.View.Elements.label(content: after_cursor)
        ]
      else
        Raxol.View.Elements.label(content: display_text)
      end

    dsl_result =
      Raxol.View.Elements.box id: state.id,
                              style: Map.put(state.style, :color, text_color) do
        rendered_content
      end

    # Return the element structure directly
    dsl_result
    # Or wrap if needed by container: View.to_element(dsl_result)
  end

  # --- Internal Helpers ---

  defp handle_key_event(key_data, state) do
    msg = map_key_to_message(key_data)
    if msg, do: update(msg, state), else: {state, []}
  end

  defp map_key_to_message(%{key: k, modifiers: []})
       when is_binary(k) and byte_size(k) == 1 do
    {:insert_char, k}
  end

  defp map_key_to_message(%{key: "Enter", modifiers: []}), do: :submit
  defp map_key_to_message(%{key: "Backspace", modifiers: []}), do: :backspace
  defp map_key_to_message(%{key: "Delete", modifiers: []}), do: :delete
  defp map_key_to_message(%{key: "Left", modifiers: []}), do: :move_cursor_left

  defp map_key_to_message(%{key: "Right", modifiers: []}),
    do: :move_cursor_right

  defp map_key_to_message(%{key: "Home", modifiers: []}), do: :move_cursor_start
  defp map_key_to_message(%{key: "End", modifiers: []}), do: :move_cursor_end
  defp map_key_to_message(_), do: nil

  defp insert_char(char, state) do
    new_value =
      String.slice(state.value, 0, state.cursor_pos) <>
        char <>
        String.slice(state.value, max(0, state.cursor_pos)..-1//1)

    new_cursor_pos = state.cursor_pos + 1
    new_state = %{state | value: new_value, cursor_pos: new_cursor_pos}
    commands = if state.on_change, do: [{state.on_change, new_value}], else: []
    {new_state, commands}
  end

  defp move_cursor(offset, state) do
    new_cursor_pos =
      clamp(state.cursor_pos + offset, 0, String.length(state.value))

    {%{state | cursor_pos: new_cursor_pos}, []}
  end

  defp move_cursor_to(pos, state) do
    new_cursor_pos = clamp(pos, 0, String.length(state.value))
    {%{state | cursor_pos: new_cursor_pos}, []}
  end

  defp backspace(state) do
    if state.cursor_pos > 0 do
      new_value =
        String.slice(state.value, 0, max(0, state.cursor_pos - 1)) <>
          String.slice(state.value, max(0, state.cursor_pos)..-1//1)

      new_cursor_pos = state.cursor_pos - 1
      new_state = %{state | value: new_value, cursor_pos: new_cursor_pos}

      commands =
        if state.on_change, do: [{state.on_change, new_value}], else: []

      {new_state, commands}
    else
      {state, []}
    end
  end

  defp delete(state) do
    if state.cursor_pos < String.length(state.value) do
      new_value =
        String.slice(state.value, 0, state.cursor_pos) <>
          String.slice(state.value, max(0, state.cursor_pos + 1)..-1//1)

      new_state = %{state | value: new_value}

      commands =
        if state.on_change, do: [{state.on_change, new_value}], else: []

      {new_state, commands}
    else
      {state, []}
    end
  end

  defp submit(state) do
    commands =
      if state.on_submit, do: [{state.on_submit, state.value}], else: []

    {state, commands}
  end

  defp clamp(value, min_val, max_val) do
    value |> max(min_val) |> min(max_val)
  end
end
