defmodule Raxol.Terminal.Clipboard.Format do
  @moduledoc """
  Handles clipboard content formatting and filtering.
  """

  @doc """
  Applies a filter to clipboard content.
  """
  @spec apply_filter(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, :invalid_filter}
  def apply_filter(filter, content, format) do
    case filter do
      "plain" -> {:ok, strip_formatting(content)}
      "html" -> {:ok, to_html(content, format)}
      "rtf" -> {:ok, to_rtf(content, format)}
      _ -> {:error, :invalid_filter}
    end
  end

  @doc """
  Strips formatting from content.
  """
  @spec strip_formatting(String.t()) :: String.t()
  def strip_formatting(content) do
    content
    |> String.replace(~r/<[^>]*>/, "")
    |> String.replace(~r/\n\s*\n/, "\n")
    |> String.trim()
  end

  @doc """
  Converts content to HTML format.
  """
  @spec to_html(String.t(), String.t()) :: String.t()
  def to_html(content, format) do
    case format do
      "text" -> "<pre>#{content}</pre>"
      "html" -> content
      _ -> "<pre>#{content}</pre>"
    end
  end

  @doc """
  Converts content to RTF format.
  """
  @spec to_rtf(String.t(), String.t()) :: String.t()
  def to_rtf(content, format) do
    case format do
      "text" -> "{\\rtf1\\ansi\\deff0\n#{content}}"
      "rtf" -> content
      _ -> "{\\rtf1\\ansi\\deff0\n#{content}}"
    end
  end
end
