defmodule Raxol.Demo.Todo do
  @moduledoc """
  Todo list demo for `mix raxol.demo todo`.

  Demonstrates keyboard-driven TEA patterns with input modes,
  list navigation, and CRUD operations.

  Controls:
    Normal: j/k or arrows to navigate, Enter/Space to toggle, d to delete, a to add
    Input:  type text, Enter to submit, Backspace to delete, Escape to cancel
    q/Ctrl+C to quit
  """

  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context) do
    %{
      todos: [
        %{id: 1, text: "Learn Raxol", done: false},
        %{id: 2, text: "Build a TUI app", done: false},
        %{id: 3, text: "Ship it", done: true}
      ],
      next_id: 4,
      cursor: 0,
      mode: :normal,
      input_buffer: ""
    }
  end

  @impl true
  def update(message, model) do
    case message do
      # Quit
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}}
      when model.mode == :normal ->
        {model, [command(:quit)]}

      %Raxol.Core.Events.Event{
        type: :key,
        data: %{key: :char, char: "c", ctrl: true}
      } ->
        {model, [command(:quit)]}

      # Normal: navigation
      %Raxol.Core.Events.Event{type: :key, data: %{key: key}}
      when key in [:down] and model.mode == :normal ->
        {move_cursor(model, 1), []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "j"}}
      when model.mode == :normal ->
        {move_cursor(model, 1), []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: key}}
      when key in [:up] and model.mode == :normal ->
        {move_cursor(model, -1), []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "k"}}
      when model.mode == :normal ->
        {move_cursor(model, -1), []}

      # Normal: toggle done
      %Raxol.Core.Events.Event{type: :key, data: %{key: key}}
      when key in [:enter, :space] and model.mode == :normal ->
        {toggle_done(model), []}

      # Normal: delete
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "d"}}
      when model.mode == :normal ->
        {delete_todo(model), []}

      # Normal: start input
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "a"}}
      when model.mode == :normal ->
        {%{model | mode: :input, input_buffer: ""}, []}

      # Input: submit
      %Raxol.Core.Events.Event{type: :key, data: %{key: :enter}}
      when model.mode == :input ->
        {submit_todo(model), []}

      # Input: cancel
      %Raxol.Core.Events.Event{type: :key, data: %{key: key}}
      when key in [:esc, :escape] and model.mode == :input ->
        {%{model | mode: :normal, input_buffer: ""}, []}

      # Input: backspace
      %Raxol.Core.Events.Event{type: :key, data: %{key: :backspace}}
      when model.mode == :input ->
        buf = String.slice(model.input_buffer, 0..-2//1)
        {%{model | input_buffer: buf}, []}

      # Input: printable character
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: ch}}
      when model.mode == :input and is_binary(ch) ->
        {%{model | input_buffer: model.input_buffer <> ch}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    done_count = Enum.count(model.todos, & &1.done)
    total = length(model.todos)

    column style: %{padding: 1, gap: 1} do
      [
        text("Todo List", style: [:bold]),
        todo_list_box(model),
        text("#{total} items, #{done_count} done"),
        help_text(model)
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []

  # -- View helpers --

  defp todo_list_box(model) do
    if model.todos == [] do
      box style: %{padding: 1, border: :single, width: 40} do
        text("(no todos -- press 'a' to add one)")
      end
    else
      items =
        model.todos
        |> Enum.with_index()
        |> Enum.map(fn {todo, idx} ->
          prefix = if idx == model.cursor, do: "> ", else: "  "
          check = if todo.done, do: "[x]", else: "[ ]"
          style = if idx == model.cursor, do: [:bold], else: []
          text("#{prefix}#{check} #{todo.text}", style: style)
        end)

      box style: %{padding: 1, border: :single, width: 40} do
        column style: %{gap: 0} do
          items
        end
      end
    end
  end

  defp help_text(%{mode: :input} = model) do
    text("New todo: #{model.input_buffer}_  [enter]submit [esc]cancel")
  end

  defp help_text(_model) do
    text("[a]dd  [d]elete  [enter]toggle  [j/k]move  [q]uit")
  end

  # -- Model helpers --

  defp move_cursor(model, delta) do
    len = length(model.todos)

    if len == 0 do
      model
    else
      new_cursor = max(0, min(model.cursor + delta, len - 1))
      %{model | cursor: new_cursor}
    end
  end

  defp toggle_done(%{todos: []} = model), do: model

  defp toggle_done(model) do
    todos =
      List.update_at(model.todos, model.cursor, fn todo ->
        %{todo | done: not todo.done}
      end)

    %{model | todos: todos}
  end

  defp delete_todo(%{todos: []} = model), do: model

  defp delete_todo(model) do
    todos = List.delete_at(model.todos, model.cursor)
    new_cursor = min(model.cursor, max(length(todos) - 1, 0))
    %{model | todos: todos, cursor: new_cursor}
  end

  defp submit_todo(model) do
    trimmed = String.trim(model.input_buffer)

    if trimmed == "" do
      %{model | mode: :normal, input_buffer: ""}
    else
      new_todo = %{id: model.next_id, text: trimmed, done: false}

      %{
        model
        | todos: model.todos ++ [new_todo],
          next_id: model.next_id + 1,
          cursor: length(model.todos),
          mode: :normal,
          input_buffer: ""
      }
    end
  end
end
