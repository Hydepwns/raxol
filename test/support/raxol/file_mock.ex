defmodule FileMock do
  @moduledoc """
  Default implementation of File.Behaviour for testing.
  """

  @behaviour File.Behaviour

  @impl File.Behaviour
  def stat(_path) do
    # Default implementation returns a regular readable file
    {:ok,
     %File.Stat{
       size: 0,
       type: :regular,
       access: :read,
       atime: {{2024, 1, 1}, {0, 0, 0}},
       mtime: {{2024, 1, 1}, {0, 0, 0}},
       ctime: {{2024, 1, 1}, {0, 0, 0}},
       mode: 0o644,
       links: 1,
       major_device: 0,
       minor_device: 0,
       inode: 0,
       uid: 0,
       gid: 0
     }}
  end

  @impl File.Behaviour
  def exists?(_path), do: true

  @impl File.Behaviour
  def read(_path), do: {:ok, ""}

  @impl File.Behaviour
  def write(_path, _content), do: :ok

  @impl File.Behaviour
  def rm(_path), do: :ok

  @impl File.Behaviour
  def mkdir_p(_path), do: :ok
end
