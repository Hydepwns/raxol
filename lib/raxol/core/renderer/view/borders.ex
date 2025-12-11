defmodule Raxol.Core.Renderer.View.Borders do
  @moduledoc """
  Border-related functions for the View module.
  Extracted from the main View module to improve maintainability.
  """

  alias Raxol.Core.Renderer.View.Style.Border

  # Helper function for validating opts
  defp validate_keyword_opts!(opts, function_name) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "Borders.#{function_name} macro expects a keyword list as the second argument, got: #{inspect(opts)}"
    end
  end

  @doc """
  Wraps a view with a border, optionally with a title and style.

  ## Parameters
    * `view` - The view to wrap with a border
    * `opts` - Options for the border
      * `:title` - Optional title to display in the border
      * `:style` - Border style (`:single`, `:double`, `:rounded`, `:bold`, `:block`, `:simple`)
      * `:align` - Title alignment (`:left`, `:center`, `:right`)

  ## Examples

      Borders.wrap_with_border(view, style: :single)
      Borders.wrap_with_border(view, title: "Title", style: :double)
  """
  def wrap_with_border(view, opts \\ []) do
    validate_keyword_opts!(opts, "wrap_with_border")
    Border.wrap(view, opts)
  end

  @doc """
  Wraps a view with a border using a block style.

  ## Parameters
    * `view` - The view to wrap with a border
    * `opts` - Options for the border
      * `:title` - Optional title to display in the border
      * `:align` - Title alignment (`:left`, `:center`, `:right`)

  ## Examples

      Borders.block_border(view)
      Borders.block_border(view, title: "Title")
  """
  def block_border(view, opts \\ []) do
    validate_keyword_opts!(opts, "block_border")
    wrap_with_border(view, Keyword.put(opts, :style, :block))
  end

  @doc """
  Wraps a view with a border using a double line style.

  ## Parameters
    * `view` - The view to wrap with a border
    * `opts` - Options for the border
      * `:title` - Optional title to display in the border
      * `:align` - Title alignment (`:left`, `:center`, `:right`)

  ## Examples

      Borders.double_border(view)
      Borders.double_border(view, title: "Title")
  """
  def double_border(view, opts \\ []) do
    validate_keyword_opts!(opts, "double_border")
    wrap_with_border(view, Keyword.put(opts, :style, :double))
  end

  @doc """
  Wraps a view with a border using a rounded style.

  ## Parameters
    * `view` - The view to wrap with a border
    * `opts` - Options for the border
      * `:title` - Optional title to display in the border
      * `:align` - Title alignment (`:left`, `:center`, `:right`)

  ## Examples

      Borders.rounded_border(view)
      Borders.rounded_border(view, title: "Title")
  """
  def rounded_border(view, opts \\ []) do
    validate_keyword_opts!(opts, "rounded_border")
    wrap_with_border(view, Keyword.put(opts, :style, :rounded))
  end

  @doc """
  Wraps a view with a border using a bold style.

  ## Parameters
    * `view` - The view to wrap with a border
    * `opts` - Options for the border
      * `:title` - Optional title to display in the border
      * `:align` - Title alignment (`:left`, `:center`, `:right`)

  ## Examples

      Borders.bold_border(view)
      Borders.bold_border(view, title: "Title")
  """
  def bold_border(view, opts \\ []) do
    validate_keyword_opts!(opts, "bold_border")
    wrap_with_border(view, Keyword.put(opts, :style, :bold))
  end

  @doc """
  Wraps a view with a border using a simple style.

  ## Parameters
    * `view` - The view to wrap with a border
    * `opts` - Options for the border
      * `:title` - Optional title to display in the border
      * `:align` - Title alignment (`:left`, `:center`, `:right`)

  ## Examples

      Borders.simple_border(view)
      Borders.simple_border(view, title: "Title")
  """
  def simple_border(view, opts \\ []) do
    validate_keyword_opts!(opts, "simple_border")
    wrap_with_border(view, Keyword.put(opts, :style, :simple))
  end
end
