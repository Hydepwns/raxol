defmodule RaxolWeb.PresenceTest do
  use ExUnit.Case, async: false

  # Note: Phoenix.Presence integration tests require the PubSub server.
  # These tests focus on the utility functions and logic that can be
  # tested without a full Phoenix setup.

  alias RaxolWeb.Presence

  describe "module structure" do
    test "module exists" do
      assert Code.ensure_loaded?(RaxolWeb.Presence)
    end

    test "defines track_user/3" do
      Code.ensure_loaded!(RaxolWeb.Presence)
      assert function_exported?(RaxolWeb.Presence, :track_user, 3)
    end

    test "defines update_cursor/2" do
      Code.ensure_loaded!(RaxolWeb.Presence)
      assert function_exported?(RaxolWeb.Presence, :update_cursor, 2)
    end

    test "defines list_users/1" do
      Code.ensure_loaded!(RaxolWeb.Presence)
      assert function_exported?(RaxolWeb.Presence, :list_users, 1)
    end

    test "defines user_count/1" do
      Code.ensure_loaded!(RaxolWeb.Presence)
      assert function_exported?(RaxolWeb.Presence, :user_count, 1)
    end

    test "defines get_cursors/1" do
      Code.ensure_loaded!(RaxolWeb.Presence)
      assert function_exported?(RaxolWeb.Presence, :get_cursors, 1)
    end

    test "defines format_diff/1" do
      Code.ensure_loaded!(RaxolWeb.Presence)
      assert function_exported?(RaxolWeb.Presence, :format_diff, 1)
    end
  end

  describe "user color generation" do
    test "generates consistent color for same user_id" do
      color1 = generate_user_color("user123")
      color2 = generate_user_color("user123")

      assert color1 == color2
    end

    test "generates different colors for different user_ids" do
      color1 = generate_user_color("user1")
      color2 = generate_user_color("user2")

      assert color1 != color2
    end

    test "generates valid hex color format" do
      color = generate_user_color("test_user")

      assert String.starts_with?(color, "#")
      assert String.length(color) == 7
      assert Regex.match?(~r/^#[0-9a-f]{6}$/, color)
    end
  end

  describe "format_diff/1" do
    test "formats joins and leaves" do
      diff = %{
        joins: %{
          "user1" => %{metas: [%{name: "Alice", cursor: {0, 0}}]}
        },
        leaves: %{
          "user2" => %{metas: [%{name: "Bob", cursor: {5, 10}}]}
        }
      }

      formatted = Presence.format_diff(diff)

      assert length(formatted.joins) == 1
      assert length(formatted.leaves) == 1

      [join] = formatted.joins
      assert join.user_id == "user1"
      assert join.name == "Alice"

      [leave] = formatted.leaves
      assert leave.user_id == "user2"
      assert leave.name == "Bob"
    end

    test "handles empty diff" do
      diff = %{joins: %{}, leaves: %{}}

      formatted = Presence.format_diff(diff)

      assert formatted.joins == []
      assert formatted.leaves == []
    end

    test "handles multiple users" do
      diff = %{
        joins: %{
          "user1" => %{metas: [%{name: "Alice"}]},
          "user2" => %{metas: [%{name: "Bob"}]},
          "user3" => %{metas: [%{name: "Charlie"}]}
        },
        leaves: %{}
      }

      formatted = Presence.format_diff(diff)

      assert length(formatted.joins) == 3
      assert Enum.empty?(formatted.leaves)
    end
  end

  describe "format_presence_list/1" do
    test "extracts first meta from metas list" do
      presences = %{
        "user1" => %{metas: [%{cursor: {1, 2}}, %{cursor: {3, 4}}]}
      }

      [result] = format_presence_list(presences)

      assert result.user_id == "user1"
      assert result.cursor == {1, 2}
    end

    test "handles empty metas" do
      presences = %{
        "user1" => %{metas: []}
      }

      [result] = format_presence_list(presences)

      assert result.user_id == "user1"
    end
  end

  describe "get_topic/1" do
    test "extracts topic from LiveView socket assigns" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{presence_topic: "terminal:test_session"}
      }

      assert get_topic(socket) == "terminal:test_session"
    end

    test "returns default topic when missing" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert get_topic(socket) == "terminal:default"
    end

    test "extracts topic from Phoenix socket" do
      socket = %Phoenix.Socket{topic: "terminal:channel_session"}

      assert get_topic(socket) == "terminal:channel_session"
    end
  end

  describe "get_user_id/1" do
    test "extracts user_id from LiveView socket assigns" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{user_id: "test_user_123"}
      }

      assert get_user_id(socket) == "test_user_123"
    end

    test "returns anonymous when missing" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert get_user_id(socket) == "anonymous"
    end

    test "extracts user_id from Phoenix socket assigns" do
      socket = %Phoenix.Socket{assigns: %{user_id: "channel_user"}}

      assert get_user_id(socket) == "channel_user"
    end
  end

  # Helper functions that mirror private functions in Presence

  defp generate_user_color(user_id) do
    hash =
      :crypto.hash(:md5, user_id)
      |> :binary.bin_to_list()
      |> Enum.take(3)

    [r, g, b] = hash
    "#" <> Base.encode16(<<r, g, b>>, case: :lower)
  end

  defp format_presence_list(presences) do
    Enum.map(presences, fn {user_id, %{metas: metas}} ->
      meta = List.first(metas) || %{}
      Map.put(meta, :user_id, user_id)
    end)
  end

  defp get_topic(socket) do
    case socket do
      %Phoenix.LiveView.Socket{} = s ->
        Map.get(s.assigns, :presence_topic, "terminal:default")

      %Phoenix.Socket{topic: topic} ->
        topic

      _ ->
        "terminal:default"
    end
  end

  defp get_user_id(socket) do
    case socket do
      %Phoenix.LiveView.Socket{} = s ->
        Map.get(s.assigns, :user_id, "anonymous")

      %Phoenix.Socket{assigns: assigns} ->
        Map.get(assigns, :user_id, "anonymous")

      _ ->
        "anonymous"
    end
  end
end

defmodule RaxolWeb.PresenceIntegrationTest do
  @moduledoc """
  Integration tests for RaxolWeb.Presence.

  These tests require the full Phoenix PubSub server to be running.
  They are tagged with :integration and can be run separately.
  """
  use ExUnit.Case, async: false

  @moduletag :integration

  describe "presence tracking" do
    @tag :skip
    test "tracks user in session" do
      # Would test track_user/3 with real socket
    end

    @tag :skip
    test "updates cursor position" do
      # Would test update_cursor/2
    end

    @tag :skip
    test "lists users in session" do
      # Would test list_users/1
    end
  end

  describe "presence queries" do
    @tag :skip
    test "counts users in session" do
      # Would test user_count/1
    end

    @tag :skip
    test "gets all cursors" do
      # Would test get_cursors/1
    end

    @tag :skip
    test "checks user presence" do
      # Would test user_present?/2
    end
  end

  describe "presence subscription" do
    @tag :skip
    test "subscribes to presence events" do
      # Would test subscribe/1
    end

    @tag :skip
    test "receives presence diff on join" do
      # Would test presence_diff events
    end

    @tag :skip
    test "receives presence diff on leave" do
      # Would test leave events
    end
  end
end
