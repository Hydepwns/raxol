defmodule Raxol.View do
  @moduledoc """
  Main view module for Raxol that provides view macros and sigils.
  
  This module provides the `~V` sigil used in examples to define views
  with Raxol's template syntax.
  """

  @doc """
  Sigil for creating Raxol views with template syntax.
  
  ## Examples
  
      ~V"""
      <.panel title="Hello">
        <.text>Hello, World!</.text>
      </.panel>
      """
  """
  defmacro sigil_V(expr, opts) do
    case expr do
      {_, _, [template]} when is_binary(template) ->
        quote do
          Raxol.View.parse_template(unquote(template), unquote(opts))
        end
      _ ->
        quote do
          unquote(expr)
        end
    end
  end

  @doc """
  Parse a template string into a Raxol view structure.
  """
  def parse_template(template, _opts \\ []) do
    # For now, return the template as-is
    # This is a simplified implementation
    # In a full implementation, this would parse the template syntax
    # and convert it to appropriate Raxol view structures
    %{
      type: :view,
      template: template,
      parsed_at: DateTime.utc_now()
    }
  end

  @doc """
  Import common view functions and macros.
  """
  defmacro __using__(_opts) do
    quote do
      import Raxol.View
      import Raxol.View.Elements
      import Raxol.View.Components
    end
  end
end