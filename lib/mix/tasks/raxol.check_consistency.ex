defmodule Mix.Tasks.Raxol.CheckConsistency do
  @moduledoc """
  Checks code consistency across the Raxol codebase.

  ## Usage

      mix raxol.check_consistency [options]

  ## Options

    * `--dir` - Directory to check (default: lib/raxol)
    * `--format` - Output format: text, json, html (default: text)
    * `--severity` - Minimum severity to report: info, warning, error (default: info)
    * `--fix` - Attempt to auto-fix issues

  ## Examples

      mix raxol.check_consistency

      mix raxol.check_consistency --dir lib/raxol/terminal

      mix raxol.check_consistency --severity warning

      mix raxol.check_consistency --format json
  """

  use Mix.Task

  alias Raxol.Core.Standards.ConsistencyChecker

  @shortdoc "Checks code consistency"

  @impl Mix.Task
  def run(args) do
    opts = parse_options(args)

    Mix.shell().info("Checking code consistency in #{opts.dir}...")

    case ConsistencyChecker.check_directory(opts.dir) do
      {:ok, report} ->
        filtered_report = filter_by_severity(report, opts.severity)

        if opts.auto_fix do
          apply_fixes(filtered_report)
        end

        output_report(filtered_report, opts.format)

        exit_code = if Enum.empty?(filtered_report.issues), do: 0, else: 1
        System.at_exit(fn _ -> exit({:shutdown, exit_code}) end)

      {:error, reason} ->
        Mix.shell().error("Error checking consistency: #{inspect(reason)}")
        System.at_exit(fn _ -> exit({:shutdown, 1}) end)
    end
  end

  defp parse_options(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          dir: :string,
          format: :string,
          severity: :string,
          fix: :boolean
        ]
      )

    %{
      dir: Keyword.get(opts, :dir, "lib/raxol"),
      format: Keyword.get(opts, :format, "text"),
      severity: Keyword.get(opts, :severity, "info"),
      auto_fix: Keyword.get(opts, :fix, false)
    }
  end

  defp filter_by_severity(report, severity) do
    severity_level = severity_to_level(severity)

    filtered_issues =
      Enum.filter(report.issues, fn issue ->
        issue_level = severity_to_level(to_string(issue.severity))
        issue_level >= severity_level
      end)

    %{report | issues: filtered_issues}
  end

  defp severity_to_level("error"), do: 3
  defp severity_to_level("warning"), do: 2
  defp severity_to_level("info"), do: 1
  defp severity_to_level(_), do: 1

  defp output_report(report, "json") do
    json = Jason.encode!(report, pretty: true)
    IO.puts(json)
  end

  defp output_report(report, "html") do
    html = generate_html_report(report)
    File.write!("consistency_report.html", html)
    Mix.shell().info("HTML report written to consistency_report.html")
  end

  defp output_report(report, _) do
    output = ConsistencyChecker.generate_report(report)
    IO.puts(output)

    if length(report.issues) > 0 do
      Mix.shell().info("\nFound #{length(report.issues)} consistency issues")
    else
      Mix.shell().info("\n✓ No consistency issues found!")
    end
  end

  defp apply_fixes(report) do
    Mix.shell().info("Attempting to auto-fix issues...")

    fixable_issues = Enum.filter(report.issues, &fixable?/1)

    Enum.each(fixable_issues, fn issue ->
      case fix_issue(issue) do
        :ok ->
          Mix.shell().info(
            "Fixed: #{issue.file}:#{issue.line} - #{issue.message}"
          )

        {:error, reason} ->
          Mix.shell().error(
            "Failed to fix #{issue.file}:#{issue.line} - #{reason}"
          )
      end
    end)

    Mix.shell().info(
      "Fixed #{length(fixable_issues)} of #{length(report.issues)} issues"
    )
  end

  defp fixable?(%{type: :formatting}), do: true
  defp fixable?(%{type: :trailing_whitespace}), do: true
  defp fixable?(_), do: false

  defp fix_issue(%{type: :formatting, file: file}) do
    System.cmd("mix", ["format", file])
    :ok
  rescue
    _ -> {:error, "Failed to run mix format"}
  end

  defp fix_issue(%{type: :trailing_whitespace, file: file, line: line}) do
    with {:ok, content} <- File.read(file),
         lines <- String.split(content, "\n"),
         fixed_line <- String.trim_trailing(Enum.at(lines, line - 1)),
         fixed_lines <- List.replace_at(lines, line - 1, fixed_line),
         fixed_content <- Enum.join(fixed_lines, "\n") do
      File.write(file, fixed_content)
    end
  end

  defp generate_html_report(report) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Raxol Code Consistency Report</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .summary { background: #f0f0f0; padding: 10px; margin: 20px 0; }
        .issue { margin: 10px 0; padding: 10px; border-left: 3px solid #ccc; }
        .error { border-color: #f44336; }
        .warning { border-color: #ff9800; }
        .info { border-color: #2196f3; }
        .file-name { font-weight: bold; color: #666; }
        .line-number { color: #999; }
        .message { margin-top: 5px; }
      </style>
    </head>
    <body>
      <h1>Raxol Code Consistency Report</h1>

      <div class="summary">
        <h2>Summary</h2>
        <p>Total files analyzed: #{report.total_files}</p>
        <p>Total issues found: #{length(report.issues)}</p>
        #{format_summary_html(report.summary)}
      </div>

      <h2>Issues</h2>
      #{format_issues_html(report.issues)}
    </body>
    </html>
    """
  end

  defp format_summary_html(summary) do
    Enum.map_join(summary, "\n", fn {type, count} ->
      "<p>#{String.capitalize(to_string(type))}: #{count}</p>"
    end)
  end

  defp format_issues_html(issues) do
    Enum.map_join(issues, "\n", fn {file, file_issues} ->
      """
      <div class="file-section">
        <h3 class="file-name">#{file}</h3>
        #{format_file_issues_html(file_issues)}
      </div>
      """
    end)
  end

  defp format_file_issues_html(issues) do
    Enum.map_join(issues, "\n", fn issue ->
      """
      <div class="issue #{issue.severity}">
        <span class="line-number">Line #{issue.line}</span>
        <span class="severity">[#{issue.severity}]</span>
        <div class="message">#{issue.message}</div>
      </div>
      """
    end)
  end
end
