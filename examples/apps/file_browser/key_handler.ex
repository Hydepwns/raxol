defmodule Examples.FileBrowser.KeyHandler do
  @moduledoc """
  Key handling logic for the file browser explorer.

  Handles all keyboard input including navigation, file operations,
  and mode switching.
  """

  alias Examples.FileBrowser.{State, FileOperations}

  def handle_key(state, :up) do
    new_index = max(0, state.selected_index - 1)

    %{state | selected_index: new_index}
    |> FileOperations.load_preview()
  end

  def handle_key(state, :down) do
    max_index = length(state.entries) - 1
    new_index = min(max_index, state.selected_index + 1)

    %{state | selected_index: new_index}
    |> FileOperations.load_preview()
  end

  def handle_key(state, :enter) do
    case FileOperations.get_selected_entry(state) do
      %{type: :directory, path: path} ->
        FileOperations.enter_directory(state, path)

      %{path: path} ->
        FileOperations.open_file(state, path)

      _ ->
        state
    end
  end

  def handle_key(state, :backspace) do
    parent = Path.dirname(state.current_path)

    if parent != state.current_path do
      FileOperations.enter_directory(state, parent)
    else
      state
    end
  end

  def handle_key(state, {:char, ?h}) do
    %{state | show_hidden: not state.show_hidden}
    |> FileOperations.refresh_directory()
  end

  def handle_key(state, {:char, ?/}) do
    %{state | mode: :search, search_query: ""}
  end

  def handle_key(%{mode: :search} = state, {:char, char}) do
    query = state.search_query <> <<char>>

    %{state | search_query: query}
    |> FileOperations.filter_entries()
  end

  def handle_key(%{mode: :search} = state, :escape) do
    %{state | mode: :browse, search_query: ""}
    |> FileOperations.refresh_directory()
  end

  def handle_key(state, {:char, ?c}) when state.mode == :browse do
    case FileOperations.get_selected_entry(state) do
      %{path: path} = entry ->
        %{
          state
          | clipboard: entry,
            clipboard_operation: :copy,
            status_message: "Copied: #{entry.name}"
        }

      _ ->
        state
    end
  end

  def handle_key(state, {:char, ?x}) when state.mode == :browse do
    case FileOperations.get_selected_entry(state) do
      %{path: path} = entry ->
        %{
          state
          | clipboard: entry,
            clipboard_operation: :cut,
            status_message: "Cut: #{entry.name}"
        }

      _ ->
        state
    end
  end

  def handle_key(state, {:char, ?v})
      when state.mode == :browse and state.clipboard != nil do
    FileOperations.paste_file(state)
  end

  def handle_key(state, {:char, ?d}) when state.mode == :browse do
    case FileOperations.get_selected_entry(state) do
      %{name: name} ->
        %{
          state
          | mode: :confirm_delete,
            status_message: "Delete '#{name}'? (y/n)"
        }

      _ ->
        state
    end
  end

  def handle_key(%{mode: :confirm_delete} = state, {:char, ?y}) do
    FileOperations.delete_selected(state)
  end

  def handle_key(%{mode: :confirm_delete} = state, _) do
    %{state | mode: :browse, status_message: "Cancelled"}
  end

  def handle_key(state, {:char, ?r}) when state.mode == :browse do
    case FileOperations.get_selected_entry(state) do
      %{name: name} ->
        %{
          state
          | mode: :rename,
            search_query: name,
            status_message: "Rename to: "
        }

      _ ->
        state
    end
  end

  def handle_key(%{mode: :rename} = state, :enter) do
    FileOperations.rename_selected(state)
  end

  def handle_key(state, {:char, ?s}) do
    next_sort =
      case state.sort_by do
        :name -> :size
        :size -> :modified
        :modified -> :type
        :type -> :name
      end

    %{state | sort_by: next_sort}
    |> FileOperations.sort_entries()
  end

  def handle_key(state, {:char, ?p}) do
    next_mode =
      case state.preview_mode do
        :auto -> :text
        :text -> :hex
        :hex -> :none
        :none -> :auto
      end

    %{state | preview_mode: next_mode}
    |> FileOperations.load_preview()
  end

  def handle_key(state, {:char, ?b}) do
    bookmark = %{
      name: Path.basename(state.current_path),
      path: state.current_path
    }

    %{
      state
      | bookmarks: [bookmark | state.bookmarks],
        status_message: "Bookmarked: #{bookmark.name}"
    }
  end

  def handle_key(state, {:char, digit}) when digit >= ?1 and digit <= ?9 do
    index = digit - ?1

    case Enum.at(state.bookmarks, index) do
      %{path: path} ->
        FileOperations.enter_directory(state, path)

      _ ->
        state
    end
  end

  def handle_key(state, {:char, ?q}) do
    System.halt(0)
  end

  def handle_key(state, _), do: state
end
