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
# Run this example with:
#
#   mix run examples/documentation_browser.exs

defmodule DocumentationBrowser do
  @behaviour Raxol.App
  use Raxol.View

  alias Raxol.Runtime.Command

  @arrow_up :arrow_up
  @arrow_down :arrow_down

  @header "Documentation Browser Example (UP/DOWN to select module, j/k to scroll content)"

  def init(_context) do
    {:ok, modules} = :application.get_key(:elixir, :modules)

    model = %{
      content: "",
      content_cursor: 0,
      module_cursor: 0,
      modules: modules
    }

    {model, update_cmd(model)}
  end

  def update(
        %{
          content_cursor: content_cursor,
          module_cursor: module_cursor,
          modules: modules
        } = model,
        msg
      ) do
    case msg do
      %{type: :key, key: ?k, modifiers: []} ->
        %{model | content_cursor: max(content_cursor - 1, 0)}

      %{type: :key, key: ?j, modifiers: []} ->
        %{model | content_cursor: content_cursor + 1}

      %{type: :key, key: key, modifiers: []}
      when key in [@arrow_up, @arrow_down] ->
        new_cursor =
          case key do
            @arrow_up -> max(module_cursor - 1, 0)
            @arrow_down -> min(module_cursor + 1, length(modules) - 1)
          end

        new_model = %{model | module_cursor: new_cursor}
        {new_model, update_cmd(new_model)}

      {:content_updated, content} ->
        %{model | content: content}

      _ ->
        model
    end
  end

  def render(model) do
    menu_bar =
      row do
        text(content: @header, color: :blue)
      end

    view do
      row do
        column size: 4 do
          panel(title: "Modules", height: :fill) do
            for {module, idx} <- Enum.with_index(model.modules) do
              if idx == model.module_cursor do
                text(content: "> " <> inspect(module), attributes: [:bold])
              else
                text(content: inspect(module))
              end
            end
          end
        end

        column size: 8 do
          selected = Enum.at(model.modules, model.module_cursor)

          panel(title: inspect(selected), height: :fill) do
            text(content: model.content)
          end
        end
      end
    end
  end

  defp update_cmd(model) do
    Command.new(fn -> fetch_content(model) end, :content_updated)
  end

  defp fetch_content(%{module_cursor: cursor, modules: modules}) do
    selected = Enum.at(modules, cursor)

    case Code.fetch_docs(selected) do
      {:docs_v1, _, :elixir, _, %{"en" => docs}, _, _} ->
        docs

      _ ->
        "(No documentation for #{selected})"
    end
  end
end

Raxol.run(DocumentationBrowser, quit_keys: [?q])
