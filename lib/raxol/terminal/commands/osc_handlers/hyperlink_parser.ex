defmodule Raxol.Terminal.Commands.OSCHandlers.HyperlinkParser do
  @moduledoc """
  Parser for hyperlink data in OSC commands.

  This module handles parsing of hyperlink data in the format:
  - Query: "?'
  - Set: 'id;url"
  - Clear: "id;"
  """

  import Raxol.Guards

  @doc """
  Parses hyperlink data from an OSC command.

  Returns:
  - `{:query, id}` for query commands
  - `{:set, id, url}` for set commands
  - `{:clear, id}` for clear commands
  - `{:error, reason}` for invalid data
  """
  @spec parse(String.t()) ::
          {:query, String.t()}
          | {:set, String.t(), String.t()}
          | {:clear, String.t()}
          | {:error, term()}
  def parse(data) do
    case data do
      "?'" ->
        {:query, "'"}

      str when binary?(str) ->
        case String.split(str, ";") do
          [id, ""] ->
            {:clear, id}

          [id, url] when binary?(id) and binary?(url) ->
            {:set, id, url}

          _ ->
            {:error, :invalid_format}
        end

      _ ->
        {:error, :invalid_data}
    end
  end
end
