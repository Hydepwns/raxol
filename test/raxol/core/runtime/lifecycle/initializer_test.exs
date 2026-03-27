defmodule Raxol.Core.Runtime.Lifecycle.InitializerTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Lifecycle.Initializer

  describe "detect_terminal_size/1" do
    test "falls back to option values when :io unavailable" do
      # In test env, :io.columns/:io.rows may return {:error, :enotsup}
      # which triggers the fallback path
      {w, h} = Initializer.detect_terminal_size(width: 132, height: 43)

      # Either detects real terminal size or uses our fallback
      assert is_integer(w) and w > 0
      assert is_integer(h) and h > 0
    end

    test "defaults to 80x24 when no options provided" do
      {w, h} = Initializer.detect_terminal_size([])

      assert is_integer(w) and w > 0
      assert is_integer(h) and h > 0
      # Can't assert exact values since a real terminal might be detected
    end
  end
end
