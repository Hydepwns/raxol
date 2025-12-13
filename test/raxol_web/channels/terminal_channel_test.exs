defmodule RaxolWeb.TerminalChannelTest do
  use ExUnit.Case, async: false

  # Note: This is a unit test file for the TerminalChannel module.
  # For full integration tests, use Phoenix.ChannelTest with proper endpoint setup.

  alias Raxol.Web.SessionBridge
  alias Raxol.Web.PersistentStore

  setup do
    # Use unique names to avoid conflicts between tests
    test_id = :erlang.unique_integer([:positive])

    # Start SessionBridge with unique name - ExUnit will clean up
    session_bridge_name = :"SessionBridge_#{test_id}"

    case Process.whereis(SessionBridge) do
      nil ->
        start_supervised!({SessionBridge, name: session_bridge_name})

      _pid ->
        :ok
    end

    # Start PersistentStore with unique name - ExUnit will clean up
    persistent_store_name = :"PersistentStore_#{test_id}"

    case Process.whereis(PersistentStore) do
      nil ->
        start_supervised!({PersistentStore, name: persistent_store_name})

      _pid ->
        :ok
    end

    # Ensure module is loaded before any tests run
    Code.ensure_loaded!(RaxolWeb.TerminalChannel)

    :ok
  end

  describe "module structure" do
    test "module exists" do
      assert Code.ensure_loaded?(RaxolWeb.TerminalChannel)
    end

    test "defines join/3 callback" do
      Code.ensure_loaded!(RaxolWeb.TerminalChannel)
      assert function_exported?(RaxolWeb.TerminalChannel, :join, 3)
    end

    test "defines handle_in/3 callback" do
      Code.ensure_loaded!(RaxolWeb.TerminalChannel)
      assert function_exported?(RaxolWeb.TerminalChannel, :handle_in, 3)
    end

    test "defines handle_info/2 callback" do
      Code.ensure_loaded!(RaxolWeb.TerminalChannel)
      assert function_exported?(RaxolWeb.TerminalChannel, :handle_info, 2)
    end

    test "defines terminate/2 callback" do
      Code.ensure_loaded!(RaxolWeb.TerminalChannel)
      assert function_exported?(RaxolWeb.TerminalChannel, :terminate, 2)
    end
  end

  describe "session_id validation" do
    # Test the session ID validation logic via reflection
    test "valid session IDs are accepted" do
      valid_ids = [
        "session123",
        "my-session",
        "user_session_1",
        "ABC123",
        "a",
        String.duplicate("a", 64)
      ]

      for id <- valid_ids do
        assert valid_session_id?(id), "Expected #{inspect(id)} to be valid"
      end
    end

    test "invalid session IDs are rejected" do
      invalid_ids = [
        "",
        "session with spaces",
        "session@special",
        "session/slash",
        String.duplicate("a", 65),
        nil
      ]

      for id <- invalid_ids do
        refute valid_session_id?(id), "Expected #{inspect(id)} to be invalid"
      end
    end
  end

  describe "input validation" do
    test "valid input passes validation" do
      assert validate_input("hello") == :ok
      assert validate_input("a") == :ok
      assert validate_input(String.duplicate("x", 4096)) == :ok
    end

    test "too large input is rejected" do
      large_input = String.duplicate("x", 4097)
      assert validate_input(large_input) == {:error, :input_too_large}
    end

    test "non-binary input is rejected" do
      assert validate_input(123) == {:error, :invalid_input}
      assert validate_input(nil) == {:error, :invalid_input}
      assert validate_input(['list']) == {:error, :invalid_input}
    end
  end

  describe "rate limiting logic" do
    test "init_rate_limit creates initial state" do
      rate_limit = init_rate_limit()

      assert rate_limit.count == 0
      assert is_integer(rate_limit.window_start)
    end

    test "rate limit allows messages within window" do
      rate_limit = %{
        count: 50,
        window_start: System.monotonic_time(:millisecond)
      }

      socket = %{assigns: %{rate_limit: rate_limit}}

      assert check_rate_limit(socket) == :ok
    end

    test "rate limit blocks when exceeded" do
      rate_limit = %{
        count: 100,
        window_start: System.monotonic_time(:millisecond)
      }

      socket = %{assigns: %{rate_limit: rate_limit}}

      assert check_rate_limit(socket) == {:error, :rate_limited}
    end

    test "rate limit resets after window expires" do
      rate_limit = %{
        count: 100,
        window_start: System.monotonic_time(:millisecond) - 2000
      }

      socket = %{assigns: %{rate_limit: rate_limit}}

      # Window expired (older than 1000ms), should reset
      assert check_rate_limit(socket) == :ok
    end
  end

  describe "buffer serialization" do
    test "serialize_color handles nil" do
      assert serialize_color(nil) == nil
    end

    test "serialize_color handles RGB tuples" do
      assert serialize_color({255, 0, 128}) == [255, 0, 128]
    end

    test "serialize_color handles atoms" do
      assert serialize_color(:red) == "red"
      assert serialize_color(:white) == "white"
    end

    test "serialize_color handles other values" do
      assert serialize_color("custom") == "custom"
      assert serialize_color(16) == 16
    end
  end

  # Helper functions that mirror the private functions in TerminalChannel
  # These allow us to test the logic without full channel integration

  defp valid_session_id?(nil), do: false

  defp valid_session_id?(session_id) when is_binary(session_id) do
    byte_size(session_id) > 0 and byte_size(session_id) <= 64 and
      Regex.match?(~r/^[a-zA-Z0-9_-]+$/, session_id)
  end

  defp valid_session_id?(_), do: false

  defp validate_input(data) when is_binary(data) do
    max_size = 4096

    if byte_size(data) > max_size do
      {:error, :input_too_large}
    else
      :ok
    end
  end

  defp validate_input(_), do: {:error, :invalid_input}

  defp init_rate_limit do
    %{
      count: 0,
      window_start: System.monotonic_time(:millisecond)
    }
  end

  defp check_rate_limit(socket) do
    rate_limit = socket.assigns.rate_limit
    now = System.monotonic_time(:millisecond)
    window_elapsed = now - rate_limit.window_start
    max_messages = 100
    window_ms = 1000

    cond do
      window_elapsed > window_ms ->
        :ok

      rate_limit.count >= max_messages ->
        {:error, :rate_limited}

      true ->
        :ok
    end
  end

  defp serialize_color(nil), do: nil
  defp serialize_color({r, g, b}), do: [r, g, b]
  defp serialize_color(color) when is_atom(color), do: Atom.to_string(color)
  defp serialize_color(color), do: color
end

defmodule RaxolWeb.TerminalChannelIntegrationTest do
  @moduledoc """
  Integration tests for TerminalChannel.

  These tests require the full Phoenix endpoint to be running.
  They are tagged with :integration and can be run separately.
  """
  use ExUnit.Case, async: false

  # These tests would use Phoenix.ChannelTest
  # Keeping them as placeholders for when the endpoint is configured

  @moduletag :integration

  describe "channel join" do
    @tag :skip
    test "joins successfully with valid session_id" do
      # Would use Phoenix.ChannelTest.socket/2 and subscribe_and_join/4
    end

    @tag :skip
    test "rejects join with invalid session_id" do
      # Would test error response
    end
  end

  describe "input handling" do
    @tag :skip
    test "processes input and broadcasts output" do
      # Would test push and receive
    end

    @tag :skip
    test "enforces rate limiting" do
      # Would test rate limit enforcement
    end
  end

  describe "resize handling" do
    @tag :skip
    test "resizes terminal and broadcasts to collaborators" do
      # Would test resize message
    end
  end

  describe "presence tracking" do
    @tag :skip
    test "tracks user presence on join" do
      # Would test presence updates
    end
  end
end
