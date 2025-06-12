defmodule Raxol.Terminal.Hyperlink.Manager do
  @moduledoc """
  Manages hyperlink operations for the terminal emulator.
  This module handles hyperlink creation, modification, and state tracking.
  """

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  @doc """
  Gets the current hyperlink URL.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  The current hyperlink URL or nil if none exists
  """
  @spec get_hyperlink_url(EmulatorStruct.t()) :: String.t() | nil
  def get_hyperlink_url(%EmulatorStruct{} = emulator) do
    emulator.current_hyperlink_url
  end

  @doc """
  Updates the current hyperlink URL.

  ## Parameters

  * `emulator` - The emulator instance
  * `url` - The new hyperlink URL

  ## Returns

  Updated emulator with new hyperlink URL
  """
  @spec update_hyperlink_url(EmulatorStruct.t(), String.t() | nil) :: EmulatorStruct.t()
  def update_hyperlink_url(%EmulatorStruct{} = emulator, url) when is_binary(url) or is_nil(url) do
    %{emulator | current_hyperlink_url: url}
  end

  @doc """
  Gets the current hyperlink state.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  The current hyperlink state map or nil if none exists
  """
  @spec get_hyperlink_state(EmulatorStruct.t()) :: map() | nil
  def get_hyperlink_state(%EmulatorStruct{} = emulator) do
    emulator.current_hyperlink
  end

  @doc """
  Updates the current hyperlink state.

  ## Parameters

  * `emulator` - The emulator instance
  * `state` - The new hyperlink state map

  ## Returns

  Updated emulator with new hyperlink state
  """
  @spec update_hyperlink_state(EmulatorStruct.t(), map() | nil) :: EmulatorStruct.t()
  def update_hyperlink_state(%EmulatorStruct{} = emulator, state) when is_map(state) or is_nil(state) do
    %{emulator | current_hyperlink: state}
  end

  @doc """
  Clears the current hyperlink state.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  Updated emulator with cleared hyperlink state
  """
  @spec clear_hyperlink_state(EmulatorStruct.t()) :: EmulatorStruct.t()
  def clear_hyperlink_state(%EmulatorStruct{} = emulator) do
    %{
      emulator
      | current_hyperlink_url: nil,
        current_hyperlink: nil
    }
  end

  @doc """
  Creates a new hyperlink state.

  ## Parameters

  * `emulator` - The emulator instance
  * `url` - The hyperlink URL
  * `id` - Optional hyperlink ID
  * `params` - Optional hyperlink parameters

  ## Returns

  Updated emulator with new hyperlink state
  """
  @spec create_hyperlink(EmulatorStruct.t(), String.t(), String.t() | nil, map() | nil) :: EmulatorStruct.t()
  def create_hyperlink(%EmulatorStruct{} = emulator, url, id \\ nil, params \\ %{})
      when is_binary(url) and (is_binary(id) or is_nil(id)) and (is_map(params) or is_nil(params)) do
    state = %{
      url: url,
      id: id,
      params: params || %{},
      created_at: System.system_time(:millisecond)
    }

    %{
      emulator
      | current_hyperlink_url: url,
        current_hyperlink: state
    }
  end
end
