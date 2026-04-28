defmodule Raxol.Symphony.PathSafety do
  @moduledoc """
  Workspace path safety primitives.

  Implements SPEC s9.5 invariants:

  - **Invariant 1**: Coding agent runs only inside its per-issue workspace path
    (cwd check enforced at agent launch).
  - **Invariant 2**: Workspace path stays inside workspace root (prefix check
    on normalized absolute paths).
  - **Invariant 3**: Workspace key sanitized to `[A-Za-z0-9._-]` only.

  These checks are the baseline filesystem guarantee; they do not replace the
  agent's approval/sandbox policy.
  """

  @sanitize_pattern ~r/[^A-Za-z0-9._-]/u

  @doc """
  Sanitizes an issue identifier into a workspace key.

  Replaces any character outside `[A-Za-z0-9._-]` with `_`.
  """
  @spec sanitize_key(binary()) :: binary()
  def sanitize_key(identifier) when is_binary(identifier) do
    Regex.replace(@sanitize_pattern, identifier, "_")
  end

  @doc """
  Computes the absolute workspace path for an issue.

  Returns `{:ok, path}` when the resulting path is inside `workspace_root`,
  otherwise `{:error, :workspace_outside_root}`.
  """
  @spec workspace_path(Path.t(), binary()) ::
          {:ok, Path.t()} | {:error, :workspace_outside_root | :invalid_workspace_root}
  def workspace_path(workspace_root, identifier)
      when is_binary(workspace_root) and is_binary(identifier) do
    with {:ok, root} <- absolutize(workspace_root) do
      key = sanitize_key(identifier)
      candidate = Path.join(root, key) |> Path.expand()
      validate_inside_root(candidate, root)
    end
  end

  @doc """
  Validates that `path` is contained within `root`.

  Both arguments are normalized to absolute paths before comparison.

  Returns `{:ok, path}` (the normalized path) or
  `{:error, :workspace_outside_root}`.
  """
  @spec validate_inside_root(Path.t(), Path.t()) ::
          {:ok, Path.t()} | {:error, :workspace_outside_root | :invalid_workspace_root}
  def validate_inside_root(path, root)
      when is_binary(path) and is_binary(root) do
    with {:ok, abs_path} <- absolutize(path),
         {:ok, abs_root} <- absolutize(root) do
      if inside?(abs_path, abs_root) do
        {:ok, abs_path}
      else
        {:error, :workspace_outside_root}
      end
    end
  end

  @doc """
  Asserts that the current working directory matches `expected_path`.

  Used as the SPEC s9.5 Invariant 1 check immediately before launching a
  coding-agent subprocess.
  """
  @spec assert_cwd!(Path.t()) :: :ok | no_return()
  def assert_cwd!(expected_path) when is_binary(expected_path) do
    {:ok, cwd} = File.cwd()

    if Path.expand(cwd) == Path.expand(expected_path) do
      :ok
    else
      raise "PathSafety: cwd #{inspect(cwd)} != expected workspace #{inspect(expected_path)}"
    end
  end

  # -- Internals --------------------------------------------------------------

  defp absolutize(""), do: {:error, :invalid_workspace_root}

  defp absolutize(path) when is_binary(path) do
    {:ok, Path.expand(path)}
  end

  defp inside?(path, root) do
    # Append `/` so that `/foo/barbaz` is not considered inside `/foo/bar`.
    path_with_sep = path <> "/"
    root_with_sep = ensure_trailing_slash(root)
    path == root or String.starts_with?(path_with_sep, root_with_sep)
  end

  defp ensure_trailing_slash(path) do
    if String.ends_with?(path, "/"), do: path, else: path <> "/"
  end
end
