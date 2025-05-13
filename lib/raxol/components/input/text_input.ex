defmodule Raxol.Components.Input.TextInput do
  @moduledoc """
  A text input component for single-line text entry.

  Features:
  * Cursor management
  * Text selection
  * Copy/paste support
  * Password masking
  * Placeholder text
  """

  use Raxol.UI.Components.Base.Component
  alias Raxol.Components.Input.TextInput.Manipulation
  alias Raxol.Components.Input.TextInput.Selection
  alias Raxol.Components.Input.TextInput.Validation
  alias Raxol.Components.Input.TextInput.Renderer

  @type state :: %{
          value: String.t(),
          cursor: non_neg_integer(),
          selection: {non_neg_integer(), non_neg_integer()} | nil,
          focused: boolean(),
          placeholder: String.t() | nil,
          password: boolean(),
          max_length: non_neg_integer() | nil,
          pattern: String.t() | nil,
          error: String.t() | nil
        }

  @doc false
  @impl true
  def init(props) do
    %{
      value: props[:value] || "",
      cursor: 0,
      selection: nil,
      focused: false,
      placeholder: props[:placeholder],
      password: props[:password] || false,
      max_length: props[:max_length],
      pattern: props[:pattern],
      error: nil
    }
  end

  @impl true
  def update(msg, state) do
    new_state =
      case msg do
        {:input, char} when is_integer(char) ->
          # Clear selection when typing
          state = Selection.clear_selection(state)
          # Check max length before inserting
          if Validation.would_exceed_max_length?(state, char) do
            state
          else
            state = Manipulation.insert_char(state, char)
            Validation.validate_input(state)
          end

        {:backspace} ->
          case state.selection do
            {start, len} ->
              Manipulation.delete_selected_text(state, start, len)

            _ ->
              state = Manipulation.delete_char_backward(state)
              Validation.validate_input(state)
          end

        {:delete} ->
          case state.selection do
            {start, len} ->
              Manipulation.delete_selected_text(state, start, len)

            _ ->
              state = Manipulation.delete_char_forward(state)
              Validation.validate_input(state)
          end

        {:move_cursor, :left} ->
          Selection.move_cursor(state, -1)

        {:move_cursor, :right} ->
          Selection.move_cursor(state, 1)

        {:move_cursor, :home} ->
          Selection.move_to_home(state)

        {:move_cursor, :end} ->
          Selection.move_to_end(state)

        {:select, :left} ->
          Selection.select_text(state, -1)

        {:select, :right} ->
          Selection.select_text(state, 1)

        {:select, :home} ->
          Selection.select_to_home(state)

        {:select, :end} ->
          Selection.select_to_end(state)

        {:clear_selection} ->
          Selection.clear_selection(state)

        {:focus} ->
          %{state | focused: true}

        {:blur} ->
          %{state | focused: false, selection: nil}

        # Handle copy operation
        {:copy} ->
          case Selection.get_selected_text(state) do
            text when is_binary(text) ->
              Raxol.Clipboard.set_text(text)
              state

            _ ->
              state
          end

        # Handle paste operation
        {:paste} ->
          case Raxol.Clipboard.get_text() do
            {:ok, text} ->
              case state.selection do
                {start, len} ->
                  # Replace selected text
                  Manipulation.paste_at_position(state, text, start, len)

                _ ->
                  # Insert at cursor
                  Manipulation.paste_at_position(state, text, state.cursor, 0)
              end

            _ ->
              state
          end

        _ ->
          state
      end

    # Return {state, commands}
    {new_state, []}
  end

  @impl true
  def render(assigns, context) do
    Renderer.render(assigns, context)
  end

  @impl true
  def handle_event(%{type: :key, data: key_data} = _event, %{} = _props, state) do
    handle_key_event(key_data, state)
  end

  @impl true
  def handle_event(%{type: :focus}, %{} = _props, state) do
    {Map.put(state, :focused, true), []}
  end

  @impl true
  def handle_event(%{type: :blur}, %{} = _props, state) do
    {Map.put(state, :focused, false), []}
  end

  @impl true
  def handle_event(_event, %{} = _props, state), do: {state, []}

  # Private helpers

  defp handle_key_event(key_data, state) do
    msg =
      case key_data do
        %{key: char, modifiers: []}
        when is_binary(char) and byte_size(char) == 1 ->
          {:input, char}

        %{key: :backspace, modifiers: []} ->
          {:backspace}

        %{key: :left, modifiers: []} ->
          {:move_cursor, :left}

        %{key: :right, modifiers: []} ->
          {:move_cursor, :right}

        %{key: :home, modifiers: []} ->
          {:move_cursor, :home}

        %{key: :end, modifiers: []} ->
          {:move_cursor, :end}

        %{key: :delete, modifiers: []} ->
          {:delete}

        # Add selection with Shift+Arrow
        %{key: :left, modifiers: [:shift]} ->
          {:select, :left}

        %{key: :right, modifiers: [:shift]} ->
          {:select, :right}

        %{key: :home, modifiers: [:shift]} ->
          {:select, :home}

        %{key: :end, modifiers: [:shift]} ->
          {:select, :end}

        # Add copy (Ctrl+C) when text is selected
        %{key: :char, char: "c", ctrl: true} when state.selection != nil ->
          {:copy}

        # Add paste (Ctrl+V)
        %{key: :char, char: "v", ctrl: true} ->
          {:paste}

        _ ->
          # Ignore other keys
          nil
      end

    if msg do
      {update(msg, state), []}
    else
      {state, []}
    end
  end
end
