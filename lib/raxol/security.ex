defmodule Raxol.Security do
  @moduledoc """
  Top-level security API for Raxol.

  Provides convenient access to security functions including input validation,
  command validation, path validation, HTML escaping, and CSRF protection.

  ## Example

      # Sanitize user input
      safe_input = Raxol.Security.sanitize_input(user_input)

      # Validate a command
      {:ok, safe_cmd} = Raxol.Security.validate_command(cmd)

      # Validate a file path
      {:ok, safe_path} = Raxol.Security.validate_path(path)
  """

  alias Raxol.Security.Auditor
  alias Raxol.Security.InputValidator

  # Dangerous command patterns
  @dangerous_commands ~w(rm rmdir del format fdisk mkfs dd shutdown reboot halt poweroff)
  @dangerous_flags ~w(-rf -fr --no-preserve-root --force)
  @traversal_patterns ["../", "..\\", "%2e%2e/", "%2e%2e\\"]

  @doc """
  Sanitize user input by removing potentially dangerous characters.

  ## Example

      safe = Raxol.Security.sanitize_input("<script>alert('xss')</script>")
      # => "&lt;script&gt;alert('xss')&lt;/script&gt;"
  """
  @spec sanitize_input(String.t()) :: String.t()
  def sanitize_input(input) when is_binary(input) do
    escape_html(input)
  end

  def sanitize_input(input), do: to_string(input)

  @doc """
  Validate a shell command for safety.

  Returns `{:ok, command}` if safe, `{:error, :unsafe}` if potentially dangerous.

  ## Example

      {:ok, "ls -la"} = Raxol.Security.validate_command("ls -la")
      {:error, :unsafe} = Raxol.Security.validate_command("rm -rf /")
  """
  @spec validate_command(String.t()) :: {:ok, String.t()} | {:error, :unsafe}
  def validate_command(command) when is_binary(command) do
    parts = String.split(command, ~r/\s+/)
    base_command = List.first(parts) || ""
    base_name = Path.basename(base_command)

    cond do
      base_name in @dangerous_commands ->
        {:error, :unsafe}

      Enum.any?(parts, &(&1 in @dangerous_flags)) ->
        {:error, :unsafe}

      String.contains?(command, [";", "&&", "||", "|", "`", "$(", "${"]) ->
        {:error, :unsafe}

      true ->
        {:ok, command}
    end
  end

  def validate_command(_), do: {:error, :unsafe}

  @doc """
  Validate a file path to prevent directory traversal attacks.

  Returns `{:ok, path}` if safe, `{:error, :traversal}` if contains traversal patterns.

  ## Example

      {:ok, "/home/user/file.txt"} = Raxol.Security.validate_path("/home/user/file.txt")
      {:error, :traversal} = Raxol.Security.validate_path("../../../etc/passwd")
  """
  @spec validate_path(String.t()) :: {:ok, String.t()} | {:error, :traversal}
  def validate_path(path) when is_binary(path) do
    normalized = Path.expand(path)

    cond do
      Enum.any?(@traversal_patterns, &String.contains?(path, &1)) ->
        {:error, :traversal}

      String.contains?(normalized, "..") ->
        {:error, :traversal}

      true ->
        {:ok, path}
    end
  end

  def validate_path(_), do: {:error, :traversal}

  @doc """
  Validate input against a schema.

  ## Example

      schema = [
        %{name: :username, rules: [{:type, :string}, {:min_length, 3}]},
        %{name: :email, rules: [{:type, :string}, {:format, ~r/@/}]}
      ]

      case Raxol.Security.validate(input, schema) do
        {:ok, validated} -> use_validated(validated)
        {:error, errors} -> handle_errors(errors)
      end
  """
  @spec validate(map(), list()) :: {:ok, map()} | {:error, list()}
  def validate(input, schema) when is_map(input) and is_list(schema) do
    InputValidator.validate_inputs(input, schema)
  end

  @doc """
  Escape HTML entities to prevent XSS attacks.

  ## Example

      safe_html = Raxol.Security.escape_html("<script>alert('xss')</script>")
      # => "&lt;script&gt;alert('xss')&lt;/script&gt;"
  """
  @spec escape_html(String.t()) :: String.t()
  def escape_html(html) when is_binary(html) do
    html
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  def escape_html(value), do: to_string(value)

  @doc """
  Generate a CSRF token for form protection.

  ## Example

      token = Raxol.Security.generate_csrf_token()
      # => "a1b2c3d4e5f6..."
  """
  @spec generate_csrf_token() :: String.t()
  def generate_csrf_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Verify a CSRF token matches the expected value.

  Uses constant-time comparison to prevent timing attacks.

  ## Example

      Raxol.Security.verify_csrf_token(expected, provided)
      # => true | false
  """
  @spec verify_csrf_token(String.t(), String.t()) :: boolean()
  def verify_csrf_token(expected, provided)
      when is_binary(expected) and is_binary(provided) do
    secure_compare(expected, provided)
  end

  def verify_csrf_token(_, _), do: false

  @doc """
  Check rate limiting for an identifier and action.

  ## Options

    - `:limit` - Maximum requests allowed (default: 100)
    - `:window` - Time window in milliseconds (default: 60_000)

  ## Example

      case Raxol.Security.check_rate_limit(user_id, :api_call) do
        {:ok, remaining} -> proceed()
        {:error, :rate_limited} -> reject()
      end
  """
  @spec check_rate_limit(String.t(), atom(), keyword()) ::
          {:ok, :allowed} | {:error, :medium, String.t()}
  def check_rate_limit(identifier, action, opts \\ []) do
    Auditor.check_rate_limit(identifier, action, opts)
  end

  @doc """
  Validate and sanitize input with type checking.

  ## Example

      {:ok, safe_input} = Raxol.Security.validate_input(user_input, :text)
  """
  @spec validate_input(String.t(), atom(), keyword()) ::
          {:ok, String.t()} | {:error, atom(), String.t()}
  def validate_input(input, type, opts \\ []) do
    Auditor.validate_input(input, type, opts)
  end

  # Private functions

  defp secure_compare(a, b) when byte_size(a) != byte_size(b), do: false

  defp secure_compare(a, b) do
    a_bytes = :binary.bin_to_list(a)
    b_bytes = :binary.bin_to_list(b)

    result =
      a_bytes
      |> Enum.zip(b_bytes)
      |> Enum.reduce(0, fn {x, y}, acc ->
        Bitwise.bor(acc, Bitwise.bxor(x, y))
      end)

    result == 0
  end
end
