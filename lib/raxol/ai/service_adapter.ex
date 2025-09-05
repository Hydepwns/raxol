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

    response = generate_mock_response(downcase_prompt, prompt, max_length)

    {:ok, response}
  end

  defp local_generate_content(prompt, options) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
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
         end) do
      {:ok, result} -> result
      {:error, _reason} -> {:error, :service_unavailable}
    end
  end

  defp openai_generate_content(prompt, options) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           # Implementation for OpenAI API
           api_key = Application.get_env(:raxol, :openai_api_key)

           api_key = Application.get_env(:raxol, :openai_api_key)
           make_openai_request(api_key, prompt, options)
         end) do
      {:ok, result} -> result
      {:error, _reason} -> {:error, :service_unavailable}
    end
  end

  defp anthropic_generate_content(prompt, options) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           # Implementation for Anthropic Claude API
           api_key = Application.get_env(:raxol, :anthropic_api_key)

           api_key = Application.get_env(:raxol, :anthropic_api_key)
           make_anthropic_request(api_key, prompt, options)
         end) do
      {:ok, result} -> result
      {:error, _reason} -> {:error, :service_unavailable}
    end
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
      classify_analysis_line(line, acc)
    end)
    |> Enum.reverse()
  end

  defp extract_suggestion(line) do
    patterns = [
      {~r/cache/i, "Implement caching mechanism"},
      {~r/virtual/i, "Consider virtual scrolling"},
      {~r/memoiz/i, "Add memoization for expensive operations"},
      {~r/batch/i, "Batch operations for better performance"}
    ]

    Enum.find_value(patterns, "Review and optimize this area", fn {pattern,
                                                                   suggestion} ->
      check_pattern_match(line, pattern, suggestion)
    end)
  end

  # Helper functions for pattern matching refactoring

  defp generate_mock_response(downcase_prompt, prompt, max_length) do
    response_patterns = [
      {~r/error/, "Error handling implementation needed"},
      {~r/performance/, "Consider optimizing rendering cycles"},
      {~r/suggest/,
       "Here are some suggestions: 1. Optimize state management 2. Implement caching"}
    ]

    Enum.find_value(
      response_patterns,
      "AI-generated response for: #{String.slice(prompt, 0, max_length)}",
      fn {pattern, response} ->
        check_prompt_match(downcase_prompt, pattern, response)
      end
    )
  end

  defp classify_analysis_line(line, acc) do
    classifications = [
      {~r/(slow|performance|bottleneck)/i, :performance, :medium},
      {~r/(memory|leak|allocation)/i, :memory, :high},
      {~r/(state|update|render)/i, :rendering, :medium}
    ]

    case Enum.find(classifications, fn {pattern, _type, _severity} ->
           line =~ pattern
         end) do
      {_pattern, type, severity} ->
        [
          %{
            type: type,
            severity: severity,
            description: String.trim(line),
            suggestion: extract_suggestion(line)
          }
          | acc
        ]

      nil ->
        acc
    end
  end

  defp make_openai_request(nil, _prompt, _options), do: {:error, :api_key_not_configured}
  defp make_openai_request(api_key, prompt, options) do
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
  end

  defp make_anthropic_request(nil, _prompt, _options), do: {:error, :api_key_not_configured}
  defp make_anthropic_request(api_key, prompt, options) do
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
  end

  defp check_pattern_match(line, pattern, suggestion) do
    case line =~ pattern do
      true -> suggestion
      false -> nil
    end
  end

  defp check_prompt_match(downcase_prompt, pattern, response) do
    case downcase_prompt =~ pattern do
      true -> response
      false -> nil
    end
  end
end
