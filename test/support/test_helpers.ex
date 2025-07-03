defmodule Raxol.Test.Helpers do
  @moduledoc """
  Common test helpers for process management and assertions.
  """

  import ExUnit.Assertions
  import ExUnit.Callbacks

  @doc """
  Starts a named process using the process naming utility.

  ## Parameters
    * `module` - The module to start
    * `opts` - Options to pass to start_link

  ## Returns
    * `{:ok, pid}` - The started process

  ## Examples
      iex> {:ok, pid} = Raxol.Test.Helpers.start_named_process(Raxol.Terminal.Sync.System)
      iex> is_pid(pid)
      true
  """
  def start_named_process(module, opts \\ []) do
    name = Raxol.Test.ProcessNaming.generate_name(module)
    start_supervised({module, Keyword.put(opts, :name, name)})
  end

  @doc """
  Asserts that a process has been started with the given name.

  ## Parameters
    * `module` - The module name
    * `name` - The process name to check

  ## Examples
      iex> Raxol.Test.Helpers.assert_process_started(Raxol.Terminal.Sync.System, :some_name)
      :ok
  """
  def assert_process_started(module, name) do
    assert Process.whereis(name)
  end

  @doc """
  Asserts that a render event is received with the expected content.

  ## Parameters
    * `expected_content` - The expected text content in the render event
    * `timeout` - Timeout in milliseconds (default: 100)

  ## Examples
      iex> Raxol.Test.Helpers.assert_render_event("Hello World")
      :ok
  """
  def assert_render_event(expected_content, timeout \\ 100) do
    receive do
      {:renderer_rendered, ops} ->
        assert Enum.any?(ops, fn op ->
                 case op do
                   {:draw_text, _line, text} -> text == expected_content
                   _ -> false
                 end
               end),
               "Expected render event with content '#{expected_content}' but got #{inspect(ops)}"
    after
      timeout ->
        flunk(
          "Expected render event with content '#{expected_content}' not received within #{timeout}ms"
        )
    end
  end

  @doc """
  Asserts that a partial render event is received.

  ## Parameters
    * `expected_path` - The expected path for the partial update
    * `expected_subtree` - The expected subtree content
    * `expected_tree` - The expected full tree
    * `timeout` - Timeout in milliseconds (default: 100)

  ## Examples
      iex> Raxol.Test.Helpers.assert_partial_render_event([], subtree, full_tree)
      :ok
  """
  def assert_partial_render_event(
        expected_path,
        expected_subtree,
        expected_tree,
        timeout \\ 100
      ) do
    receive do
      {:renderer_partial_update, path, subtree, tree} ->
        assert path == expected_path,
               "Expected path #{inspect(expected_path)}, got #{inspect(path)}"

        assert subtree == expected_subtree,
               "Expected subtree #{inspect(expected_subtree)}, got #{inspect(subtree)}"

        assert tree == expected_tree,
               "Expected tree #{inspect(expected_tree)}, got #{inspect(tree)}"
    after
      timeout ->
        flunk("Expected partial render event not received within #{timeout}ms")
    end
  end

  @doc """
  Asserts that no render event is received within the timeout.

  ## Parameters
    * `timeout` - Timeout in milliseconds (default: 50)

  ## Examples
      iex> Raxol.Test.Helpers.refute_render_event()
      :ok
  """
  def refute_render_event(timeout \\ 50) do
    receive do
      {:renderer_rendered, ops} ->
        flunk("Unexpected render event received: #{inspect(ops)}")

      {:renderer_partial_update, path, subtree, tree} ->
        flunk(
          "Unexpected partial render event received: path=#{inspect(path)}, subtree=#{inspect(subtree)}, tree=#{inspect(tree)}"
        )
    after
      timeout -> :ok
    end
  end

  @doc """
  Sets up a test environment with renderer and pipeline processes.

  ## Returns
    * `map()` - Map containing renderer_pid and pipeline_pid

  ## Examples
      iex> %{renderer_pid: r_pid, pipeline_pid: p_pid} = Raxol.Test.Helpers.setup_rendering_test()
      iex> is_pid(r_pid) and is_pid(p_pid)
      true
  """
  def setup_rendering_test do
    # Start the Renderer GenServer with module name registration
    {:ok, renderer_pid} =
      start_supervised(
        {Raxol.UI.Rendering.Renderer,
         name: Raxol.UI.Rendering.Renderer}
      )

    # Start the Pipeline GenServer with module name registration
    # This bypasses the unique name generation in test mode to ensure
    # the public API functions can find the process
    {:ok, pipeline_pid} =
      start_supervised(
        {Raxol.UI.Rendering.Pipeline, name: Raxol.UI.Rendering.Pipeline}
      )

    # Set test notification for renderer using the actual PID
    GenServer.cast(renderer_pid, {:set_test_pid, self()})

    %{renderer_pid: renderer_pid, pipeline_pid: pipeline_pid}
  end

  @doc """
  Asserts window size matches expected dimensions.

  ## Parameters
    * `emulator` - The emulator to check
    * `expected_width` - Expected width in characters
    * `expected_height` - Expected height in characters

  ## Examples
      iex> Raxol.Test.Helpers.assert_window_size(emulator, 80, 24)
      :ok
  """
  def assert_window_size(emulator, expected_width, expected_height) do
    assert emulator.window_state.size == {expected_width, expected_height}

    # Calculate expected pixel dimensions
    char_width_px =
      Raxol.Terminal.Commands.WindowHandlers.default_char_width_px()

    char_height_px =
      Raxol.Terminal.Commands.WindowHandlers.default_char_height_px()

    expected_pixel_width = expected_width * char_width_px
    expected_pixel_height = expected_height * char_height_px

    assert emulator.window_state.size_pixels ==
             {expected_pixel_width, expected_pixel_height}
  end
end
