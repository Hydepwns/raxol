defmodule Raxol.Headless.EventBuilder do
  @moduledoc """
  Builds `Raxol.Core.Events.Event` structs from simple inputs.

  Designed for headless session interaction where callers send keystrokes
  without constructing full Event structs manually.
  """

  alias Raxol.Core.Events.Event

  @doc """
  Builds a key event from a character string or atom.

  ## Examples

      EventBuilder.key("q")
      EventBuilder.key(:tab)
      EventBuilder.key("c", ctrl: true)
  """
  @spec key(String.t() | atom(), keyword()) :: Event.t()
  def key(key, opts \\ [])

  def key(char, opts) when is_binary(char) do
    data =
      %{key: :char, char: char}
      |> maybe_add_modifier(:ctrl, opts)
      |> maybe_add_modifier(:alt, opts)
      |> maybe_add_modifier(:shift, opts)

    Event.new(:key, data)
  end

  def key(special, opts) when is_atom(special) do
    data =
      %{key: special}
      |> maybe_add_modifier(:ctrl, opts)
      |> maybe_add_modifier(:alt, opts)
      |> maybe_add_modifier(:shift, opts)

    Event.new(:key, data)
  end

  defp maybe_add_modifier(data, modifier, opts) do
    if Keyword.get(opts, modifier, false) do
      Map.put(data, modifier, true)
    else
      data
    end
  end
end
