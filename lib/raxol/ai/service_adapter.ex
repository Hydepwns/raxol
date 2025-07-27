defmodule Raxol.AI.ServiceAdapter do
  @moduledoc """
  Adapter for integrating with external AI services.

  This module provides a standardized interface for different AI providers
  and handles the actual implementation of AI-powered features.
  """

  @type provider :: :openai | :anthropic | :local | :mock
  @type service_config :: %{
          provider: provider(),
          api_key: String.t() | nil,
          base_url: String.t() | nil,
          model: String.t(),
          timeout: integer()
        }

  @doc """
  Initializes the AI service adapter with the specified provider.
  """
  @spec init(service_config()) :: {:ok, pid()} | {:error, term()}
  def init(config) do
    case config.provider do
      :mock ->
        {:ok, self()}

      :local ->
        init_local_service(config)

      provider when provider in [:openai, :anthropic] ->
        init_external_service(provider, config)

      _ ->
        {:error, :unsupported_provider}
    end
  end

  @doc """
  Generates content using the configured AI service.
  """
  @spec generate_content(String.t(), map()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_content(prompt, options \\ %{}) do
    provider = get_provider()

    case provider do
      :mock -> mock_generate_content(prompt, options)
      :local -> local_generate_content(prompt, options)
      :openai -> openai_generate_content(prompt, options)
      :anthropic -> anthropic_generate_content(prompt, options)
      _ -> {:error, :provider_not_configured}
    end
  end

  @doc """
  Generates text suggestions based on context.
  """
  @spec generate_suggestions(String.t(), map()) ::
          {:ok, [String.t()]} | {:error, term()}
  def generate_suggestions(input, context \\ %{}) do
    prompt = build_suggestion_prompt(input, context)

    case generate_content(prompt, %{max_tokens: 150, temperature: 0.7}) do
      {:ok, response} ->
        suggestions = parse_suggestions(response)
        {:ok, suggestions}

      error ->
        error
    end
  end

  @doc """
  Analyzes code for performance optimization suggestions.
  """
  @spec analyze_performance(String.t(), map()) ::
          {:ok, [map()]} | {:error, term()}
  def analyze_performance(code, context \\ %{}) do
    prompt = build_performance_analysis_prompt(code, context)

    case generate_content(prompt, %{max_tokens: 300, temperature: 0.3}) do
      {:ok, response} ->
        analysis = parse_performance_analysis(response)
        {:ok, analysis}

      error ->
        error
    end
  end

  # Private implementation functions

  defp init_local_service(_config) do
    # For local AI models (e.g., using a local LLM server)
    {:ok, self()}
  end

  defp init_external_service(_provider, _config) do
    # Initialize HTTP client for external AI services
    {:ok, self()}
  end

  defp get_provider do
    Application.get_env(:raxol, :ai_provider, :mock)
  end

  defp mock_generate_content(prompt, options) do
    # Mock implementation for testing and development
    max_length = Map.get(options, :max_tokens, 100)
    downcase_prompt = String.downcase(prompt)

    response =
      cond do
        String.contains?(downcase_prompt, "error") ->
          "Error handling implementation needed"

        String.contains?(downcase_prompt, "performance") ->
          "Consider optimizing rendering cycles"

        String.contains?(downcase_prompt, "suggest") ->
          "Here are some suggestions: 1. Optimize state management 2. Implement caching"

        true ->
          "AI-generated response for: #{String.slice(prompt, 0, max_length)}"
      end

    {:ok, response}
  end

  defp local_generate_content(prompt, options) do
    # Implementation for local AI service
    # This would call a local LLM server or use a local model
    case HTTPoison.post(
           "http://localhost:8080/v1/completions",
           Jason.encode!(%{
             prompt: prompt,
             max_tokens: Map.get(options, :max_tokens, 100),
             temperature: Map.get(options, :temperature, 0.7)
           }),
           [{"Content-Type", "application/json"}]
         ) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"choices" => [%{"text" => text} | _]}} -> {:ok, text}
          _ -> {:error, :invalid_response}
        end

      {:ok, %{status_code: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    _ -> {:error, :service_unavailable}
  end

  defp openai_generate_content(prompt, options) do
    # Implementation for OpenAI API
    api_key = Application.get_env(:raxol, :openai_api_key)

    if api_key do
      case HTTPoison.post(
             "https://api.openai.com/v1/completions",
             Jason.encode!(%{
               model: "gpt-3.5-turbo-instruct",
               prompt: prompt,
               max_tokens: Map.get(options, :max_tokens, 100),
               temperature: Map.get(options, :temperature, 0.7)
             }),
             [
               {"Content-Type", "application/json"},
               {"Authorization", "Bearer #{api_key}"}
             ]
           ) do
        {:ok, %{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"choices" => [%{"text" => text} | _]}} ->
              {:ok, String.trim(text)}

            _ ->
              {:error, :invalid_response}
          end

        {:ok, %{status_code: status}} ->
          {:error, {:http_error, status}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :api_key_not_configured}
    end
  rescue
    _ -> {:error, :service_unavailable}
  end

  defp anthropic_generate_content(prompt, options) do
    # Implementation for Anthropic Claude API
    api_key = Application.get_env(:raxol, :anthropic_api_key)

    if api_key do
      case HTTPoison.post(
             "https://api.anthropic.com/v1/messages",
             Jason.encode!(%{
               model: "claude-3-haiku-20240307",
               max_tokens: Map.get(options, :max_tokens, 100),
               messages: [%{role: "user", content: prompt}]
             }),
             [
               {"Content-Type", "application/json"},
               {"x-api-key", api_key},
               {"anthropic-version", "2023-06-01"}
             ]
           ) do
        {:ok, %{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"content" => [%{"text" => text} | _]}} ->
              {:ok, String.trim(text)}

            _ ->
              {:error, :invalid_response}
          end

        {:ok, %{status_code: status}} ->
          {:error, {:http_error, status}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :api_key_not_configured}
    end
  rescue
    _ -> {:error, :service_unavailable}
  end

  defp build_suggestion_prompt(input, context) do
    language = Map.get(context, :language, "elixir")
    context_info = Map.get(context, :context, "general programming")

    """
    Given the following #{language} code input: "#{input}"

    Context: #{context_info}

    Provide 3 practical code completion suggestions that would be helpful in this context.
    Format as a simple list with one suggestion per line.
    """
  end

  defp build_performance_analysis_prompt(code, context) do
    component_type = Map.get(context, :component_type, "general")

    """
    Analyze the following Elixir code for performance issues:

    ```elixir
    #{code}
    ```

    Component type: #{component_type}

    Identify potential performance bottlenecks and provide specific optimization suggestions.
    Focus on:
    1. Rendering performance
    2. Memory usage
    3. State management efficiency
    4. Event handling optimization

    Format your response as practical, actionable suggestions.
    """
  end

  defp parse_suggestions(response) do
    response
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(fn line ->
      line != "" and not String.starts_with?(line, "#")
    end)
    |> Enum.take(5)
  end

  defp parse_performance_analysis(response) do
    # Parse the AI response into structured analysis results
    lines = String.split(response, "\n")

    Enum.reduce(lines, [], fn line, acc ->
      cond do
        String.contains?(line, ["slow", "performance", "bottleneck"]) ->
          [
            %{
              type: :performance,
              severity: :medium,
              description: String.trim(line),
              suggestion: extract_suggestion(line)
            }
            | acc
          ]

        String.contains?(line, ["memory", "leak", "allocation"]) ->
          [
            %{
              type: :memory,
              severity: :high,
              description: String.trim(line),
              suggestion: extract_suggestion(line)
            }
            | acc
          ]

        String.contains?(line, ["state", "update", "render"]) ->
          [
            %{
              type: :rendering,
              severity: :medium,
              description: String.trim(line),
              suggestion: extract_suggestion(line)
            }
            | acc
          ]

        true ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp extract_suggestion(line) do
    # Extract actionable suggestions from the analysis line
    cond do
      String.contains?(line, "cache") ->
        "Implement caching mechanism"

      String.contains?(line, "virtual") ->
        "Consider virtual scrolling"

      String.contains?(line, "memoiz") ->
        "Add memoization for expensive operations"

      String.contains?(line, "batch") ->
        "Batch operations for better performance"

      true ->
        "Review and optimize this area"
    end
  end
end
