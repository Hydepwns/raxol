defmodule Raxol.Test.ProcessNaming do
  @moduledoc """
  Utilities for generating unique process names in tests.

  This module provides functions to generate unique process names
  to avoid conflicts when running tests concurrently (async: true).
  """

  @doc """
  Generates a unique process name for a given module.

  ## Parameters
    * `module` - The module name (atom or string)
    * `suffix` - Optional suffix to append to the name

  ## Returns
    * `atom()` - A unique process name

  ## Examples
      iex> Raxol.Test.ProcessNaming.generate_name(Raxol.Terminal.Sync.System)
      :Raxol_Terminal_Sync_System_12345

      iex> Raxol.Test.ProcessNaming.generate_name(Raxol.Terminal.Sync.System, "test")
      :Raxol_Terminal_Sync_System_test_12345
  """
  def generate_name(module, suffix \\ "") do
    test_id = get_test_id()
    base_name = module |> to_string() |> String.replace("Elixir.", "")
    name = case suffix == "" do
      true -> base_name
      false -> "#{base_name}_#{suffix}"
    end
    :"#{name}_#{test_id}"
  end

  @doc """
  Generates a unique process name with a specific prefix.

  ## Parameters
    * `prefix` - The prefix for the process name
    * `suffix` - Optional suffix to append

  ## Returns
    * `atom()` - A unique process name

  ## Examples
      iex> Raxol.Test.ProcessNaming.generate_name_with_prefix("sync", "test")
      :sync_test_12345
  """
  def generate_name_with_prefix(prefix, suffix \\ "") do
    test_id = get_test_id()
    name = case suffix == "" do
      true -> prefix
      false -> "#{prefix}_#{suffix}"
    end
    :"#{name}_#{test_id}"
  end

  @doc """
  Gets a unique test identifier.

  Uses EXUNIT_TEST_ID environment variable if available,
  otherwise generates a unique integer.

  ## Returns
    * `integer()` - A unique test identifier
  """
  def get_test_id do
    case System.get_env("EXUNIT_TEST_ID") do
      nil -> System.unique_integer([:positive])
      test_id -> String.to_integer(test_id)
    end
  end

  @doc """
  Creates a start_link function that uses unique names.

  This is a helper for modules that need to generate unique names
  in their start_link functions.

  ## Parameters
    * `module` - The module calling this function
    * `opts` - Options passed to start_link

  ## Returns
    * `atom()` - A unique process name

  ## Examples
      def start_link(opts \\ []) do
        name = Raxol.Test.ProcessNaming.unique_name(__MODULE__, opts)
        GenServer.start_link(__MODULE__, opts, name: name)
      end
  """
  def unique_name(module, opts \\ []) do
    Keyword.get(opts, :name, generate_name(module))
  end
end
