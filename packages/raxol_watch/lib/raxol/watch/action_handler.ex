defmodule Raxol.Watch.ActionHandler do
  @moduledoc """
  Maps watch tap actions back to Raxol Event structs.

  When a user taps a notification action on their watch, the action ID
  is sent back (via webhook or polling) and translated to a TEA event.
  """

  alias Raxol.Core.Events.Event

  @default_action_map %{
    "pause" => {:key, %{key: :char, char: " "}},
    "details" => {:key, %{key: :enter}},
    "acknowledge" => {:key, %{key: :enter}},
    "quit" => {:key, %{key: :char, char: "q"}},
    "next" => {:key, %{key: :tab}},
    "previous" => {:key, %{key: :tab, modifiers: [:shift]}},
    "dismiss" => nil
  }

  @doc """
  Translates a watch tap action into a Raxol Event.

  Returns `nil` for actions that don't produce events (e.g. "dismiss").

  ## Options

    * `:action_map` - custom action mapping (merged with defaults)
  """
  @spec handle_action(String.t(), keyword()) :: Event.t() | nil
  def handle_action(action_id, opts \\ []) do
    actions = merge_actions(opts)

    case Map.get(actions, action_id) do
      {:key, data} -> Event.new(:key, data)
      nil -> nil
    end
  end

  @doc "Returns the default action mapping."
  @spec default_action_map() :: map()
  def default_action_map, do: @default_action_map

  defp merge_actions(opts) do
    case Keyword.get(opts, :action_map) do
      nil -> @default_action_map
      custom when is_map(custom) -> Map.merge(@default_action_map, custom)
      _ -> @default_action_map
    end
  end
end
