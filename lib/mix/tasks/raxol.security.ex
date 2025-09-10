defmodule Mix.Tasks.Raxol.Security do
  @moduledoc """
  Comprehensive security scanning for the Raxol project.

  This task runs multiple security tools to check for vulnerabilities:
  - Sobelow: Security-focused static analysis for Phoenix applications
  - Mix Audit: Checks dependencies for known security vulnerabilities

  ## Usage

      mix raxol.security          # Run all security checks
      mix raxol.security --quick  # Run quick checks only (skip detailed analysis)
      mix raxol.security --fix    # Attempt to fix issues where possible
  """

  use Mix.Task

  @shortdoc "Run comprehensive security scanning"

  @switches [
    quick: :boolean,
    fix: :boolean,
    verbose: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    Mix.shell().info("🔒 Starting Raxol Security Scan...")
    Mix.shell().info("")

    results = []

    # Run dependency audit
    results = results ++ run_mix_audit(opts)

    # Run Sobelow security analysis
    results = results ++ run_sobelow(opts)

    # Run additional custom checks
    results = results ++ run_custom_checks(opts)

    # Print summary
    print_summary(results)
  end

  defp run_mix_audit(opts) do
    Mix.shell().info("📦 Checking dependencies for vulnerabilities...")

    try do
      case Mix.shell().cmd("mix deps.audit") do
        0 ->
          Mix.shell().info("  ✅ No vulnerable dependencies found")
          [{:deps_audit, :passed}]

        _ ->
          Mix.shell().error("  ⚠️  Vulnerable dependencies detected")

          if opts[:fix] do
            Mix.shell().info(
              "  🔧 Attempting to update vulnerable dependencies..."
            )

            Mix.shell().cmd("mix deps.update --all")
          end

          [{:deps_audit, :failed}]
      end
    rescue
      _ ->
        Mix.shell().error("  ❌ Failed to run mix deps.audit")
        [{:deps_audit, :error}]
    end
  end

  defp run_sobelow(opts) do
    Mix.shell().info("")
    Mix.shell().info("🔍 Running Sobelow security analysis...")

    sobelow_args = if opts[:quick], do: "--skip", else: ""

    try do
      case Mix.shell().cmd("mix sobelow #{sobelow_args}") do
        0 ->
          Mix.shell().info("  ✅ No security issues found")
          [{:sobelow, :passed}]

        _ ->
          Mix.shell().error("  ⚠️  Security issues detected")
          [{:sobelow, :failed}]
      end
    rescue
      _ ->
        Mix.shell().error("  ❌ Failed to run Sobelow")
        [{:sobelow, :error}]
    end
  end

  defp run_custom_checks(opts) do
    Mix.shell().info("")
    Mix.shell().info("🔐 Running custom security checks...")

    results = []

    # Check for hardcoded secrets
    results = results ++ check_for_secrets(opts)

    # Check for insecure configurations
    results = results ++ check_configurations(opts)

    # Check file permissions
    results = results ++ check_file_permissions(opts)

    results
  end

  defp check_for_secrets(_opts) do
    Mix.shell().info("  • Checking for hardcoded secrets...")

    patterns = [
      ~r/(?i)(api[_-]?key|apikey|secret[_-]?key|password|passwd|pwd)\s*[:=]\s*["'][^"']+["']/,
      ~r/(?i)bearer\s+[a-zA-Z0-9\-\._~\+\/]+=*/,
      ~r/-----BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY-----/
    ]

    suspicious_files =
      Path.wildcard("lib/**/*.{ex,exs}")
      |> Enum.filter(fn file ->
        content = File.read!(file)

        Enum.any?(patterns, fn pattern ->
          Regex.match?(pattern, content)
        end)
      end)

    if Enum.empty?(suspicious_files) do
      Mix.shell().info("    ✅ No hardcoded secrets found")
      [{:secrets_check, :passed}]
    else
      Mix.shell().error(
        "    ⚠️  Potential secrets found in: #{inspect(suspicious_files)}"
      )

      [{:secrets_check, :failed}]
    end
  end

  defp check_configurations(_opts) do
    Mix.shell().info("  • Checking security configurations...")

    issues =
      []
      |> check_endpoint_security()
      |> check_cors_configuration()

    if Enum.empty?(issues) do
      Mix.shell().info("    ✅ Security configurations look good")
      [{:config_check, :passed}]
    else
      Enum.each(issues, &Mix.shell().error("    ⚠️  #{&1}"))
      [{:config_check, :failed}]
    end
  end

  defp check_endpoint_security(issues) do
    endpoint_file = "lib/raxol_web/endpoint.ex"

    if File.exists?(endpoint_file) do
      content = File.read!(endpoint_file)

      issues =
        if String.contains?(content, "force_ssl"),
          do: issues,
          else: ["Missing force_ssl configuration" | issues]

      if String.contains?(content, "secure_browser_headers"),
        do: issues,
        else: ["Missing secure browser headers" | issues]
    else
      issues
    end
  end

  defp check_cors_configuration(issues) do
    if File.exists?("lib/raxol_web/router.ex") do
      router_content = File.read!("lib/raxol_web/router.ex")

      if String.contains?(router_content, "cors_plug") &&
           String.contains?(router_content, "origin: \"*\"") do
        ["Overly permissive CORS configuration" | issues]
      else
        issues
      end
    else
      issues
    end
  end

  defp check_file_permissions(_opts) do
    Mix.shell().info("  • Checking file permissions...")

    sensitive_files = [
      "config/prod.secret.exs",
      ".env",
      ".env.production"
    ]

    issues =
      Enum.reduce(sensitive_files, [], fn file, acc ->
        if File.exists?(file) do
          %{mode: mode} = File.stat!(file)
          # Check if file is world-readable (last 3 bits)
          if Bitwise.band(mode, 0o007) != 0 do
            ["#{file} is world-readable" | acc]
          else
            acc
          end
        else
          acc
        end
      end)

    if Enum.empty?(issues) do
      Mix.shell().info("    ✅ File permissions are secure")
      [{:permissions_check, :passed}]
    else
      Enum.each(issues, &Mix.shell().error("    ⚠️  #{&1}"))
      [{:permissions_check, :failed}]
    end
  end

  defp print_summary(results) do
    Mix.shell().info("")
    Mix.shell().info("=" |> String.duplicate(50))
    Mix.shell().info("SECURITY SCAN SUMMARY")
    Mix.shell().info("=" |> String.duplicate(50))

    passed = Enum.count(results, fn {_, status} -> status == :passed end)
    failed = Enum.count(results, fn {_, status} -> status == :failed end)
    errors = Enum.count(results, fn {_, status} -> status == :error end)

    total = length(results)

    Mix.shell().info("Total checks: #{total}")
    Mix.shell().info("  ✅ Passed: #{passed}")

    if failed > 0 do
      Mix.shell().error("  ⚠️  Failed: #{failed}")
    end

    if errors > 0 do
      Mix.shell().error("  ❌ Errors: #{errors}")
    end

    Mix.shell().info("")

    if failed == 0 and errors == 0 do
      Mix.shell().info("🎉 All security checks passed!")
    else
      Mix.shell().error("⚠️  Security issues detected. Please review and fix.")
      exit({:shutdown, 1})
    end
  end
end
