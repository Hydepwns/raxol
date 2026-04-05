defmodule Raxol.Agent.Actions.Vfs.ReadFile do
  use Raxol.Agent.Action,
    name: "vfs_read_file",
    description: "Read the contents of a file in the virtual filesystem",
    schema: [
      input: [
        path: [type: :string, required: true, description: "File path to read"]
      ]
    ]

  @spec run(map(), map()) :: {:ok, map()} | {:error, term()}
  @impl true
  def run(%{path: path} = params, context) do
    fs = Raxol.Agent.Actions.Vfs.get_vfs(params, context)

    case Raxol.Commands.FileSystem.cat(fs, path) do
      {:ok, content} -> {:ok, %{content: content, path: path}}
      {:error, reason} -> {:error, reason}
    end
  end
end
