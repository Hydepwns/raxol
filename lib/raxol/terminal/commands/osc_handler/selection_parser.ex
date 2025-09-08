defmodule Raxol.Terminal.Commands.OSCHandler.SelectionParser do
  @moduledoc false

  @spec parse(String.t()) ::
          {:query, nil}
          | {:start, integer(), integer()}
          | {:end, integer(), integer()}
          | {:clear, nil}
          | {:text, String.t()}
          | {:error, term()}
  def parse(data) do
    case String.split(data, ";") do
      ["?'] -> {:query, nil}
      ['start", x_str, y_str] -> parse_coordinates(x_str, y_str, :start)
      ["end", x_str, y_str] -> parse_coordinates(x_str, y_str, :end)
      ["clear"] -> {:clear, nil}
      ["text" | rest] -> {:text, Enum.join(rest, ";")}
      _ -> {:error, :invalid_format}
    end
  end

  defp parse_coordinates(x_str, y_str, command) do
    with {x, ""} <- Integer.parse(x_str),
         {y, ""} <- Integer.parse(y_str) do
      {command, x, y}
    else
      _ -> {:error, :invalid_coordinates}
    end
  end
end
