defmodule Raxol.Agent.Actions.Vfs.ChangeDir do
  use Raxol.Agent.Action,
    name: "vfs_change_dir",
    description: "Change the current working directory in the virtual filesystem",
    schema: [
      input: [
        path: [type: :string, required: true, description: "Directory to change to"]
      ]
    ]

  @impl true
  def run(%{path: path} = params, context) do
    fs = Raxol.Agent.Actions.Vfs.get_vfs(params, context)

    case Raxol.Commands.FileSystem.cd(fs, path) do
      {:ok, new_fs} -> {:ok, %{cwd: Raxol.Commands.FileSystem.pwd(new_fs), vfs: new_fs}}
      {:error, reason} -> {:error, reason}
    end
  end
end
