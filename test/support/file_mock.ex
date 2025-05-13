defmodule FileMock do
  @moduledoc """
  Default implementation of File.Behaviour for testing.
  """

  @behaviour File.Behaviour

  @impl true
  def stat(path) do
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

  @impl true
  def exists?(_path), do: true

  @impl true
  def read(_path), do: {:ok, ""}

  @impl true
  def write(_path, _content), do: :ok

  @impl true
  def rm(_path), do: :ok

  @impl true
  def mkdir_p(_path), do: :ok
end
