defmodule Examples.FileBrowser.Explorer do
  @moduledoc """
  A file browser with preview functionality built with Raxol.

  Features:
  - Directory navigation with arrow keys
  - File preview pane (text, images as ASCII, code with syntax highlighting)
  - File operations (copy, move, delete, rename)
  - Search within current directory
  - Bookmarks for quick navigation
  - File size and permissions display
  - Hidden files toggle

  Run with: mix run examples/file_browser/explorer.ex [directory]
  """

  use Raxol.UI, framework: :react

  alias Examples.FileBrowser.{State, KeyHandler, FileOperations, Renderer}

  def start(args \\ []) do
    path = List.first(args) || "."
    initial_state = State.new(path)

    Raxol.Runtime.start_link(
      app: __MODULE__,
      initial_state: initial_state,
      title: "Raxol File Explorer"
    )
  end

  @impl true
  def init(state) do
    FileOperations.refresh_directory(state)
  end

  @impl true
  def update(state, event) do
    case event do
      {:key, key} -> KeyHandler.handle_key(state, key)
      {:resize, _width, _height} -> state
      _ -> state
    end
  end

  @impl true
  def render(state) do
    div class: "file-explorer" do
      # Top bar with path and controls
      div class: "top-bar", style: [height: 3, bg: :dark_blue, fg: :white] do
        Renderer.render_top_bar(state)
      end

      # Main content area
      div class: "content", style: [display: :flex, height: :fill] do
        # Bookmarks sidebar
        div class: "bookmarks", style: [width: 20, bg: :dark_gray] do
          Renderer.render_bookmarks(state)
        end

        # File list
        div class: "file-list", style: [flex: 1] do
          Renderer.render_file_list(state)
        end

        # Preview pane
        div class: "preview", style: [width: 40, bg: :black] do
          Renderer.render_preview(state)
        end
      end

      # Status bar
      div class: "status-bar", style: [height: 1, bg: :blue, fg: :white] do
        Renderer.render_status_bar(state)
      end
    end
  end
end

# Start the file browser
Examples.FileBrowser.Explorer.start(System.argv())
