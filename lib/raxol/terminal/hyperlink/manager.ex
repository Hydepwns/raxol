defmodule Raxol.Terminal.Hyperlink.Manager do
  @moduledoc """
  Manages terminal hyperlinks and their states.
  """

  defstruct [
    hyperlink_url: nil,
    hyperlink_state: :inactive,  # :inactive, :active, :hover
    hyperlink_id: nil,
    hyperlink_params: %{}
  ]

  @type hyperlink_state :: :inactive | :active | :hover
  @type hyperlink_params :: %{String.t() => String.t()}

  @type t :: %__MODULE__{
    hyperlink_url: String.t() | nil,
    hyperlink_state: hyperlink_state(),
    hyperlink_id: String.t() | nil,
    hyperlink_params: hyperlink_params()
  }

  @doc """
  Creates a new hyperlink manager instance.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Gets the current hyperlink URL.
  """
  def get_hyperlink_url(%__MODULE__{} = state) do
    state.hyperlink_url
  end

  @doc """
  Updates the hyperlink URL.
  """
  def update_hyperlink_url(%__MODULE__{} = state, url) when is_binary(url) do
    %{state | hyperlink_url: url}
  end

  @doc """
  Gets the current hyperlink state.
  """
  def get_hyperlink_state(%__MODULE__{} = state) do
    state.hyperlink_state
  end

  @doc """
  Updates the hyperlink state.
  """
  def update_hyperlink_state(%__MODULE__{} = state, new_state)
      when new_state in [:inactive, :active, :hover] do
    %{state | hyperlink_state: new_state}
  end

  @doc """
  Clears the hyperlink state.
  """
  def clear_hyperlink_state(%__MODULE__{} = state) do
    %{state |
      hyperlink_url: nil,
      hyperlink_state: :inactive,
      hyperlink_id: nil,
      hyperlink_params: %{}
    }
  end

  @doc """
  Creates a new hyperlink with the given parameters.
  """
  def create_hyperlink(%__MODULE__{} = state, id, url, params \\ %{})
      when is_binary(id) and is_binary(url) and is_map(params) do
    %{state |
      hyperlink_id: id,
      hyperlink_url: url,
      hyperlink_params: params,
      hyperlink_state: :inactive
    }
  end

  @doc """
  Gets the hyperlink ID.
  """
  def get_hyperlink_id(%__MODULE__{} = state) do
    state.hyperlink_id
  end

  @doc """
  Gets the hyperlink parameters.
  """
  def get_hyperlink_params(%__MODULE__{} = state) do
    state.hyperlink_params
  end

  @doc """
  Updates the hyperlink parameters.
  """
  def update_hyperlink_params(%__MODULE__{} = state, params) when is_map(params) do
    %{state | hyperlink_params: params}
  end

  @doc """
  Checks if a hyperlink is active.
  """
  def hyperlink_active?(%__MODULE__{} = state) do
    state.hyperlink_state == :active
  end

  @doc """
  Checks if a hyperlink is being hovered.
  """
  def hyperlink_hover?(%__MODULE__{} = state) do
    state.hyperlink_state == :hover
  end

  @doc """
  Checks if a hyperlink exists.
  """
  def has_hyperlink?(%__MODULE__{} = state) do
    state.hyperlink_url != nil
  end
end
