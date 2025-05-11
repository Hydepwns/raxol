# This example shows how to render and scroll multi-line content, as
# well as how to asynchronously perform updates, by implementing a
# documentation browser for Elixir modules.
#
# The browser is intended to be relatively simplistic for the sake of
# readability. But it might be fun to add:
#
#  - Searching
#  - Text reflowing at narrow screen widths
#  - Markdown formatting
#  - Code highlighting
#  - vi-style pagination shortcuts (gg, G, etc.)
#
# Usage:
#   elixir examples/snippets/advanced/documentation_browser.exs

defmodule DocumentationBrowser do
  # Use correct behaviour and DSL
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  alias Raxol.Core.Commands.Command
  alias Raxol.Core.Events.Event
  require Logger

  @header "Docs Browser (UP/DOWN: Select Module | j/k: Scroll Content | q/Ctrl+C: Quit)"

  @impl true
  def init(_context) do
    Logger.debug("DocumentationBrowser: init/1")
    # Get loaded Elixir modules
    modules =
      Code.available_modules()
      |> Enum.sort()

    model = %{
      content: "Loading...",
      # Store content as lines for easier scrolling
      content_lines: [],
      # Top visible line index
      scroll_offset: 0,
      module_cursor: 0,
      modules: modules,
      # Default/Estimate, could be updated via resize events
      view_height: 20
    }

    # Fetch initial content
    command = update_cmd(model)
    # Return :ok tuple
    {:ok, model, [command]}
  end

  @impl true
  def update(
        message,
        %{
          content_lines: content_lines,
          scroll_offset: scroll_offset,
          module_cursor: module_cursor,
          modules: modules,
          view_height: view_height
        } = model
      ) do
    Logger.debug(
      "DocumentationBrowser: update/2 received message: \#{inspect(message)}"
    )

    case message do
      # Use Event struct for keys
      # Scroll content down (move view up)
      %Event{type: :key, data: %{key: :char, char: "j"}} ->
        max_offset = max(0, length(content_lines) - view_height)
        new_offset = min(scroll_offset + 1, max_offset)
        {:ok, %{model | scroll_offset: new_offset}, []}

      # Scroll content up (move view down)
      %Event{type: :key, data: %{key: :char, char: "k"}} ->
        new_offset = max(scroll_offset - 1, 0)
        {:ok, %{model | scroll_offset: new_offset}, []}

      # Select module up
      %Event{type: :key, data: %{key: :key_up}} ->
        new_cursor = max(module_cursor - 1, 0)

        new_model = %{
          model
          | module_cursor: new_cursor,
            scroll_offset: 0,
            content: "Loading..."
        }

        command = update_cmd(new_model)
        {:ok, new_model, [command]}

      # Select module down
      %Event{type: :key, data: %{key: :key_down}} ->
        new_cursor = min(module_cursor + 1, length(modules) - 1)

        new_model = %{
          model
          | module_cursor: new_cursor,
            scroll_offset: 0,
            content: "Loading..."
        }

        command = update_cmd(new_model)
        {:ok, new_model, [command]}

      # Handle quit keys
      %Event{type: :key, data: %{key: :char, char: "q"}} ->
        {:ok, model, [Command.new(:quit)]}

      %Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
        {:ok, model, [Command.new(:quit)]}

      # Assume command results are wrapped
      {:command_result, :content_updated, content} ->
        Logger.debug("DocumentationBrowser: Content updated.")
        lines = String.split(content, "\n")
        # Reset scroll on new content
        {:ok,
         %{model | content: content, content_lines: lines, scroll_offset: 0},
         []}

      # Handle resize event to update view_height
      %Event{type: :resize, data: %{height: height}} ->
        # Subtract 2 for header and border
        new_height = max(1, height - 2)
        {:ok, %{model | view_height: new_height}, []}

      _ ->
        # Return :ok tuple
        {:ok, model, []}
    end
  end

  # Renamed from render/1
  @impl true
  def view(%{view_height: view_height} = model) do
    Logger.debug("DocumentationBrowser: view/1")

    view do
      # Use box and column/row from Elements DSL
      # Use column for header + main row
      column style: %{gap: 0} do
        box style: %{width: :fill, padding: [0, 1]} do
          text(content: @header, style: %{color: :blue})
        end

        # Main content row
        row style: %{height: :fill} do
          box title: "Modules",
              style: [[:width, "30%"], [:height, :fill], [:border, :single]] do
            # Basic list rendering, could use a list component if available
            # Highlight selected module
            module_list_content =
              for {module, idx} <- Enum.with_index(model.modules) do
                prefix = if idx == model.module_cursor, do: "> ", else: "  "
                style = if idx == model.module_cursor, do: [:bold], else: []
                text(content: prefix <> inspect(module), style: style)
              end

            # Need to handle scrolling for the module list as well if it gets long
            column(content: module_list_content, style: %{padding: 1})
          end

          box title: inspect(Enum.at(model.modules, model.module_cursor)),
              style: [[:width, "70%"], [:height, :fill], [:border, :single]] do
            # Implement scrolling by slicing lines
            visible_lines =
              Enum.slice(model.content_lines, model.scroll_offset, view_height)

            visible_content = Enum.join(visible_lines, "\n")
            text(content: visible_content, style: %{padding: 1})
          end
        end
      end
    end
  end

  defp update_cmd(model) do
    Logger.debug(
      "DocumentationBrowser: Creating content update command for module index \#{model.module_cursor}"
    )

    # Pass only needed data to the command function
    module_index = model.module_cursor
    modules = model.modules

    Command.new(
      fn -> fetch_content(module_index, modules) end,
      :content_updated
    )
  end

  defp fetch_content(module_index, modules) do
    selected = Enum.at(modules, module_index)

    Logger.debug(
      "DocumentationBrowser: Fetching docs for \#{inspect(selected)}"
    )

    # Use Code.get_docs for beam chunks
    case Code.get_docs(selected, :docs) do
      {:docs_v1, _annotation, :elixir, _format, %{"en" => docs}, _meta} ->
        docs

      {:docs_v1, _annotation, :elixir, _format, docs_map, _meta}
      when is_map(docs_map) ->
        # Handle cases where default lang might not be 'en'
        elem(Map.to_list(docs_map) |> List.first(), 1)

      nil ->
        "(No documentation found for \#{inspect(selected)})"

      _ ->
        "(Error fetching documentation for \#{inspect(selected)})"
    end
  catch
    kind, reason ->
      IO.puts(
        "Error fetching docs for \#{inspect(selected)}: \#{kind} - \#{inspect(reason)}"
      )

      "(Error fetching documentation for \#{inspect(selected)})"
  end
end

Logger.info("DocumentationBrowser: Starting Raxol...")
# Use standard startup
{:ok, _pid} = Raxol.start_link(DocumentationBrowser, [])
Logger.info("DocumentationBrowser: Raxol started. Running...")
