defmodule Raxol.Payments.HeadersTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.Headers

  describe "flatten/1" do
    test "converts map of lists to flat list of tuples" do
      headers = %{
        "x-token" => ["abc", "def"],
        "content-type" => ["application/json"]
      }

      result = Headers.flatten(headers)

      assert {"x-token", "abc"} in result
      assert {"x-token", "def"} in result
      assert {"content-type", "application/json"} in result
      assert length(result) == 3
    end

    test "converts map of single values to list of tuples" do
      headers = %{"authorization" => "Bearer tok123", "accept" => "text/plain"}

      result = Headers.flatten(headers)

      assert {"authorization", "Bearer tok123"} in result
      assert {"accept", "text/plain"} in result
      assert length(result) == 2
    end

    test "passes through an already-flat list unchanged" do
      headers = [{"content-type", "application/json"}, {"x-req-id", "42"}]

      assert Headers.flatten(headers) == headers
    end

    test "handles empty map" do
      assert Headers.flatten(%{}) == []
    end

    test "handles empty list" do
      assert Headers.flatten([]) == []
    end
  end

  describe "find/2" do
    test "returns value for exact case match" do
      headers = [{"Content-Type", "application/json"}]

      assert Headers.find(headers, "Content-Type") == "application/json"
    end

    test "returns value for case-insensitive match" do
      headers = [{"Content-Type", "application/json"}]

      assert Headers.find(headers, "content-type") == "application/json"
      assert Headers.find(headers, "CONTENT-TYPE") == "application/json"
    end

    test "returns nil for missing header" do
      headers = [{"content-type", "application/json"}]

      assert Headers.find(headers, "authorization") == nil
    end

    test "returns nil for empty list" do
      assert Headers.find([], "anything") == nil
    end

    test "skips malformed tuples with non-binary key" do
      headers = [{:atom_key, "value"}, {"content-type", "application/json"}]

      assert Headers.find(headers, "content-type") == "application/json"
      assert Headers.find(headers, "atom_key") == nil
    end

    test "skips malformed tuples with non-binary value" do
      headers = [{"x-count", 42}, {"content-type", "application/json"}]

      assert Headers.find(headers, "x-count") == nil
      assert Headers.find(headers, "content-type") == "application/json"
    end

    test "returns first matching value when duplicates exist" do
      headers = [{"x-token", "first"}, {"X-Token", "second"}]

      assert Headers.find(headers, "x-token") == "first"
    end
  end

  describe "require/2" do
    test "returns {:ok, value} for present header" do
      headers = [{"authorization", "Bearer tok"}]

      assert Headers.require(headers, "authorization") == {:ok, "Bearer tok"}
    end

    test "returns {:error, {:missing_header, name}} for missing header" do
      headers = [{"content-type", "application/json"}]

      assert Headers.require(headers, "authorization") ==
               {:error, {:missing_header, "authorization"}}
    end

    test "is case-insensitive" do
      headers = [{"X-Request-Id", "abc123"}]

      assert Headers.require(headers, "x-request-id") == {:ok, "abc123"}
    end

    test "returns error for empty headers" do
      assert Headers.require([], "x-missing") == {:error, {:missing_header, "x-missing"}}
    end
  end
end
