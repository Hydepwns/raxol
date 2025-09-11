defmodule Raxol.Examples.TodoApp do
  @moduledoc """
  A fully-featured todo list application demonstrating Raxol's capabilities.

  Features:
  - Add, edit, and delete todos
  - Mark todos as complete
  - Filter by status (all, active, completed)
  - Persist todos to disk
  - Keyboard shortcuts
  - Search functionality
  """

  use Raxol.Application

  @storage_file Path.expand("~/.raxol_todos.json")

  @impl true
  def mount(_params, socket) do
    todos = load_todos()

    {:ok,
     socket
     |> assign(todos: todos)
     |> assign(filter: :all)
     |> assign(input: "")
     |> assign(search: "")
     |> assign(editing_id: nil)
     |> assign(edit_text: "")
     |> register_shortcuts([
       {"ctrl+n", "new_todo"},
       {"ctrl+d", "clear_completed"},
       {"ctrl+s", "save_todos"},
       {"ctrl+f", "focus_search"},
       {"/", "focus_search"},
       {"escape", "cancel_edit"}
     ])}
  end

  @impl true
  def render(assigns) do
    filtered_todos = filter_todos(assigns.todos, assigns.filter, assigns.search)
    stats = calculate_stats(assigns.todos)

    ~H"""
    <Screen title="Todo List">
      <Box padding={2}>
        <!-- Header -->
        <Stack direction="horizontal" justify="between" marginBottom={2}>
          <Heading level={1}>📝 Todo List</Heading>
          <Text color="gray">
            <%= stats.active %> active, <%= stats.completed %> completed
          </Text>
        </Stack>
        
        <!-- Search Bar -->
        <Box marginBottom={2}>
          <TextInput
            value={@search}
            onChange="update_search"
            placeholder="Search todos... (Ctrl+F or /)"
            leftIcon="🔍"
          />
        </Box>
        
        <!-- New Todo Input -->
        <Box marginBottom={2}>
          <TextInput
            value={@input}
            onChange="update_input"
            onSubmit="add_todo"
            placeholder="What needs to be done? (Ctrl+N)"
            autoFocus
          />
        </Box>
        
        <!-- Filter Tabs -->
        <Tabs
          value={@filter}
          onChange="change_filter"
          marginBottom={2}
          tabs={[
            %{id: :all, label: "All (#{length(filtered_todos)})"},
            %{id: :active, label: "Active (#{stats.active})"},
            %{id: :completed, label: "Completed (#{stats.completed})"}
          ]}
        />
        
        <!-- Todo List -->
        <Box border="single" borderColor="gray.600" minHeight={20}>
          <%= if length(filtered_todos) == 0 do %>
            <Box padding={2}>
              <Text color="gray" align="center">
                <%= empty_message(@filter, @search) %>
              </Text>
            </Box>
          <% else %>
            <List>
              <%= for todo <- filtered_todos do %>
                <TodoItem
                  todo={todo}
                  editing={@editing_id == todo.id}
                  editText={@edit_text}
                  onToggle="toggle_todo"
                  onEdit="start_edit"
                  onUpdateEdit="update_edit"
                  onSaveEdit="save_edit"
                  onCancelEdit="cancel_edit"
                  onDelete="delete_todo"
                />
              <% end %>
            </List>
          <% end %>
        </Box>
        
        <!-- Footer Actions -->
        <Stack direction="horizontal" justify="between" marginTop={2}>
          <ButtonGroup size="small">
            <Button onClick="mark_all_complete">
              ✓ Mark All Complete
            </Button>
            <Button onClick="clear_completed" variant="danger">
              Clear Completed
            </Button>
          </ButtonGroup>
          
          <Text color="gray" size="small">
            Ctrl+S to save | Ctrl+D to clear completed
          </Text>
        </Stack>
      </Box>
    </Screen>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("update_input", %{"value" => value}, socket) do
    {:noreply, assign(socket, input: value)}
  end

  @impl true
  def handle_event("add_todo", _, socket) do
    text = String.trim(socket.assigns.input)

    if text != "" do
      todo = %{
        id: generate_id(),
        text: text,
        completed: false,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      socket =
        socket
        |> update(:todos, &[todo | &1])
        |> assign(input: "")
        |> save_todos_to_disk()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_todo", %{"id" => id}, socket) do
    todos =
      Enum.map(socket.assigns.todos, fn todo ->
        if todo.id == id do
          %{todo | completed: !todo.completed, updated_at: DateTime.utc_now()}
        else
          todo
        end
      end)

    socket =
      socket
      |> assign(todos: todos)
      |> save_todos_to_disk()

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_edit", %{"id" => id}, socket) do
    todo = Enum.find(socket.assigns.todos, &(&1.id == id))

    socket =
      socket
      |> assign(editing_id: id)
      |> assign(edit_text: todo.text)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_edit", %{"value" => value}, socket) do
    {:noreply, assign(socket, edit_text: value)}
  end

  @impl true
  def handle_event("save_edit", _, socket) do
    text = String.trim(socket.assigns.edit_text)

    if text != "" do
      todos =
        Enum.map(socket.assigns.todos, fn todo ->
          if todo.id == socket.assigns.editing_id do
            %{todo | text: text, updated_at: DateTime.utc_now()}
          else
            todo
          end
        end)

      socket =
        socket
        |> assign(todos: todos)
        |> assign(editing_id: nil)
        |> assign(edit_text: "")
        |> save_todos_to_disk()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    socket =
      socket
      |> assign(editing_id: nil)
      |> assign(edit_text: "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_todo", %{"id" => id}, socket) do
    todos = Enum.reject(socket.assigns.todos, &(&1.id == id))

    socket =
      socket
      |> assign(todos: todos)
      |> save_todos_to_disk()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_filter", %{"value" => filter}, socket) do
    {:noreply, assign(socket, filter: String.to_atom(filter))}
  end

  @impl true
  def handle_event("update_search", %{"value" => value}, socket) do
    {:noreply, assign(socket, search: value)}
  end

  @impl true
  def handle_event("mark_all_complete", _, socket) do
    todos =
      Enum.map(socket.assigns.todos, fn todo ->
        %{todo | completed: true, updated_at: DateTime.utc_now()}
      end)

    socket =
      socket
      |> assign(todos: todos)
      |> save_todos_to_disk()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_completed", _, socket) do
    todos = Enum.reject(socket.assigns.todos, & &1.completed)

    socket =
      socket
      |> assign(todos: todos)
      |> save_todos_to_disk()

    {:noreply, socket}
  end

  @impl true
  def handle_event("new_todo", _, socket) do
    # Focus the input field (implementation depends on focus management)
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_todos", _, socket) do
    socket = save_todos_to_disk(socket)
    Raxol.Toast.show("Todos saved!", type: :success)
    {:noreply, socket}
  end

  @impl true
  def handle_event("focus_search", _, socket) do
    # Focus the search field (implementation depends on focus management)
    {:noreply, socket}
  end

  # Helper Functions

  defp filter_todos(todos, filter, search) do
    todos
    |> filter_by_status(filter)
    |> filter_by_search(search)
    |> Enum.sort_by(& &1.created_at, {:desc, DateTime})
  end

  defp filter_by_status(todos, :all), do: todos
  defp filter_by_status(todos, :active), do: Enum.reject(todos, & &1.completed)

  defp filter_by_status(todos, :completed),
    do: Enum.filter(todos, & &1.completed)

  defp filter_by_search(todos, ""), do: todos

  defp filter_by_search(todos, search) do
    search_term = String.downcase(search)

    Enum.filter(todos, fn todo ->
      String.contains?(String.downcase(todo.text), search_term)
    end)
  end

  defp calculate_stats(todos) do
    completed = Enum.count(todos, & &1.completed)

    %{
      total: length(todos),
      active: length(todos) - completed,
      completed: completed
    }
  end

  defp empty_message(:all, ""), do: "No todos yet. Add one above!"
  defp empty_message(:all, _search), do: "No todos match your search."
  defp empty_message(:active, _), do: "No active todos. Nice work!"
  defp empty_message(:completed, _), do: "No completed todos yet."

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16()
  end

  defp save_todos_to_disk(socket) do
    todos_json = Jason.encode!(socket.assigns.todos, pretty: true)
    File.write!(@storage_file, todos_json)
    socket
  end

  defp load_todos do
    if File.exists?(@storage_file) do
      @storage_file
      |> File.read!()
      |> Jason.decode!()
      |> Enum.map(fn todo ->
        %{
          "id" => id,
          "text" => text,
          "completed" => completed,
          "created_at" => created_at,
          "updated_at" => updated_at
        } = todo

        %{
          id: id,
          text: text,
          completed: completed,
          created_at: parse_datetime(created_at),
          updated_at: parse_datetime(updated_at)
        }
      end)
    else
      []
    end
  rescue
    _ -> []
  end

  defp parse_datetime(nil), do: DateTime.utc_now()

  defp parse_datetime(string) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, datetime, _} -> datetime
      _ -> DateTime.utc_now()
    end
  end
end

# TodoItem Component
defmodule Raxol.Examples.TodoApp.TodoItem do
  use Raxol.Component

  prop(:todo, :map, required: true)
  prop(:editing, :boolean, default: false)
  prop(:editText, :string, default: "")
  prop(:onToggle, :string)
  prop(:onEdit, :string)
  prop(:onUpdateEdit, :string)
  prop(:onSaveEdit, :string)
  prop(:onCancelEdit, :string)
  prop(:onDelete, :string)

  @impl true
  def render(assigns) do
    ~H"""
    <ListItem>
      <Stack direction="horizontal" align="center" spacing={2}>
        <!-- Checkbox -->
        <Checkbox
          checked={@todo.completed}
          onChange={@onToggle}
          params={%{id: @todo.id}}
        />
        
        <!-- Todo Text or Edit Input -->
        <%= if @editing do %>
          <Box flex={1}>
            <TextInput
              value={@editText}
              onChange={@onUpdateEdit}
              onSubmit={@onSaveEdit}
              onEscape={@onCancelEdit}
              autoFocus
            />
          </Box>
        <% else %>
          <Box flex={1}>
            <Text
              strikethrough={@todo.completed}
              color={if @todo.completed, do: "gray", else: "white"}
              onDoubleClick={@onEdit}
              params={%{id: @todo.id}}
            >
              <%= @todo.text %>
            </Text>
          </Box>
        <% end %>
        
        <!-- Actions -->
        <%= unless @editing do %>
          <ButtonGroup size="small">
            <Button
              variant="ghost"
              onClick={@onEdit}
              params={%{id: @todo.id}}
              title="Edit (double-click)"
            >
              ✏️
            </Button>
            <Button
              variant="ghost"
              onClick={@onDelete}
              params={%{id: @todo.id}}
              title="Delete"
              color="red"
            >
              🗑️
            </Button>
          </ButtonGroup>
        <% end %>
      </Stack>
    </ListItem>
    """
  end
end
