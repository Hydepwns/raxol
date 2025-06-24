defmodule Raxol.Terminal.Commands.OSCHandlers.HyperlinkParser do
  @moduledoc false

  @spec parse(String.t()) ::
          {:query, String.t()}
          | {:set, String.t(), String.t()}
          | {:clear, String.t()}
          | {:error, term()}
  def parse(data) do
    case data do
      "?'" ->
        {:query, "'"}

      str when is_binary(str) ->
        case String.split(str, ";") do
          [id, ""] ->
            {:clear, id}

          [id, url] when is_binary(id) and is_binary(url) ->
            {:set, id, url}

          _ ->
            {:error, :invalid_format}
        end

      _ ->
        {:error, :invalid_data}
    end
  end
end
