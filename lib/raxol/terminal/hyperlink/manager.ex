defmodule Raxol.Terminal.Hyperlink.Manager do
  @moduledoc """
  Manages terminal hyperlinks and their states.
  """

  defstruct [
    :url,
    :state,
    :id,
    :params
  ]

  @type hyperlink_state :: :active | :inactive | :hover
  @type hyperlink_params :: %{
          optional(String.t()) => String.t()
        }

  @type t :: %__MODULE__{
          url: String.t(),
          state: hyperlink_state(),
          id: String.t(),
          params: hyperlink_params()
        }

  @doc """
  Creates a new hyperlink manager with default settings.
  """
  def new(opts \\ []) do
    %__MODULE__{
      url: Keyword.get(opts, :url, ""),
      state: Keyword.get(opts, :state, :inactive),
      id: Keyword.get(opts, :id, generate_id()),
      params: Keyword.get(opts, :params, %{})
    }
  end

  @doc """
  Gets the hyperlink URL.
  """
  def get_hyperlink_url(%__MODULE__{} = manager) do
    manager.url
  end

  @doc """
  Updates the hyperlink URL.
  """
  def update_hyperlink_url(%__MODULE__{} = manager, url) do
    %{manager | url: url}
  end

  @doc """
  Gets the current hyperlink state.
  """
  def get_hyperlink_state(%__MODULE__{} = manager) do
    manager.state
  end

  @doc """
  Updates the hyperlink state.
  """
  def update_hyperlink_state(%__MODULE__{} = manager, state)
      when state in [:active, :inactive, :hover] do
    %{manager | state: state}
  end

  @doc """
  Clears the hyperlink state.
  """
  def clear_hyperlink_state(%__MODULE__{} = manager) do
    %{manager | state: :inactive}
  end

  @doc """
  Creates a new hyperlink with the given parameters.
  """
  def create_hyperlink(%__MODULE__{} = manager, url, id \\ nil, params \\ %{}) do
    %{
      manager
      | url: url,
        id: id || generate_id(),
        params: params,
        state: :inactive
    }
  end

  @doc """
  Gets the hyperlink parameters.
  """
  def get_hyperlink_params(%__MODULE__{} = manager) do
    manager.params
  end

  @doc """
  Updates the hyperlink parameters.
  """
  def update_hyperlink_params(%__MODULE__{} = manager, params) do
    %{manager | params: params}
  end

  @doc """
  Gets the hyperlink ID.
  """
  def get_hyperlink_id(%__MODULE__{} = manager) do
    manager.id
  end

  # Private Functions

  defp generate_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end
end
