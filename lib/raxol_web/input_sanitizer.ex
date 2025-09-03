defmodule RaxolWeb.InputSanitizer do
  @moduledoc """
  Provides input sanitization for security.
  """

  @doc """
  Sanitizes terminal input to prevent injection attacks.
  """
  @spec sanitize_terminal_input(String.t()) ::
          {:ok, String.t()} | {:error, :invalid_input}
  def sanitize_terminal_input(input) when is_binary(input) do
    # Remove potentially dangerous characters
    sanitized =
      input
      # Only printable ASCII + newlines/tabs
      |> String.replace(~r/[^\x20-\x7E\n\r\t]/, "")
      # Remove null bytes
      |> String.replace(~r/\x00/, "")
      # Remove ANSI escape sequences
      |> String.replace(~r/\x1B\[[0-9;]*[a-zA-Z]/, "")

    if String.valid?(sanitized) and byte_size(sanitized) <= 1024 do
      {:ok, sanitized}
    else
      {:error, :invalid_input}
    end
  end

  def sanitize_terminal_input(_), do: {:error, :invalid_input}

  @doc """
  Validates and sanitizes form input.
  """
  @spec sanitize_form_input(map(), [atom()]) ::
          {:ok, map()} | {:error, :invalid_input}
  def sanitize_form_input(params, allowed_fields) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           params
           |> Map.take(allowed_fields)
           |> Enum.map(fn {key, value} ->
             {key, sanitize_string_value(value)}
           end)
           |> Map.new()
         end) do
      {:ok, sanitized} -> {:ok, sanitized}
      {:error, _reason} -> {:error, :invalid_input}
    end
  end

  defp sanitize_string_value(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.replace(~r/<script[^>]*>.*?<\/script>/is, "")
    |> String.replace(~r/<[^>]*>/, "")
    |> String.replace(~r/[^\w\s\-\.@]/, "")
  end

  defp sanitize_string_value(value), do: value
end
