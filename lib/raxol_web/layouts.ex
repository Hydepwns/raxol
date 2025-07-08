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
        <%= if @flash[:info], do: Phoenix.HTML.raw(@flash[:info]) %>
        <%= if @flash[:error], do: Phoenix.HTML.raw(@flash[:error]) %>
        <%= @inner_content %>
      </body>
    </html>
    """
  end
end
