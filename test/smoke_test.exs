defmodule SmokeTest do
  use ExUnit.Case

  test "basic arithmetic" do
    assert 1 + 1 == 2
  end

  test "string operations" do
    assert "hello" <> " world" == "hello world"
  end

  test "list operations" do
    assert [1, 2, 3] ++ [4, 5] == [1, 2, 3, 4, 5]
  end
end
