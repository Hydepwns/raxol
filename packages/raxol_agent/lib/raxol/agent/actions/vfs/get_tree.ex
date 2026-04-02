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

  defp format_tree({name, :file, []}), do: name

  defp format_tree({"/", :directory, children}) do
    %{name: "/", children: Enum.map(children, &format_tree/1)}
  end

  defp format_tree({name, :directory, []}) do
    name <> "/"
  end

  defp format_tree({name, :directory, children}) do
    %{name: name <> "/", children: Enum.map(children, &format_tree/1)}
  end
end
