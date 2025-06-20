defmodule Raxol.Terminal.Clipboard do
  @moduledoc """
  Provides a high-level interface for clipboard operations.

  This module offers a unified API for clipboard operations across different
  terminal environments. It supports:
  * Copying content to clipboard
  * Pasting content from clipboard
  * Clearing clipboard contents
  * Multiple clipboard formats

  ## Clipboard Formats

  The module supports different clipboard formats:
  * `"text"` - Plain text (default)
  * `"html"` - HTML content
  * `"rtf"` - Rich Text Format
  * Custom formats as needed

  ## Usage

  ```elixir
  # Copy text to clipboard
  Clipboard.copy("Hello, World!")

  # Copy HTML content
  Clipboard.copy("<b>Hello</b>", "html")

  # Paste from clipboard
  {:ok, content} = Clipboard.paste()

  # Clear clipboard
  Clipboard.clear()
  ```
  """

  alias Raxol.Terminal.Clipboard.Manager

  @doc """
  Copies content to the clipboard.

  ## Parameters

    * `content` - The content to copy
    * `format` - The clipboard format (default: "text")

  ## Returns

    * `:ok` - Content copied successfully

  ## Examples

      iex> Clipboard.copy("Hello, World!")
      :ok

      iex> Clipboard.copy("<b>Hello</b>", "html")
      :ok
  """
  @spec copy(String.t(), String.t()) :: :ok
  def copy(content, format \\ "text") do
    Manager.copy(content, format)
  end

  @doc """
  Pastes content from the clipboard.

  ## Parameters

    * `format` - The clipboard format to paste (default: "text")

  ## Returns

    * `{:ok, content}` - Content pasted successfully
    * `{:error, :empty_clipboard}` - Clipboard is empty

  ## Examples

      iex> Clipboard.copy("Hello, World!")
      iex> Clipboard.paste()
      {:ok, "Hello, World!"}

      iex> Clipboard.clear()
      iex> Clipboard.paste()
      {:error, :empty_clipboard}
  """
  @spec paste(String.t()) :: {:ok, String.t()} | {:error, :empty_clipboard}
  def paste(format \\ "text") do
    Manager.paste(format)
  end

  @doc """
  Clears the clipboard contents.

  ## Returns

    * `:ok` - Clipboard cleared successfully

  ## Examples

      iex> Clipboard.copy("Hello, World!")
      iex> Clipboard.clear()
      iex> Clipboard.paste()
      {:error, :empty_clipboard}
  """
  @spec clear() :: :ok
  def clear do
    Manager.clear()
  end

  @doc """
  Gets the content from a clipboard instance.

  ## Parameters

    * `clipboard` - The clipboard instance

  ## Returns

    * `String.t()` - The clipboard content

  ## Examples

      iex> clipboard = Manager.new()
      iex> clipboard = Manager.set_content(clipboard, "Hello, World!")
      iex> Clipboard.get_content(clipboard)
      "Hello, World!"
  """
  @spec get_content(Manager.t()) :: String.t()
  def get_content(clipboard) do
    Manager.get_content(clipboard)
  end
end
