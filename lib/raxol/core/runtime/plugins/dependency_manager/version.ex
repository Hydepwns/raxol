defmodule Raxol.Core.Runtime.Plugins.DependencyManager.Version do
  @moduledoc """
  Handles version parsing and constraint checking for plugin dependencies.
  Provides sophisticated version constraint handling with support for complex requirements.
  """

  @doc """
  Checks if a version satisfies a version requirement.

  ## Parameters

  * `version` - The version string to check
  * `requirement` - The version requirement string

  ## Returns

  * `:ok` - If the version satisfies the requirement
  * `{:error, reason}` - If there's an error or the version doesn't satisfy the requirement
  """
  def check_version(version, requirement) do
    with {:ok, _} <- Version.parse(version),
         {:ok, parsed_req} <- parse_version_requirement(requirement) do
      case parsed_req do
        {:or, reqs} ->
          # reqs is a list of parsed requirements
          case Enum.any?(reqs, &Version.match?(version, &1)) do
            true ->
              :ok

            false ->
              {:error, :version_mismatch}
          end

        req ->
          case Version.match?(version, req) do
            true ->
              :ok

            false ->
              {:error, :version_mismatch}
          end
      end
    else
      :error ->
        {:error, :invalid_version_format}

      {:error, _} ->
        {:error, :invalid_requirement_format}
    end
  end

  @doc """
  Parses a version requirement string into a format suitable for version matching.

  ## Parameters

  * `requirement` - The version requirement string

  ## Returns

  * `{:ok, parsed_requirement}` - The parsed requirement
  * `{:error, :invalid_requirement_format}` - If the requirement is invalid

  ## Examples

      iex> Version.parse_version_requirement(">= 1.0.0")
      {:ok, ">= 1.0.0"}

      iex> Version.parse_version_requirement(">= 1.0.0 || >= 2.0.0")
      {:ok, {:or, [">= 1.0.0", ">= 2.0.0"]}}
  """
  def parse_version_requirement(requirement) when is_binary(requirement) do
    # Handle complex version requirements
    case String.split(requirement, "||") do
      [single_req] ->
        parse_single_requirement(single_req)

      multiple_reqs ->
        # Handle OR conditions
        parsed_reqs = Enum.map(multiple_reqs, &parse_single_requirement/1)

        case Enum.all?(parsed_reqs, &match?({:ok, _}, &1)) do
          true ->
            {:ok, {:or, Enum.map(parsed_reqs, fn {:ok, parsed} -> parsed end)}}

          false ->
            {:error, :invalid_requirement_format}
        end
    end
  end

  def parse_version_requirement(_requirement) do
    {:error, :invalid_requirement_format}
  end

  @doc """
  Parses a single version requirement.

  ## Parameters

  * `req` - The version requirement string

  ## Returns

  * `{:ok, parsed}` - The parsed requirement
  * `{:error, :invalid_requirement_format}` - If the requirement is invalid
  """
  def parse_single_requirement(req) do
    req = String.trim(req)

    case Version.parse_requirement(req) do
      {:ok, parsed} -> {:ok, parsed}
      _ -> {:error, :invalid_requirement_format}
    end
  end
end
