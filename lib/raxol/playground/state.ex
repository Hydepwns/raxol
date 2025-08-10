defmodule Raxol.Playground.State do
  @moduledoc """
  State management for the Raxol Playground.
  """

  defstruct [
    :port,
    :catalog,
    :selected_component,
    :current_props,
    :current_state,
    :theme,
    :preview_mode,
    :layout,
    :code_visible,
    :history,
    :bookmarks
  ]

  @type t :: %__MODULE__{
          port: integer(),
          catalog: list(),
          selected_component: map() | nil,
          current_props: map(),
          current_state: map(),
          theme: atom(),
          preview_mode: :terminal | :web,
          layout: :split | :tabs | :full,
          code_visible: boolean(),
          history: list(),
          bookmarks: list()
        }

  @doc """
  Creates a new playground state.
  """
  def new(opts \\ []) do
    %__MODULE__{
      port: Keyword.get(opts, :port, 4444),
      catalog: [],
      selected_component: nil,
      current_props: %{},
      current_state: %{},
      theme: :default,
      preview_mode: :terminal,
      layout: :split,
      code_visible: true,
      history: [],
      bookmarks: []
    }
  end

  @doc """
  Adds an entry to history.
  """
  def add_to_history(state, entry) do
    %{state | history: [entry | Enum.take(state.history, 49)]}
  end

  @doc """
  Adds a bookmark.
  """
  def add_bookmark(state, component_id, props, component_state) do
    bookmark = %{
      id: generate_bookmark_id(),
      component_id: component_id,
      props: props,
      state: component_state,
      timestamp: DateTime.utc_now()
    }

    %{state | bookmarks: [bookmark | state.bookmarks]}
  end

  @doc """
  Loads a bookmark.
  """
  def load_bookmark(state, bookmark_id) do
    case Enum.find(state.bookmarks, &(&1.id == bookmark_id)) do
      nil ->
        {:error, "Bookmark not found"}

      bookmark ->
        {:ok,
         %{
           state
           | selected_component:
               find_component(state.catalog, bookmark.component_id),
             current_props: bookmark.props,
             current_state: bookmark.state
         }}
    end
  end

  defp find_component(catalog, component_id) do
    Enum.find(catalog, &(&1.id == component_id))
  end

  defp generate_bookmark_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
