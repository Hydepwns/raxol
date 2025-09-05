defmodule RaxolWeb.Layouts do
  use RaxolWeb, :html

  embed_templates("layouts/*")

  # Manual fallback for root template if embed_templates fails
  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <title>Raxol</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      </head>
      <body>
        <%= render_flash_message(@flash[:info], :info) %>
        <%= render_flash_message(@flash[:error], :error) %>
        <%= @inner_content %>
      </body>
    </html>
    """
  end

  defp render_flash_message(nil, _type), do: ""

  defp render_flash_message(message, _type) do
    Phoenix.HTML.raw(message)
  end
end
