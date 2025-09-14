defmodule Examples.FileBrowser.Renderer do
  @moduledoc """
  Rendering components for the file browser explorer.

  Handles all UI rendering including file list, preview pane,
  status bar, and bookmarks sidebar.
  """

  use Raxol.UI, framework: :react

  alias Examples.FileBrowser.Helpers

  def render_top_bar(state) do
    div do
      div class: "breadcrumbs" do
        state.current_path
        |> Path.split()
        |> Enum.intersperse(" / ")
        |> Enum.map(fn part ->
          span do
            part
          end
        end)
      end

      div class: "controls", style: [float: :right] do
        "#{length(state.entries)} items | " <>
          "Sort: #{state.sort_by} | " <> "Preview: #{state.preview_mode}"
      end
    end
  end

  def render_bookmarks(state) do
    div class: "bookmarks-list" do
      h3 do
        "Bookmarks"
      end

      state.bookmarks
      |> Enum.with_index()
      |> Enum.map(fn {bookmark, idx} ->
        div class: "bookmark-item",
            style: [cursor: :pointer, padding: 1] do
          "#{idx + 1}. #{bookmark.name}"
        end
      end)
    end
  end

  def render_file_list(state) do
    ~H"""
    <div class="file-list scroll-view">
      <table class="file-table">
        <thead>
          <tr>
            <th class="icon-col">Icon</th>
            <th class="name-col">Name</th>
            <th class="size-col">Size</th>
            <th class="modified-col">Modified</th>
            <th class="permissions-col">Permissions</th>
          </tr>
        </thead>
        <tbody>
          <%= for {entry, idx} <- Enum.with_index(state.entries) do %>
            <tr class={if idx == state.selected_index, do: "selected", else: ""}>
              <td class="icon-col">
                <%= Helpers.file_icon(entry) %>
              </td>
              <td class="name-col">
                <%= if entry.type == :directory do %>
                  <span class="directory-name"><%= entry.name %></span>
                <% else %>
                  <%= entry.name %>
                <% end %>
              </td>
              <td class="size-col">
                <%= Helpers.format_size(entry.size) %>
              </td>
              <td class="modified-col">
                <%= Helpers.format_time(entry.modified) %>
              </td>
              <td class="permissions-col">
                <span class="permissions"><%= entry.permissions %></span>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  def render_preview(state) do
    div class: "preview-panel" do
      h3 do
        "Preview"
      end

      case state.preview_content do
        nil ->
          div style: [fg: :dark_gray] do
            "No preview available"
          end

        {:directory, files} ->
          div do
            h4 do
              "Directory contents:"
            end

            files
            |> Enum.map(fn file ->
              div do
                "  " <> file
              end
            end)
          end

        {:text, content} ->
          div class: "scroll-view" do
            pre do
              content
            end
          end

        {:code, content} ->
          div class: "scroll-view" do
            pre style: [syntax_highlight: true] do
              content
            end
          end

        {:hex, content} ->
          div class: "scroll-view" do
            pre style: [font: :monospace] do
              content
            end
          end

        {:image, ascii} ->
          div do
            ascii
          end

        {:binary, message} ->
          div style: [fg: :yellow] do
            message
          end
      end
    end
  end

  def render_status_bar(state) do
    left =
      case state.mode do
        :search -> "Search: #{state.search_query}_"
        :rename -> "Rename to: #{state.search_query}_"
        :confirm_delete -> state.status_message
        _ -> state.status_message
      end

    right = "h:hidden /: q:quit"

    div style: [display: :flex] do
      div style: [flex: 1] do
        left
      end

      div do
        right
      end
    end
  end
end
