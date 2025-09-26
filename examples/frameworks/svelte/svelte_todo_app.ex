defmodule Examples.SvelteTodoApp do
  @moduledoc """
  A todo application demonstrating advanced Svelte-style patterns.

  Features:
  - Reactive stores
  - Two-way data binding
  - Derived state
  - Array operations
  - Conditional rendering

  Usage:
    terminal = Raxol.Terminal.new()
    app = Examples.SvelteTodoApp.mount(terminal)
  """

  use Raxol.Svelte.Component, optimize: :compile_time
  use Raxol.Svelte.Reactive

  # State
  state(:todos, [])
  state(:new_todo_text, "")
  # :all, :active, :completed
  state(:filter, :all)
  state(:editing_id, nil)

  # Reactive derived state
  reactive :total_count do
    length(@todos)
  end

  reactive :active_count do
    @todos |> Enum.count(fn todo -> !todo.completed end)
  end

  reactive :completed_count do
    @todos |> Enum.count(fn todo -> todo.completed end)
  end

  reactive :filtered_todos do
    case @filter do
      :all -> @todos
      :active -> Enum.filter(@todos, fn todo -> !todo.completed end)
      :completed -> Enum.filter(@todos, fn todo -> todo.completed end)
    end
  end

  reactive :all_completed do
    @total_count > 0 && @active_count == 0
  end

  # Reactive statements
  reactive_block do
    # Auto-save to localStorage-equivalent when todos change
    reactive_stmt(
      case @total_count > 0 do
        true -> save_todos(@todos)
        false -> nil
      end
    )

    # Status updates
    reactive_stmt(
      status =
        cond do
          @total_count == 0 -> "No todos yet"
          @active_count == 0 -> "All done! [DONE]"
          @active_count == 1 -> "1 item left"
          true -> "#{@active_count} items left"
        end
    )
  end

  # Event handlers
  def add_todo do
    text = String.trim(get_state(:new_todo_text))

    case text do
      "" ->
        nil

      _ ->
        new_todo = %{
          id: :crypto.strong_rand_bytes(8) |> Base.encode64(),
          text: text,
          completed: false,
          created_at: DateTime.utc_now()
        }

        update_state(:todos, fn todos -> [new_todo | todos] end)
        set_state(:new_todo_text, "")
    end
  end

  def toggle_todo(id) do
    update_state(:todos, fn todos ->
      Enum.map(todos, fn todo ->
        case todo.id == id do
          true -> %{todo | completed: !todo.completed}
          false -> todo
        end
      end)
    end)
  end

  def remove_todo(id) do
    update_state(:todos, fn todos ->
      Enum.reject(todos, fn todo -> todo.id == id end)
    end)
  end

  def edit_todo(id) do
    set_state(:editing_id, id)
  end

  def save_todo(id, new_text) do
    text = String.trim(new_text)

    case text do
      "" ->
        remove_todo(id)

      _ ->
        update_state(:todos, fn todos ->
          Enum.map(todos, fn todo ->
            case todo.id == id do
              true -> %{todo | text: text}
              false -> todo
            end
          end)
        end)
    end

    set_state(:editing_id, nil)
  end

  def cancel_edit do
    set_state(:editing_id, nil)
  end

  def set_filter(new_filter) do
    set_state(:filter, new_filter)
  end

  def toggle_all do
    all_completed = get_state(:all_completed)

    update_state(:todos, fn todos ->
      Enum.map(todos, fn todo ->
        %{todo | completed: !all_completed}
      end)
    end)
  end

  def clear_completed do
    update_state(:todos, fn todos ->
      Enum.reject(todos, fn todo -> todo.completed end)
    end)
  end

  # Template helpers
  defp filter_button_style(current_filter, button_filter) do
    case current_filter == button_filter do
      true -> "selected"
      false -> "normal"
    end
  end

  # Persistence
  defp save_todos(todos) do
    # In a real app, this would save to persistent storage
    IO.puts("Saving #{length(todos)} todos...")
  end

  # Render function
  def render(assigns) do
    ~H"""
    <Box padding={2} border="single" title="Svelte Todo App">
      <!-- Header -->
      <Row>
        <Text size="large" bold>Todo App</Text>
        <Text color="gray">{status}</Text>
      </Row>
      
      <!-- New todo input -->
      <Row spacing={1}>
        <TextInput 
          value={@new_todo_text}
          placeholder="What needs to be done?"
          on_change={fn text -> set_state(:new_todo_text, text) end}
          on_enter={&add_todo/0}
          flex={1}
        />
        <Button on_click={&add_todo/0} disabled={String.trim(@new_todo_text) == ""}>
          Add
        </Button>
      </Row>
      
      <!-- Toggle all and stats -->
      {#if @total_count > 0}
        <Row spacing={2}>
          <Button 
            on_click={&toggle_all/0}
            variant={if @all_completed, do: "primary", else: "secondary"}
          >
            {if @all_completed, do: "☑", else: "☐"} Toggle All
          </Button>
          
          <Text>Total: {@total_count}</Text>
          <Text>Active: {@active_count}</Text>
          <Text>Done: {@completed_count}</Text>
        </Row>
      {/if}
      
      <!-- Filter buttons -->
      {#if @total_count > 0}
        <Row spacing={1}>
          <Text>Show:</Text>
          <Button 
            on_click={fn -> set_filter(:all) end}
            variant={filter_button_style(@filter, :all)}
          >
            All
          </Button>
          <Button 
            on_click={fn -> set_filter(:active) end}
            variant={filter_button_style(@filter, :active)}
          >
            Active
          </Button>
          <Button 
            on_click={fn -> set_filter(:completed) end}
            variant={filter_button_style(@filter, :completed)}
          >
            Completed
          </Button>
          
          {#if @completed_count > 0}
            <Button on_click={&clear_completed/0} color="red">
              Clear Completed
            </Button>
          {/if}
        </Row>
      {/if}
      
      <!-- Todo list -->
      <List>
        {#each @filtered_todos as todo}
          <ListItem key={todo.id}>
            {#if @editing_id == todo.id}
              <!-- Editing mode -->
              <EditableTodoItem 
                todo={todo}
                on_save={fn text -> save_todo(todo.id, text) end}
                on_cancel={&cancel_edit/0}
              />
            {:else}
              <!-- Display mode -->
              <TodoItem 
                todo={todo}
                on_toggle={fn -> toggle_todo(todo.id) end}
                on_remove={fn -> remove_todo(todo.id) end}
                on_edit={fn -> edit_todo(todo.id) end}
              />
            {/if}
          </ListItem>
        {/each}
        
        {#if length(@filtered_todos) == 0 && @total_count > 0}
          <ListItem>
            <Text color="gray" italic>No {Atom.to_string(@filter)} todos</Text>
          </ListItem>
        {/if}
        
        {#if @total_count == 0}
          <ListItem>
            <Text color="gray" italic>Add your first todo above</Text>
          </ListItem>
        {/if}
      </List>
    </Box>
    """
  end
