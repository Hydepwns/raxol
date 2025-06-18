defmodule Raxol.Core.Performance.AIIntegrationTest do
  @moduledoc """
  Tests for the AI integration, including configuration validation,
  performance data analysis, and error handling.
  """
  use ExUnit.Case

  # Only compile Mox and related tests if the flag is enabled
  if Application.compile_env(:raxol, :compile_ai_tests, false) do
    import Mox

    alias Raxol.Core.Performance.AIIntegration

    # Make sure mocks are verified when the test exits
    setup :verify_on_exit!

    describe "AI Integration" do
      setup do
        # Set up test configuration
        Application.put_env(:raxol, :ai_integration, %{
          endpoint: "https://api.ai-agent.com/v1",
          api_key: "test-api-key",
          timeout: 5000,
          retry_attempts: 2,
          retry_delay: 100
        })

        :ok
      end

      test ~c"validates configuration" do
        assert :ok = AIIntegration.validate_config()
      end

      test ~c"detects missing configuration" do
        Application.put_env(:raxol, :ai_integration, %{})
        assert {:error, :missing_config} = AIIntegration.validate_config()
      end

      test ~c"detects invalid endpoint" do
        Application.put_env(:raxol, :ai_integration, %{
          endpoint: "invalid-url",
          api_key: "test-api-key"
        })

        assert {:error, :invalid_endpoint} = AIIntegration.validate_config()
      end

      test ~c"detects invalid API key" do
        Application.put_env(:raxol, :ai_integration, %{
          endpoint: "https://api.ai-agent.com/v1",
          api_key: ""
        })

        assert {:error, :invalid_api_key} = AIIntegration.validate_config()
      end

      test ~c"detects invalid timeout" do
        Application.put_env(:raxol, :ai_integration, %{
          endpoint: "https://api.ai-agent.com/v1",
          api_key: "test-api-key",
          timeout: -1
        })

        assert {:error, :invalid_timeout} = AIIntegration.validate_config()
      end

      test ~c"detects invalid retry configuration" do
        Application.put_env(:raxol, :ai_integration, %{
          endpoint: "https://api.ai-agent.com/v1",
          api_key: "test-api-key",
          retry_attempts: 0,
          retry_delay: 100
        })

        assert {:error, :invalid_retry_attempts} =
                 AIIntegration.validate_config()

        Application.put_env(:raxol, :ai_integration, %{
          endpoint: "https://api.ai-agent.com/v1",
          api_key: "test-api-key",
          retry_attempts: 2,
          retry_delay: 0
        })

        assert {:error, :invalid_retry_delay} = AIIntegration.validate_config()
      end

      test ~c"sends performance data for analysis" do
        data = %{
          metrics: %{
            fps: 60,
            avg_frame_time: 16.5,
            jank_count: 0,
            memory_usage: 100_000_000,
            gc_stats: %{
              number_of_gcs: 10,
              words_reclaimed: 1000,
              heap_size: 100_000,
              heap_limit: 1_000_000
            }
          },
          analysis: %{
            performance_score: 95,
            issues: [],
            suggestions: []
          },
          context: %{
            timestamp: System.system_time(:second),
            environment: %{
              node: Node.node(),
              system: :os.type()
            }
          }
        }

        expected_response = %{
          insights: [
            "Performance analysis indicates stable frame rates",
            "Memory usage is within acceptable range"
          ],
          recommendations: [
            %{
              priority: :low,
              area: :fps,
              description: "Monitor frame rate stability",
              impact: "Maintain current performance",
              effort: :low
            }
          ],
          risk_assessment: %{
            overall_risk: :low,
            areas: %{
              fps: :low,
              memory: :low,
              jank: :low,
              gc: :low
            }
          },
          optimization_impact: %{
            fps: "stable",
            memory: "stable",
            jank: "none",
            gc: "stable"
          },
          ai_confidence: 0.95
        }

        # Mock HTTPoison for successful request
        expect(HTTPoison, :request, fn method, url, body, headers, opts ->
          assert method == :post
          assert url == "https://api.ai-agent.com/v1/analyze"

          assert headers == [
                   {"Authorization", "Bearer test-api-key"},
                   {"Content-Type", "application/json"}
                 ]

          assert Map.get(opts, :timeout) == 5000
          assert Map.get(opts, :recv_timeout) == 5000

          {:ok,
           %{
             status_code: 200,
             body: Jason.encode!(expected_response)
           }}
        end)

        assert {:ok, analysis} = AIIntegration.analyze(data)

        assert analysis.insights == expected_response.insights
        assert analysis.recommendations == expected_response.recommendations
        assert analysis.risk_assessment == expected_response.risk_assessment

        assert analysis.optimization_impact ==
                 expected_response.optimization_impact

        assert analysis.ai_confidence == expected_response.ai_confidence
        assert Map.has_key?(analysis.metadata, :analyzed_at)
        assert analysis.metadata.version == "1.0.0"
      end

      test ~c"handles API errors" do
        data = %{
          metrics: %{fps: 60},
          analysis: %{},
          context: %{}
        }

        # Mock HTTPoison for failed request
        expect(HTTPoison, :request, fn _method, _url, _body, _headers, _opts ->
          {:ok,
           %{
             status_code: 500,
             body: "Internal Server Error"
           }}
        end)

        assert {:error, :max_retries_exceeded} = AIIntegration.analyze(data)
      end

      test ~c"handles network errors" do
        data = %{
          metrics: %{fps: 60},
          analysis: %{},
          context: %{}
        }

        # Mock HTTPoison for network error
        expect(HTTPoison, :request, fn _method, _url, _body, _headers, _opts ->
          {:error, %HTTPoison.Error{reason: "Connection refused"}}
        end)

        assert {:error, :max_retries_exceeded} = AIIntegration.analyze(data)
      end

      test ~c"handles invalid response format" do
        data = %{
          metrics: %{fps: 60},
          analysis: %{},
          context: %{}
        }

        # Mock HTTPoison for invalid response
        expect(HTTPoison, :request, fn _method, _url, _body, _headers, _opts ->
          {:ok,
           %{
             status_code: 200,
             body: Jason.encode!(%{invalid: "format"})
           }}
        end)

        assert {:error, :invalid_analysis_format} = AIIntegration.analyze(data)
      end

      test ~c"respects custom timeout and retry options" do
        data = %{
          metrics: %{fps: 60},
          analysis: %{},
          context: %{}
        }

        options = %{
          timeout: 10_000,
          retry_attempts: 1,
          retry_delay: 200
        }

        # Mock HTTPoison to verify <options>
        expect(HTTPoison, :request, fn _method, _url, _body, _headers, opts ->
          assert Map.get(opts, :timeout) == 10_000
          assert Map.get(opts, :recv_timeout) == 10_000

          {:ok,
           %{
             status_code: 500,
             body: "Internal Server Error"
           }}
        end)

        assert {:error, :max_retries_exceeded} =
                 AIIntegration.analyze(data, options)
      end
    end
  end
end
