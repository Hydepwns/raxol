defmodule Raxol.Agent.Actions.Vfs.GetTree do
  use Raxol.Agent.Action,
    name: "vfs_get_tree",
    description: "Get a directory tree representation from the virtual filesystem",
    schema: [
      input: [
        path: [type: :string, description: "Root path (default: /)"],
        depth: [type: :integer, description: "Maximum depth (default: 3)"]
      ]
    ]

  @spec run(map(), map()) :: {:ok, map()} | {:error, term()}
  @impl true
  def run(params, context) do
    fs = Raxol.Agent.Actions.Vfs.get_vfs(params, context)
    path = Map.get(params, :path, "/")
    depth = Map.get(params, :depth, 3)

    case Raxol.Commands.FileSystem.tree(fs, path, depth) do
      {:ok, tree_node} -> {:ok, %{tree: format_tree(tree_node)}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec format_tree(Raxol.Commands.FileSystem.tree_node()) ::
          String.t() | %{name: String.t(), children: list()}
  defp format_tree({name, :file, _}), do: name
  defp format_tree({name, :directory, []}), do: name <> "/"

  defp format_tree({name, :directory, children}) do
    display_name = if name == "/", do: "/", else: name <> "/"
    %{name: display_name, children: Enum.map(children, &format_tree/1)}
  end
end