end

# Helper components
defmodule Examples.SvelteTodoApp.TodoItem do
  use Raxol.Svelte.Component

  def render(%{
        todo: todo,
        on_toggle: on_toggle,
        on_remove: on_remove,
        on_edit: on_edit
      }) do
    ~H"""
    <Row spacing={1} align="center">
      <Button on_click={on_toggle} variant="checkbox">
        {if todo.completed, do: "☑", else: "☐"}
      </Button>
      
      <Text 
        flex={1}
        strikethrough={todo.completed}
        color={if todo.completed, do: "gray", else: "normal"}
        on_double_click={on_edit}
      >
        {todo.text}
      </Text>
      
      <Button on_click={on_edit} variant="ghost" size="small">Edit</Button>
      <Button on_click={on_remove} variant="ghost" size="small" color="red">×</Button>
    </Row>
    """
  end
end

defmodule Examples.SvelteTodoApp.EditableTodoItem do
  use Raxol.Svelte.Component
  use Raxol.Svelte.Reactive

  state(:edit_text, "")

  def init_with_todo(todo) do
    set_state(:edit_text, todo.text)
  end

  def save(on_save) do
    on_save.(get_state(:edit_text))
  end

  def cancel(on_cancel) do
    on_cancel.()
  end

  def render(%{todo: todo, on_save: on_save, on_cancel: on_cancel}) do
    ~H"""
    <Row spacing={1} align="center">
      <Button variant="checkbox" disabled>
        {if todo.completed, do: "☑", else: "☐"}
      </Button>
      
      <TextInput 
        value={@edit_text}
        on_change={fn text -> set_state(:edit_text, text) end}
        on_enter={fn -> save(on_save) end}
        on_escape={fn -> cancel(on_cancel) end}
        focus
        flex={1}
      />
      
      <Button on_click={fn -> save(on_save) end} variant="primary" size="small">Save</Button>
      <Button on_click={fn -> cancel(on_cancel) end} variant="secondary" size="small">Cancel</Button>
    </Row>
    """
  end
end
