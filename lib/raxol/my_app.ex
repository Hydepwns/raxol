defmodule Raxol.MyApp do
  @moduledoc """
  A simple example Raxol application that displays typed text.
  """
  use Raxol.App

  require Logger

  # Bring in View DSL functions
  import Raxol.View

  @impl Raxol.App
  def init(_opts) do
    Logger.info("Raxol.MyApp initialized")
    # Initial state: empty text
    %{text: ""}
  end

  @impl Raxol.App
  def update(model, msg) do
    case msg do
      # Handle key events: append character to text
      %{type: :key, data: %{char: char}} when not is_nil(char) ->
        Logger.debug("MyApp Update: Key Char: #{char}")
        %{model | text: model.text <> <<char::utf8>>}

      # Handle special keys like backspace
      %{type: :key, data: %{key: :backspace}} ->
        Logger.debug("MyApp Update: Key Backspace")
        new_text =
          if String.length(model.text) > 0 do
            String.slice(model.text, 0..-2//-1)
          else
            ""
          end
        %{model | text: new_text}

      # Ignore other messages
      _ ->
        Logger.debug("MyApp Update: Ignored msg: #{inspect(msg)}")
        model
    end
  end

  @impl Raxol.App
  def render(model) do
    Logger.debug("MyApp Render: model=#{inspect(model)}")
    # Render the current text using the View DSL
    view do
      # Revert to using imported functions
      panel title: "Raxol Simple Editor" do
        text "Type something:"
        text "> #{model.text}"
      end
    end
  end
end
