defmodule Raxol.Agent.Actions.Vfs.MakeDir do
  use Raxol.Agent.Action,
    name: "vfs_make_dir",
    description: "Create a directory in the virtual filesystem",
    schema: [
      input: [
        path: [type: :string, required: true, description: "Directory path to create"]
      ]
    ]

  @impl true
  def run(%{path: path} = params, context) do
    fs = Raxol.Agent.Actions.Vfs.get_vfs(params, context)

    case Raxol.Commands.FileSystem.mkdir(fs, path) do
      {:ok, new_fs} -> {:ok, %{path: path, vfs: new_fs}}
      {:error, reason} -> {:error, reason}
    end
  end
end
