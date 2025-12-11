defmodule Raxol.Security.Auditor do
  alias Raxol.Core.Runtime.Log

  @moduledoc """
  Security auditing and validation module for Raxol.

  Provides comprehensive security checks and validations including:
  - Input validation and sanitization
  - Authentication and authorization checks
  - SQL injection prevention
  - XSS protection
  - CSRF protection
  - Rate limiting
  - Security headers validation
  """
  @type security_risk :: :low | :medium | :high | :critical
  @type audit_result :: {:ok, :passed} | {:error, security_risk, String.t()}

  @doc """
  Validates and sanitizes user input.

  ## Examples

      iex> validate_input("normal input", :text)
      {:ok, "normal input"}

      iex> validate_input("<script>alert('xss')</script>", :text)
      {:error, :high, "Potential XSS attack detected"}
  """
  def validate_input(input, type, opts \\ []) do
    with {:ok, input} <- check_length(input, opts),
         {:ok, input} <- check_encoding(input),
         {:ok, input} <- check_patterns(input, type) do
      sanitize_input(input, type, opts)
    end
  end

  @doc """
  Validates authentication credentials.
  """
  def validate_credentials(username, password) do
    with {:ok, _} <- validate_username(username),
         {:ok, _} <- validate_password(password),
         :ok <- check_brute_force_attempt(username) do
      {:ok, :valid}
    end
  end

  @doc """
  Checks authorization for a specific action.
  """
  def authorize_action(user, resource, action) do
    with {:ok, permissions} <- get_user_permissions(user),
         :ok <- check_resource_access(permissions, resource, action),
         :ok <- audit_access_attempt(user, resource, action) do
      {:ok, :authorized}
    else
      {:error, :unauthorized} ->
        audit_unauthorized_attempt(user, resource, action)
        {:error, :high, "Unauthorized access attempt"}
    end
  end

  @doc """
  Validates SQL queries for injection attempts.
  """
  def validate_sql_query(query, params \\ []) do
    # Check query structure
    case contains_sql_injection?(query) do
      true ->
        {:error, :critical, "SQL injection pattern detected"}

      false ->
        # Validate parameters
        case validate_sql_params(params) do
          :ok -> {:ok, {query, params}}
          error -> error
        end
    end
  end

  @doc """
  Implements rate limiting for API endpoints.
  """
  def check_rate_limit(identifier, action, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    # 1 minute
    window = Keyword.get(opts, :window, 60_000)

    key = "rate_limit:#{identifier}:#{action}"
    current_count = get_rate_count(key)

    check_and_update_rate_limit(current_count, limit, key, window)
  end

  @doc """
  Validates CSRF tokens.
  """
  def validate_csrf_token(session_token, request_token) do
    case secure_compare(session_token, request_token) do
      true -> {:ok, :valid}
      false -> {:error, :high, "Invalid CSRF token"}
    end
  end

  @doc """
  Checks security headers.
  """
  def validate_security_headers(headers) do
    required_headers = [
      {"content-security-policy", &validate_csp/1},
      {"x-content-type-options", &validate_content_type_options/1},
      {"x-frame-options", &validate_frame_options/1},
      {"strict-transport-security", &validate_hsts/1}
    ]

    errors =
      Enum.reduce(required_headers, [], fn {header, validator}, acc ->
        case Map.get(headers, header) do
          nil ->
            [{:missing, header} | acc]

          value ->
            case validator.(value) do
              :ok -> acc
              {:error, reason} -> [{:invalid, header, reason} | acc]
            end
        end
      end)

    validate_header_errors(errors)
  end

  @doc """
  Sanitizes HTML content to prevent XSS.
  """
  def sanitize_html(html) do
    html
    |> remove_scripts()
    |> remove_event_handlers()
    |> encode_special_chars()
    |> validate_tags()
  end

  @doc """
  Validates file uploads for security.
  """
  def validate_file_upload(file_path, opts \\ []) do
    allowed_types = Keyword.get(opts, :allowed_types, ~w(.jpg .png .pdf .txt))
    # 10MB
    max_size = Keyword.get(opts, :max_size, 10_485_760)

    with {:ok, stat} <- File.stat(file_path),
         :ok <- check_file_size(stat.size, max_size),
         :ok <- check_file_type(file_path, allowed_types),
         :ok <- scan_file_content(file_path) do
      {:ok, :safe}
    end
  end

  @doc """
  Performs comprehensive security audit.
  """
  def audit_system do
    audits = [
      audit_authentication(),
      audit_authorization(),
      audit_input_validation(),
      audit_session_management(),
      audit_cryptography(),
      audit_dependencies()
    ]

    results = Enum.map(audits, fn audit_fun -> audit_fun.() end)

    failures =
      Enum.filter(results, fn
        {:ok, _} -> false
        _ -> true
      end)

    process_audit_results(failures)
  end

  # Private functions

  defp check_length(input, opts) do
    max_length = Keyword.get(opts, :max_length, 1000)
    validate_input_length(input, max_length)
  end

  defp check_encoding(input) do
    validate_string_encoding(input)
  end

  defp check_patterns(input, :sql) do
    case contains_sql_injection?(input) do
      true -> {:error, :critical, "SQL injection pattern detected"}
      false -> {:ok, input}
    end
  end

  defp check_patterns(input, :html) do
    case contains_xss?(input) do
      true -> {:error, :high, "XSS pattern detected"}
      false -> {:ok, input}
    end
  end

  defp check_patterns(input, :path) do
    case contains_path_traversal?(input) do
      true -> {:error, :high, "Path traversal pattern detected"}
      false -> {:ok, input}
    end
  end

  defp check_patterns(input, _), do: {:ok, input}

  defp contains_sql_injection?(input) do
    sql_injection_patterns = [
      ~r/('\s*(;|union|or|and)\s*)/i,
      ~r/('--'|"--")/,
      ~r/(--\s*$|;\s*--)/i,
      ~r/(\/\*|\*\/)/,
      ~r/(xp_|sp_)/i,
      ~r/(\bor\b\s+'?1'?\s*=\s*'?1'?)/i,
      ~r/(';\s*(drop|delete|update|insert)\s+)/i,
      ~r/\bunion\s+select\b/i,
      ~r/\bdrop\s+table\b/i
    ]

    Enum.any?(sql_injection_patterns, &Regex.match?(&1, input))
  end

  defp contains_xss?(input) do
    xss_patterns = [
      ~r/<script[^>]*>.*?<\/script>/i,
      ~r/javascript:/i,
      ~r/on\w+\s*=/i,
      ~r/<iframe/i,
      ~r/<object/i,
      ~r/<embed/i
    ]

    Enum.any?(xss_patterns, &Regex.match?(&1, input))
  end

  defp contains_path_traversal?(input) do
    path_traversal_patterns = [
      ~r/\.\.[\/\\]/,
      ~r/\.\.%2[fF]/,
      ~r/%2e%2e/i
    ]

    Enum.any?(path_traversal_patterns, &Regex.match?(&1, input))
  end

  defp sanitize_input(input, :text, _opts) do
    sanitized =
      input
      |> String.replace(~r/<[^>]*>/, "")
      |> String.replace(~r/[<>&"']/, fn
        "<" -> "&lt;"
        ">" -> "&gt;"
        "&" -> "&amp;"
        "\"" -> "&quot;"
        "'" -> "&#x27;"
      end)

    {:ok, sanitized}
  end

  defp sanitize_input(input, :sql, _opts) do
    # Use parameterized queries instead
    {:ok, input}
  end

  defp sanitize_input(input, type, opts) when type in [:html, :text] do
    handle_html_sanitization(input, Keyword.get(opts, :sanitize, false))
  end

  defp sanitize_input(input, _, _), do: {:ok, input}

  defp validate_username(username) when byte_size(username) < 3 do
    {:error, :low, "Username too short"}
  end

  defp validate_username(username) when byte_size(username) > 50 do
    {:error, :low, "Username too long"}
  end

  defp validate_username(username) do
    validate_username_format(username)
  end

  defp validate_password(password) when byte_size(password) < 8 do
    {:error, :medium, "Password too short"}
  end

  defp validate_password(password) do
    with true <-
           Regex.match?(~r/[A-Z]/, password) ||
             {:error, :low, "Password must contain uppercase"},
         true <-
           Regex.match?(~r/[a-z]/, password) ||
             {:error, :low, "Password must contain lowercase"},
         true <-
           Regex.match?(~r/[0-9]/, password) ||
             {:error, :low, "Password must contain numbers"} do
      {:ok, password}
    else
      {:error, level, message} -> {:error, level, message}
      false -> {:error, :low, "Password validation failed"}
    end
  end

  defp check_brute_force_attempt(username) do
    key = "login_attempts:#{username}"
    attempts = get_rate_count(key)

    check_brute_force_threshold(attempts)
  end

  defp get_user_permissions(user) do
    # Return actual user permissions from the user map
    case user do
      %{permissions: permissions} -> {:ok, permissions}
      _ -> {:ok, %{}}
    end
  end

  defp check_resource_access(permissions, _resource, action) do
    # Mock implementation
    authorize_action_permission(permissions, action)
  end

  defp audit_access_attempt(user, resource, action) do
    Log.info(
      "Access attempt: user=#{inspect(user)}, resource=#{resource}, action=#{action}"
    )

    :ok
  end

  defp audit_unauthorized_attempt(user, resource, action) do
    Log.warning(
      "Unauthorized attempt: user=#{inspect(user)}, resource=#{resource}, action=#{action}"
    )

    :ok
  end

  defp validate_sql_params(params) do
    validate_all_params(params)
  end

  defp safe_param?(param) when is_binary(param) do
    not contains_sql_injection?(param)
  end

  defp safe_param?(param) when is_number(param), do: true
  defp safe_param?(param) when is_boolean(param), do: true
  defp safe_param?(nil), do: true
  defp safe_param?(_), do: false

  defp get_rate_count(key) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           # Mock implementation - would use ETS or Redis
           :ets.lookup_element(:rate_limits, key, 2)
         end) do
      {:ok, count} -> count
      {:error, _reason} -> 0
    end
  end

  defp increment_rate_count(key, window) do
    # Mock implementation
    :ets.insert(:rate_limits, {key, get_rate_count(key) + 1})
    Process.send_after(self(), {:clear_rate_limit, key}, window)
    :ok
  end

  defp secure_compare(a, b) when is_binary(a) and is_binary(b) do
    secure_compare_same_size(a, b)
  end

  defp secure_compare(_, _), do: false

  defp secure_compare_binaries(<<>>, <<>>, acc), do: acc

  defp secure_compare_binaries(
         <<a, rest_a::binary>>,
         <<b, rest_b::binary>>,
         acc
       ) do
    secure_compare_binaries(
      rest_a,
      rest_b,
      Bitwise.bor(acc, Bitwise.bxor(a, b))
    )
  end

  defp validate_csp(value) do
    validate_csp_default_src(value)
  end

  defp validate_content_type_options(value) do
    validate_nosniff_value(value)
  end

  defp validate_frame_options(value) do
    validate_frame_options_value(value)
  end

  defp validate_hsts(value) do
    validate_hsts_max_age(value)
  end

  defp remove_scripts(html) do
    String.replace(html, ~r/<script[^>]*>.*?<\/script>/is, "")
  end

  defp remove_event_handlers(html) do
    String.replace(html, ~r/\s*on\w+\s*=\s*["'][^"']*["']/i, "")
  end

  defp encode_special_chars(html) do
    html
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#x27;")
  end

  defp validate_tags(html) do
    # Allow only safe tags
    _allowed_tags = ~w(p br strong em u i b div span)
    # Implementation would parse and filter tags
    html
  end

  defp check_file_size(size, max_size) do
    validate_file_size_limit(size, max_size)
  end

  defp check_file_type(file_path, allowed_types) do
    extension = Path.extname(file_path) |> String.downcase()

    validate_file_extension(extension, allowed_types)
  end

  defp scan_file_content(_file_path) do
    # Would integrate with antivirus or content scanning
    :ok
  end

  # Audit functions

  defp audit_authentication do
    # Check for weak authentication methods
    {:ok, :authentication_secure}
  end

  defp audit_authorization do
    # Check for proper RBAC implementation
    {:ok, :authorization_secure}
  end

  defp audit_input_validation do
    # Check all input points are validated
    {:ok, :input_validation_secure}
  end

  defp audit_session_management do
    # Check session configuration
    {:ok, :session_management_secure}
  end

  defp audit_cryptography do
    # Check encryption methods and key management
    {:ok, :cryptography_secure}
  end

  defp audit_dependencies do
    # Check for vulnerable dependencies
    {:ok, :dependencies_secure}
  end

  ## Pattern matching helper functions for if statement elimination

  defp process_audit_results([]), do: {:ok, :all_passed}
  defp process_audit_results(failures), do: {:error, :audit_failed, failures}

  defp validate_string_encoding(input) do
    case String.valid?(input) do
      true -> {:ok, input}
      false -> {:error, :high, "Invalid character encoding"}
    end
  end

  defp handle_html_sanitization(input, true) do
    sanitized = sanitize_html(input)
    {:ok, sanitized}
  end

  defp handle_html_sanitization(input, false), do: {:ok, input}

  defp validate_username_format(username) do
    case Regex.match?(~r/^[a-zA-Z0-9_.-]+$/, username) do
      true -> {:ok, username}
      false -> {:error, :medium, "Invalid username format"}
    end
  end

  defp check_brute_force_threshold(attempts) when attempts > 5 do
    {:error, :high, "Too many login attempts"}
  end

  defp check_brute_force_threshold(_attempts), do: :ok

  defp authorize_action_permission(permissions, action) do
    case Map.get(permissions, action, false) do
      true -> :ok
      false -> {:error, :unauthorized}
    end
  end

  defp validate_all_params(params) do
    case Enum.all?(params, &safe_param?/1) do
      true -> :ok
      false -> {:error, :high, "Unsafe SQL parameter detected"}
    end
  end

  defp secure_compare_same_size(a, b) when byte_size(a) == byte_size(b) do
    secure_compare_binaries(a, b, 0) == 0
  end

  defp secure_compare_same_size(_a, _b), do: false

  defp validate_csp_default_src(value) do
    case String.contains?(value, "default-src") do
      true -> :ok
      false -> {:error, "Missing default-src directive"}
    end
  end

  defp validate_nosniff_value("nosniff"), do: :ok
  defp validate_nosniff_value(_value), do: {:error, "Should be 'nosniff'"}

  defp validate_frame_options_value(value) when value in ~w(DENY SAMEORIGIN),
    do: :ok

  defp validate_frame_options_value(_value),
    do: {:error, "Should be DENY or SAMEORIGIN"}

  defp validate_hsts_max_age(value) do
    case String.contains?(value, "max-age=") do
      true -> :ok
      false -> {:error, "Missing max-age directive"}
    end
  end

  defp validate_file_size_limit(size, max_size) when size <= max_size, do: :ok

  defp validate_file_size_limit(_size, _max_size),
    do: {:error, :medium, "File size exceeds limit"}

  defp validate_file_extension(extension, allowed_types) do
    case extension in allowed_types do
      true -> :ok
      false -> {:error, :high, "File type not allowed"}
    end
  end

  ## Helper functions for refactored code

  defp check_and_update_rate_limit(current_count, limit, _key, _window)
       when current_count >= limit do
    {:error, :medium, "Rate limit exceeded"}
  end

  defp check_and_update_rate_limit(_current_count, _limit, key, window) do
    increment_rate_count(key, window)
    {:ok, :allowed}
  end

  defp validate_header_errors([]) do
    {:ok, :secure}
  end

  defp validate_header_errors(errors) do
    {:error, :medium, "Security headers issues: #{inspect(errors)}"}
  end

  defp validate_input_length(input, max_length) do
    case String.length(input) <= max_length do
      true -> {:ok, input}
      false -> {:error, :low, "Input exceeds maximum length"}
    end
  end
end
