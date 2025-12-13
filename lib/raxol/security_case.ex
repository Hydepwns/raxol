defmodule Raxol.SecurityCase do
  @moduledoc """
  Test case helper for security-related tests.

  Provides helper functions for testing security controls, input validation,
  and vulnerability prevention.

  ## Example

      defmodule SecurityTest do
        use Raxol.SecurityCase

        test "prevents XSS attacks" do
          assert_xss_safe("<script>alert('xss')</script>")
        end

        test "validates input correctly" do
          assert_input_valid("normal input", :text)
          assert_input_invalid("<script>", :text)
        end
      end
  """

  use ExUnit.CaseTemplate

  alias Raxol.Security

  using do
    quote do
      import Raxol.SecurityCase
    end
  end

  setup _tags do
    {:ok, %{}}
  end

  @doc """
  Assert that input is properly sanitized against XSS attacks.
  """
  def assert_xss_safe(input) do
    sanitized = Security.escape_html(input)

    dangerous_patterns = [
      "<script",
      "javascript:",
      "onerror=",
      "onclick=",
      "onload="
    ]

    Enum.each(dangerous_patterns, fn pattern ->
      if String.contains?(String.downcase(sanitized), pattern) do
        raise ExUnit.AssertionError,
          message: "XSS pattern '#{pattern}' found in sanitized output"
      end
    end)

    :ok
  end

  @doc """
  Assert that a command is considered safe.
  """
  def assert_command_safe(command) do
    case Security.validate_command(command) do
      {:ok, _} ->
        :ok

      {:error, :unsafe} ->
        raise ExUnit.AssertionError,
          message:
            "Expected command '#{command}' to be safe, but it was rejected"
    end
  end

  @doc """
  Assert that a command is considered unsafe.
  """
  def assert_command_unsafe(command) do
    case Security.validate_command(command) do
      {:error, :unsafe} ->
        :ok

      {:ok, _} ->
        raise ExUnit.AssertionError,
          message:
            "Expected command '#{command}' to be unsafe, but it was accepted"
    end
  end

  @doc """
  Assert that a path is safe (no directory traversal).
  """
  def assert_path_safe(path) do
    case Security.validate_path(path) do
      {:ok, _} ->
        :ok

      {:error, :traversal} ->
        raise ExUnit.AssertionError,
          message:
            "Expected path '#{path}' to be safe, but traversal was detected"
    end
  end

  @doc """
  Assert that a path contains directory traversal.
  """
  def assert_path_traversal(path) do
    case Security.validate_path(path) do
      {:error, :traversal} ->
        :ok

      {:ok, _} ->
        raise ExUnit.AssertionError,
          message:
            "Expected path '#{path}' to have traversal, but it was accepted"
    end
  end

  @doc """
  Assert that input passes validation.
  """
  def assert_input_valid(input, type, opts \\ []) do
    case Security.validate_input(input, type, opts) do
      {:ok, _} ->
        :ok

      {:error, _, reason} ->
        raise ExUnit.AssertionError,
          message: "Expected input to be valid, but got error: #{reason}"
    end
  end

  @doc """
  Assert that input fails validation.
  """
  def assert_input_invalid(input, type, opts \\ []) do
    case Security.validate_input(input, type, opts) do
      {:error, _, _} ->
        :ok

      {:ok, _} ->
        raise ExUnit.AssertionError,
          message: "Expected input to be invalid, but it passed validation"
    end
  end

  @doc """
  Assert that CSRF tokens match.
  """
  def assert_csrf_valid(expected, provided) do
    if Security.verify_csrf_token(expected, provided) do
      :ok
    else
      raise ExUnit.AssertionError, message: "CSRF token verification failed"
    end
  end

  @doc """
  Assert that rate limiting is triggered.
  """
  def assert_rate_limited(identifier, action, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    # Exhaust the rate limit
    for _ <- 1..limit do
      _ = Security.check_rate_limit(identifier, action, opts)
    end

    # Next call should be limited
    case Security.check_rate_limit(identifier, action, opts) do
      {:error, :medium, _message} ->
        :ok

      {:ok, _} ->
        raise ExUnit.AssertionError,
          message:
            "Expected rate limiting to be triggered after #{limit} requests"
    end
  end

  @doc """
  Generate test payloads for security testing.
  """
  def security_payloads(type) do
    case type do
      :xss ->
        [
          "<script>alert('xss')</script>",
          "<img src=x onerror=alert('xss')>",
          "javascript:alert('xss')",
          "<svg onload=alert('xss')>",
          "<<script>alert('xss')</script>",
          "<body onload=alert('xss')>"
        ]

      :sql_injection ->
        [
          "'; DROP TABLE users; --",
          "1 OR 1=1",
          "' UNION SELECT * FROM users --",
          "1; DELETE FROM users",
          "' OR ''='"
        ]

      :path_traversal ->
        [
          "../../../etc/passwd",
          "..\\..\\..\\windows\\system32",
          "%2e%2e%2f%2e%2e%2f",
          "....//....//",
          "/etc/passwd%00"
        ]

      :command_injection ->
        [
          "; rm -rf /",
          "| cat /etc/passwd",
          "$(whoami)",
          "`id`",
          "&& cat /etc/shadow"
        ]

      _ ->
        []
    end
  end
end
