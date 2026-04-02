defmodule Raxol.Agent.Actions.Vfs.Remove do
  use Raxol.Agent.Action,
    name: "vfs_remove",
    description: "Remove a file or empty directory from the virtual filesystem",
    schema: [
      input: [
        path: [type: :string, required: true, description: "Path to remove"]
      ]
    ]

  @impl true
  def run(%{path: path} = params, context) do
    fs = Raxol.Agent.Actions.Vfs.get_vfs(params, context)

    case Raxol.Commands.FileSystem.rm(fs, path) do
      {:ok, new_fs} -> {:ok, %{path: path, vfs: new_fs}}
      {:error, reason} -> {:error, reason}
    end
  end
end
