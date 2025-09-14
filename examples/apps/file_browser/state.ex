defmodule Examples.FileBrowser.State do
  @moduledoc """
  State management for the file browser explorer.

  Handles directory listing, file metadata, permissions, and bookmarks.
  """

  defstruct [
    :current_path,
    :entries,
    :selected_index,
    :preview_content,
    :show_hidden,
    :sort_by,
    :sort_order,
    :search_query,
    :bookmarks,
    :clipboard,
    :clipboard_operation,
    :mode,
    :status_message,
    :view_mode,
    :preview_mode
  ]

  def new(path \\ ".") do
    abs_path = Path.expand(path)

    %__MODULE__{
      current_path: abs_path,
      entries: list_directory(abs_path, false),
      selected_index: 0,
      preview_content: nil,
      show_hidden: false,
      sort_by: :name,
      sort_order: :asc,
      search_query: "",
      bookmarks: load_bookmarks(),
      clipboard: nil,
      clipboard_operation: nil,
      mode: :browse,
      status_message: "Ready",
      view_mode: :list,
      preview_mode: :auto
    }
  end

  def list_directory(path, show_hidden) do
    case File.ls(path) do
      {:ok, files} ->
        files
        |> Enum.filter(fn f ->
          show_hidden or not String.starts_with?(f, ".")
        end)
        |> Enum.map(fn name ->
          full_path = Path.join(path, name)
          stat = File.stat!(full_path)

          %{
            name: name,
            path: full_path,
            type: stat.type,
            size: stat.size,
            modified: stat.mtime,
            permissions: format_permissions(stat),
            extension: Path.extname(name) |> String.downcase()
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp format_permissions(stat) do
    mode = stat.mode

    owner = format_rwx(mode >>> 6 &&& 0o7)
    group = format_rwx(mode >>> 3 &&& 0o7)
    other = format_rwx(mode &&& 0o7)

    type_char =
      case stat.type do
        :directory -> "d"
        :symlink -> "l"
        _ -> "-"
      end

    type_char <> owner <> group <> other
  end

  defp format_rwx(bits) do
    r = if (bits &&& 0o4) != 0, do: "r", else: "-"
    w = if (bits &&& 0o2) != 0, do: "w", else: "-"
    x = if (bits &&& 0o1) != 0, do: "x", else: "-"
    r <> w <> x
  end

  defp load_bookmarks do
    [
      %{name: "Home", path: System.user_home()},
      %{name: "Root", path: "/"},
      %{name: "Downloads", path: Path.join(System.user_home(), "Downloads")},
      %{name: "Documents", path: Path.join(System.user_home(), "Documents")}
    ]
  end
end
