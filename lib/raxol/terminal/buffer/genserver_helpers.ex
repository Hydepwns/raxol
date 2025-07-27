defmodule Raxol.Terminal.Buffer.GenServerHelpers do
  @moduledoc """
  Shared helpers for GenServer-based buffer modules.
  """

  @doc """
  Starts a GenServer with proper name validation.

  This function handles the common pattern of starting a GenServer with
  optional naming while ensuring the name is valid for GenServer use.

  ## Parameters

  * `module` - The GenServer module to start
  * `opts` - Options keyword list, may include `:name`

  ## Returns

  * `{:ok, pid}` - The process ID of the started server
  * `{:error, reason}` - If the server fails to start
  """
  @spec start_link_with_name_validation(module(), keyword()) ::
          {:ok, pid()} | {:error, term()}
  def start_link_with_name_validation(module, opts \\ []) do
    name = Keyword.get(opts, :name)
    gen_server_opts = Keyword.delete(opts, :name)

    # Ensure we have a valid name for GenServer
    valid_name = validate_genserver_name(name, module)

    if valid_name do
      GenServer.start_link(module, gen_server_opts, name: valid_name)
    else
      GenServer.start_link(module, gen_server_opts)
    end
  end

  @doc """
  Validates a GenServer name, returning a valid name or nil.

  ## Parameters

  * `name` - The proposed name
  * `fallback_module` - Module to use as fallback name

  ## Returns

  A valid GenServer name or nil if no valid name can be determined.
  """
  @spec validate_genserver_name(term(), module()) ::
          atom() | {:global, term()} | {:via, module(), term()} | nil
  def validate_genserver_name(name, fallback_module) do
    case name do
      nil -> fallback_module
      # Don't use references as names
      ref when is_reference(ref) -> nil
      atom when is_atom(atom) -> atom
      {:global, term} -> {:global, term}
      {:via, module, term} -> {:via, module, term}
      # Fallback to module name
      _ -> fallback_module
    end
  end
end
