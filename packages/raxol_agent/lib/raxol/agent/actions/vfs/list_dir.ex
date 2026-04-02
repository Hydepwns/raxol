defmodule Raxol.Agent.Actions.Vfs.ListDir do
  use Raxol.Agent.Action,
    name: "vfs_list_dir",
    description: "List files and directories at a path in the virtual filesystem",
    schema: [
      input: [
        path: [type: :string, description: "Directory path (default: current directory)"]
      ]
    ]

  @impl true
  def run(params, context) do
    fs = Raxol.Agent.Actions.Vfs.get_vfs(params, context)
    path = Map.get(params, :path, ".")

    case Raxol.Commands.FileSystem.ls(fs, path) do
      {:ok, entries} ->
        {:ok, %{entries: entries, cwd: Raxol.Commands.FileSystem.pwd(fs)}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
