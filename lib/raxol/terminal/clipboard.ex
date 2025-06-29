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

  @doc """
  Sets the content of a clipboard instance.

  ## Parameters

    * `clipboard` - The clipboard instance
    * `content` - The content to set

  ## Returns

    * `{:ok, Manager.t()}` - Content set successfully
    * `{:error, reason}` - Failed to set content

  ## Examples

      iex> clipboard = Manager.new()
      iex> {:ok, clipboard} = Clipboard.set_content(clipboard, "Hello, World!")
      iex> Clipboard.get_content(clipboard)
      "Hello, World!"
  """
  @spec set_content(Manager.t(), String.t()) :: {:ok, Manager.t()} | {:error, term()}
  def set_content(clipboard, content) do
    {:ok, Manager.set_content(clipboard, content)}
  end

  @doc """
  Gets the selection content from a clipboard instance.

  ## Parameters

    * `clipboard` - The clipboard instance

  ## Returns

    * `{:ok, String.t()}` - Selection content retrieved successfully
    * `{:error, reason}` - Failed to get selection content

  ## Examples

      iex> clipboard = Manager.new()
      iex> {:ok, content} = Clipboard.get_selection(clipboard)
      iex> content
      ""
  """
  @spec get_selection(Manager.t()) :: {:ok, String.t()} | {:error, term()}
  def get_selection(clipboard) do
    # For now, return the same content as the main clipboard
    # In a real implementation, this would handle separate selection buffer
    {:ok, Manager.get_content(clipboard)}
  end

  @doc """
  Sets the selection content of a clipboard instance.

  ## Parameters

    * `clipboard` - The clipboard instance
    * `content` - The selection content to set

  ## Returns

    * `{:ok, Manager.t()}` - Selection content set successfully
    * `{:error, reason}` - Failed to set selection content

  ## Examples

      iex> clipboard = Manager.new()
      iex> {:ok, clipboard} = Clipboard.set_selection(clipboard, "Selected text")
      iex> {:ok, content} = Clipboard.get_selection(clipboard)
      iex> content
      "Selected text"
  """
  @spec set_selection(Manager.t(), String.t()) :: {:ok, Manager.t()} | {:error, term()}
  def set_selection(clipboard, content) do
    # For now, set the same content as the main clipboard
    # In a real implementation, this would handle separate selection buffer
    {:ok, Manager.set_content(clipboard, content)}
  end
end
