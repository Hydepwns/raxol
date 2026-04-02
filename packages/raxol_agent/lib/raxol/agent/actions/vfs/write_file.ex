defmodule Raxol.Agent.Actions.Vfs.WriteFile do
  use Raxol.Agent.Action,
    name: "vfs_write_file",
    description: "Create a file with content in the virtual filesystem",
    schema: [
      input: [
        path: [type: :string, required: true, description: "File path to create"],
        content: [type: :string, required: true, description: "File content"]
      ]
    ]

  @impl true
  def run(%{path: path, content: content} = params, context) do
    fs = Raxol.Agent.Actions.Vfs.get_vfs(params, context)

    case Raxol.Commands.FileSystem.create_file(fs, path, content) do
      {:ok, new_fs} -> {:ok, %{path: path, size: byte_size(content), vfs: new_fs}}
      {:error, reason} -> {:error, reason}
    end
  end
end
