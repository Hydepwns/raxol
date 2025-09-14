defmodule Examples.FileBrowser.FileOperations do
  @moduledoc """
  File operations for the file browser explorer.

  Handles directory navigation, file manipulation, preview generation,
  and file system operations like copy, move, delete, rename.
  """

  alias Examples.FileBrowser.State

  def enter_directory(state, path) do
    %{
      state
      | current_path: path,
        selected_index: 0,
        preview_content: nil
    }
    |> refresh_directory()
  end

  def refresh_directory(state) do
    entries = State.list_directory(state.current_path, state.show_hidden)

    %{state | entries: entries}
    |> sort_entries()
    |> load_preview()
  end

  def sort_entries(state) do
    sorted =
      Enum.sort_by(state.entries, fn entry ->
        case state.sort_by do
          :name -> String.downcase(entry.name)
          :size -> entry.size
          :modified -> entry.modified
          :type -> {entry.type, String.downcase(entry.name)}
        end
      end)

    sorted =
      if state.sort_order == :desc, do: Enum.reverse(sorted), else: sorted

    %{state | entries: sorted}
  end

  def filter_entries(state) do
    if state.search_query == "" do
      refresh_directory(state)
    else
      filtered =
        Enum.filter(state.entries, fn entry ->
          String.contains?(
            String.downcase(entry.name),
            String.downcase(state.search_query)
          )
        end)

      %{state | entries: filtered, selected_index: 0}
    end
  end

  def get_selected_entry(state) do
    Enum.at(state.entries, state.selected_index)
  end

  def load_preview(state) do
    case get_selected_entry(state) do
      %{type: :regular, path: path} = entry ->
        preview = generate_preview(path, entry.extension, state.preview_mode)
        %{state | preview_content: preview}

      %{type: :directory, path: path} ->
        files =
          State.list_directory(path, false)
          |> Enum.take(20)
          |> Enum.map(& &1.name)

        %{state | preview_content: {:directory, files}}

      _ ->
        %{state | preview_content: nil}
    end
  end

  defp generate_preview(path, extension, mode) do
    cond do
      mode == :none ->
        nil

      extension in [".jpg", ".png", ".gif", ".bmp"] ->
        {:image, generate_ascii_art(path)}

      extension in [".ex", ".exs", ".js", ".py", ".rb", ".rs", ".go"] ->
        {:code, read_file_preview(path, 50)}

      extension in [".md", ".txt", ".log", ".csv"] or mode == :text ->
        {:text, read_file_preview(path, 50)}

      mode == :hex ->
        {:hex, read_hex_preview(path, 256)}

      true ->
        {:binary, "Binary file"}
    end
  end

  defp read_file_preview(path, lines) do
    case File.read(path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.take(lines)
        |> Enum.join("\n")

      {:error, _} ->
        "Unable to read file"
    end
  end

  defp read_hex_preview(path, bytes) do
    case File.read(path) do
      {:ok, content} ->
        content
        |> :binary.bin_to_list()
        |> Enum.take(bytes)
        |> Enum.chunk_every(16)
        |> Enum.with_index()
        |> Enum.map(fn {chunk, offset} ->
          hex =
            chunk
            |> Enum.map(fn byte ->
              Integer.to_string(byte, 16) |> String.pad_leading(2, "0")
            end)
            |> Enum.join(" ")

          ascii =
            chunk
            |> Enum.map(fn byte ->
              if byte >= 32 and byte <= 126, do: <<byte>>, else: "."
            end)
            |> Enum.join()

          offset_str =
            Integer.to_string(offset * 16, 16) |> String.pad_leading(8, "0")

          "#{offset_str}  #{String.pad_trailing(hex, 48)}  |#{ascii}|"
        end)
        |> Enum.join("\n")

      {:error, _} ->
        "Unable to read file"
    end
  end

  defp generate_ascii_art(_path) do
    """
    ┌────────────────┐
    │                │
    │    [IMAGE]     │
    │                │
    └────────────────┘
    """
  end

  def open_file(state, path) do
    case :os.type() do
      {:unix, :darwin} -> System.cmd("open", [path])
      {:unix, _} -> System.cmd("xdg-open", [path])
      {:win32, _} -> System.cmd("cmd", ["/c", "start", path])
    end

    %{state | status_message: "Opened: #{Path.basename(path)}"}
  end

  def paste_file(%{clipboard: nil} = state), do: state

  def paste_file(state) do
    source = state.clipboard.path
    dest_name = Path.basename(source)
    dest = Path.join(state.current_path, dest_name)

    result =
      case state.clipboard_operation do
        :copy ->
          File.cp_r(source, dest)

        :cut ->
          File.rename(source, dest)
      end

    case result do
      :ok ->
        %{
          state
          | clipboard: nil,
            clipboard_operation: nil,
            status_message: "Pasted: #{dest_name}"
        }
        |> refresh_directory()

      {:error, reason} ->
        %{state | status_message: "Paste failed: #{inspect(reason)}"}
    end
  end

  def delete_selected(state) do
    case get_selected_entry(state) do
      %{path: path, type: :directory} ->
        case File.rm_rf(path) do
          {:ok, _} ->
            %{
              state
              | mode: :browse,
                status_message: "Deleted directory",
                selected_index: 0
            }
            |> refresh_directory()

          {:error, reason} ->
            %{
              state
              | mode: :browse,
                status_message: "Delete failed: #{inspect(reason)}"
            }
        end

      %{path: path} ->
        case File.rm(path) do
          :ok ->
            %{
              state
              | mode: :browse,
                status_message: "Deleted file",
                selected_index: 0
            }
            |> refresh_directory()

          {:error, reason} ->
            %{
              state
              | mode: :browse,
                status_message: "Delete failed: #{inspect(reason)}"
            }
        end

      _ ->
        %{state | mode: :browse}
    end
  end

  def rename_selected(state) do
    case get_selected_entry(state) do
      %{path: old_path} ->
        new_name = state.search_query
        new_path = Path.join(Path.dirname(old_path), new_name)

        case File.rename(old_path, new_path) do
          :ok ->
            %{
              state
              | mode: :browse,
                search_query: "",
                status_message: "Renamed to: #{new_name}"
            }
            |> refresh_directory()

          {:error, reason} ->
            %{
              state
              | mode: :browse,
                status_message: "Rename failed: #{inspect(reason)}"
            }
        end

      _ ->
        %{state | mode: :browse}
    end
  end
end
