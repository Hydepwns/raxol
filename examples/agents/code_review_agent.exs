# Code Review Agent Example
#
# Demonstrates: `use Raxol.Agent`, shell commands to read files,
# async processing (simulated LLM call), structured findings in model,
# and view rendering for status display.
#
# Run with: mix run examples/agents/code_review_agent.exs

Logger.configure(level: :warning)

defmodule CodeReviewAgent do
  use Raxol.Agent

  @impl true
  def init(_context) do
    files = ["lib/raxol/agent.ex", "lib/raxol/agent/session.ex"]

    %{
      files: files,
      current_file: nil,
      findings: [],
      status: :starting
    }
  end

  @impl true
  def update({:agent_message, _from, :start_review}, model) do
    case model.files do
      [file | rest] ->
        {%{model | current_file: file, files: rest, status: :reading},
         [Command.shell("wc -l < #{file}")]}

      [] ->
        {%{model | status: :done}, []}
    end
  end

  @impl true
  def update({:command_result, {:shell_result, result}}, model) do
    finding = %{
      file: model.current_file,
      line_count: String.trim(result.output),
      exit_status: result.exit_status
    }

    new_model = %{model | findings: [finding | model.findings]}

    case model.files do
      [next | rest] ->
        {%{new_model | current_file: next, files: rest},
         [Command.shell("wc -l < #{next}")]}

      [] ->
        # Simulate async LLM analysis
        {%{new_model | status: :analyzing},
         [
           Command.async(fn sender ->
             Process.sleep(100)

             sender.(
               {:analysis_complete, "All files reviewed. No critical issues."}
             )
           end)
         ]}
    end
  end

  @impl true
  def update({:command_result, {:analysis_complete, summary}}, model) do
    IO.puts("\n--- Code Review Complete ---")
    IO.puts("Summary: #{summary}")
    IO.puts("Files reviewed: #{length(model.findings)}")

    Enum.each(model.findings, fn f ->
      IO.puts("  #{f.file}: #{f.line_count}")
    end)

    {%{model | status: :done}, [Command.quit()]}
  end

  @impl true
  def update(msg, model) do
    IO.puts("[CodeReviewAgent] Unhandled: #{inspect(msg)}")
    {model, []}
  end

  @impl true
  def view(model) do
    column do
      [
        text("Code Review Agent", style: [:bold]),
        text("Status: #{model.status}"),
        text("Files remaining: #{length(model.files)}"),
        text("Findings: #{length(model.findings)}")
      ]
    end
  end
end

# Start the agent
{:ok, _pid} =
  Raxol.Agent.Session.start_link(
    app_module: CodeReviewAgent,
    id: :code_reviewer
  )

# Kick off the review
Raxol.Agent.Session.send_message(:code_reviewer, :start_review)

# Wait for it to finish
Process.sleep(3000)
