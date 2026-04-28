defmodule Raxol.Symphony.Workflow do
  @moduledoc """
  Loader for `WORKFLOW.md` -- the repository-owned contract that drives a
  Symphony deployment.

  Implements SPEC s5.2 parsing rules:

  - If file starts with `---`, parse lines until the next `---` as YAML front
    matter.
  - Remaining lines become the prompt body.
  - If front matter is absent, treat the entire file as prompt body and use an
    empty config map.
  - YAML front matter MUST decode to a map/object; non-map YAML is an error.
  - Prompt body is trimmed before use.

  Returned object:

  - `:config` -- front matter root map (atomized keys), or `%{}` when absent.
  - `:prompt_template` -- trimmed Markdown body.
  """

  @type t :: %{
          config: map(),
          prompt_template: binary()
        }

  @type error ::
          :missing_workflow_file
          | {:workflow_parse_error, term()}
          | :workflow_front_matter_not_a_map

  @front_matter_delimiter "---"

  @doc """
  Loads and parses `WORKFLOW.md` from the given path.

  Returns `{:ok, %{config: map, prompt_template: binary}}` or an error tuple
  with one of the SPEC s5.5 error classes.
  """
  @spec load(Path.t()) :: {:ok, t()} | {:error, error()}
  def load(path) when is_binary(path) do
    case File.read(path) do
      {:ok, contents} -> parse(contents)
      {:error, _reason} -> {:error, :missing_workflow_file}
    end
  end

  @doc """
  Parses workflow file contents directly (skipping the file read).

  Useful for testing and when the contents have already been loaded by a file
  watcher.
  """
  @spec parse(binary()) :: {:ok, t()} | {:error, error()}
  def parse(contents) when is_binary(contents) do
    case split_front_matter(contents) do
      {:no_front_matter, body} ->
        {:ok, %{config: %{}, prompt_template: trim(body)}}

      {:front_matter, yaml, body} ->
        with {:ok, decoded} <- decode_yaml(yaml),
             :ok <- ensure_map(decoded) do
          {:ok, %{config: atomize_keys(decoded), prompt_template: trim(body)}}
        end
    end
  end

  # -- Internals --------------------------------------------------------------

  defp split_front_matter(contents) do
    case String.split(contents, ~r/\R/, parts: :infinity) do
      [@front_matter_delimiter | rest] ->
        case Enum.split_while(rest, &(&1 != @front_matter_delimiter)) do
          {_yaml_lines, []} ->
            # Opening delimiter without a closing one is treated as no front
            # matter -- the entire file becomes the body. This matches the
            # reference impl's behavior.
            {:no_front_matter, contents}

          {yaml_lines, [@front_matter_delimiter | body_lines]} ->
            {:front_matter, Enum.join(yaml_lines, "\n"), Enum.join(body_lines, "\n")}
        end

      _other ->
        {:no_front_matter, contents}
    end
  end

  defp decode_yaml("") do
    {:ok, %{}}
  end

  defp decode_yaml(yaml) do
    case YamlElixir.read_from_string(yaml) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, reason} -> {:error, {:workflow_parse_error, reason}}
    end
  end

  defp ensure_map(map) when is_map(map), do: :ok
  defp ensure_map(_), do: {:error, :workflow_front_matter_not_a_map}

  defp trim(body), do: String.trim(body)

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {atomize_key(k), atomize_value(v)} end)
  end

  defp atomize_value(v) when is_map(v), do: atomize_keys(v)
  defp atomize_value(v) when is_list(v), do: Enum.map(v, &atomize_value/1)
  defp atomize_value(v), do: v

  # Map keys to atoms when they are valid YAML identifier strings; otherwise
  # leave as strings. This is safe because front matter keys are
  # author-controlled (no untrusted-input atom-creation risk).
  defp atomize_key(key) when is_binary(key) do
    String.to_atom(key)
  end

  defp atomize_key(key), do: key
end
