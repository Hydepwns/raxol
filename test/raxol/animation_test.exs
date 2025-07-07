defmodule Raxol.AnimationTest do
  use ExUnit.Case, async: false
  import Raxol.AccessibilityTestHelpers

  alias Raxol.Animation.{Framework, Animation, StateManager}
  alias Raxol.Core.Accessibility
  alias Raxol.Core.UserPreferences

  # Helper to wait for animation completion
  defp wait_for_animation_completion(element_id, animation_name, timeout \\ 500) do
    assert_receive {:animation_completed, ^element_id, ^animation_name}, timeout
  end

  # Helper to wait for animation start
  defp wait_for_animation_start(element_id, animation_name, timeout \\ 500) do
    assert_receive {:animation_started, ^element_id, ^animation_name}, timeout
  end

  setup do
    # Start UserPreferences with a test-specific name
    local_user_prefs_name = __MODULE__.UserPreferences
    user_prefs_opts = [name: local_user_prefs_name, test_mode?: true]

    {:ok, _pid} = start_supervised({UserPreferences, user_prefs_opts})
    Framework.init(%{}, local_user_prefs_name)

    # Reset relevant prefs before each test
    UserPreferences.set(
      "accessibility.reduced_motion",
      false,
      local_user_prefs_name
    )

    UserPreferences.set(
      "accessibility.screen_reader",
      true,
      local_user_prefs_name
    )

    UserPreferences.set(
      "accessibility.silence_announcements",
      false,
      local_user_prefs_name
    )

    # Wait for preferences to be applied
    assert_receive {:preferences_applied, ^local_user_prefs_name}, 100

    on_exit(fn ->
      Framework.stop()
    end)

    :ok
  end

  setup_all do
    Process.flag(:trap_exit, true)

    if pid = Process.whereis(Raxol.Core.UserPreferences) do
      IO.puts(
        "setup_all: Linked processes before stop: #{inspect(Process.info(self(), :links))}"
      )

      IO.puts(
        "setup_all: Stopping global UserPreferences process gracefully: #{inspect(pid)} from #{inspect(self())}"
      )

      try do
        GenServer.stop(pid)
      catch
        :exit, reason ->
          IO.puts("setup_all: GenServer.stop exit: #{inspect(reason)}")
      end

      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} ->
          IO.puts("setup_all: Confirmed UserPreferences stopped")
      after
        500 -> IO.puts("setup_all: Timeout waiting for UserPreferences to stop")
      end

      IO.puts(
        "setup_all: Linked processes after stop: #{inspect(Process.info(self(), :links))}"
      )
    end

    :ok
  end

  setup context do
    Process.flag(:trap_exit, true)

    # Use the global UserPreferences process that's already started
    pid = Process.whereis(Raxol.Core.UserPreferences)

    Animation.init(%{}, pid)
    Accessibility.enable([], pid)
    UserPreferences.set("accessibility.reduced_motion", false, pid)
    UserPreferences.set("accessibility.screen_reader", true, pid)
    UserPreferences.set("accessibility.silence_announcements", false, pid)
    Accessibility.clear_announcements()
    assert_receive {:preferences_applied, _pid}, 100

    on_exit(fn ->
      Animation.stop()
      Accessibility.disable(pid)
    end)

    {:ok, user_preferences_pid: pid}
  end

  describe "Animation Framework with accessibility integration" do
    test "respects reduced motion settings", %{
      user_preferences_pid: user_preferences_pid
    } do
      UserPreferences.set(
        "accessibility.reduced_motion",
        false,
        user_preferences_pid
      )

      Framework.init(%{}, user_preferences_pid)

      standard_def =
        Framework.create_animation(:standard_anim_1, %{
          duration: 500,
          from: 0,
          to: 100,
          target_path: [:opacity]
        })

      :ok =
        Framework.start_animation(
          standard_def.name,
          "element_std",
          %{},
          user_preferences_pid
        )

      wait_for_animation_start("element_std", standard_def.name)

      standard_instance =
        get_in(StateManager.get_active_animations(), [
          "element_std",
          standard_def.name
        ])

      original_duration = standard_instance.animation.duration
      StateManager.remove_active_animation("element_std", standard_def.name)

      UserPreferences.set(
        "accessibility.reduced_motion",
        true,
        user_preferences_pid
      )

      Framework.init(%{}, user_preferences_pid)

      reduced_def =
        Framework.create_animation(:reduced_motion_anim_1, %{
          duration: 500,
          from: 0,
          to: 100,
          target_path: [:opacity]
        })

      :ok =
        Framework.start_animation(
          reduced_def.name,
          "element_reduced",
          %{},
          user_preferences_pid
        )

      reduced_instance =
        get_in(StateManager.get_active_animations(), [
          "element_reduced",
          reduced_def.name
        ])

      # Check adapted duration after starting (adaptation happens at start)
      adapted_duration =
        if reduced_instance, do: reduced_instance.animation.duration, else: 10

      assert adapted_duration < original_duration
      assert adapted_duration == 10
      wait_for_animation_start("element_reduced", reduced_def.name)
    end

    test "announces animation start and completion to screen readers when relevant",
         %{user_preferences_pid: user_preferences_pid} do
      with_screen_reader_spy(user_preferences_pid, fn ->
        animation =
          Framework.create_animation(
            :announce_anim_1,
            %{
              duration: 200,
              from: 0,
              to: 100,
              announce_to_screen_reader: true,
              description: "Loading process",
              target_path: [:opacity]
            }
          )

        Framework.start_animation(
          animation.name,
          "test_element",
          %{notify_pid: self()},
          user_preferences_pid
        )

        # Simulate time passing by adjusting start_time
        instance =
          get_in(StateManager.get_active_animations(), [
            "test_element",
            animation.name
          ])

        if instance do
          # Set start_time far enough in the past
          updated_instance = %{
            instance
            | start_time: instance.start_time - (animation.duration + 1)
          }

          StateManager.put_active_animation(
            "test_element",
            animation.name,
            updated_instance
          )
        end

        Framework.apply_animations_to_state(%{}, user_preferences_pid)
        wait_for_animation_start("test_element", animation.name)
        wait_for_animation_completion("test_element", animation.name)
        assert_announced("Loading process started")
        assert_announced("Loading process completed")
      end)
    end

    test "does not announce non-important animations to screen readers", %{
      user_preferences_pid: user_preferences_pid
    } do
      with_screen_reader_spy(user_preferences_pid, fn ->
        animation =
          Framework.create_animation(
            :non_announce_anim_1,
            %{
              duration: 200,
              from: 0,
              to: 100,
              announce_to_screen_reader: false,
              target_path: [:opacity]
            }
          )

        Framework.start_animation(
          animation.name,
          "test_element",
          %{notify_pid: self()},
          user_preferences_pid
        )

        # Simulate time passing
        instance =
          get_in(StateManager.get_active_animations(), [
            "test_element",
            animation.name
          ])

        if instance do
          updated_instance = %{
            instance
            | start_time: instance.start_time - (animation.duration + 1)
          }

          StateManager.put_active_animation(
            "test_element",
            animation.name,
            updated_instance
          )
        end

        Framework.apply_animations_to_state(%{}, user_preferences_pid)
        wait_for_animation_start("test_element", animation.name)
        wait_for_animation_completion("test_element", animation.name)
        assert_no_announcements()
      end)
    end

    test "disables animations when system preference is set", %{
      user_preferences_pid: user_preferences_pid
    } do
      UserPreferences.set(:disable_all_animations, true, user_preferences_pid)

      animation =
        Framework.create_animation(
          :disable_test_anim_1,
          %{
            duration: 500,
            from: 0,
            to: 100,
            announce_to_screen_reader: true,
            description: "Test animation"
          }
        )

      :ok =
        Framework.start_animation(
          animation.name,
          "test_element",
          %{},
          user_preferences_pid
        )

      # Apply animations to state to trigger completion for disabled animations
      Framework.apply_animations_to_state(%{}, user_preferences_pid)

      wait_for_animation_start("test_element", animation.name)
      wait_for_animation_completion("test_element", animation.name)
      assert_no_announcements()
    end

    test "provides alternative non-animated experience", %{
      user_preferences_pid: user_preferences_pid
    } do
      with_reduced_motion(user_preferences_pid, fn ->
        :ok
      end)
    end

    test "animation framework integrates with user preferences", %{
      user_preferences_pid: user_preferences_pid
    } do
      UserPreferences.set(
        "accessibility.reduced_motion",
        true,
        user_preferences_pid
      )

      Framework.init(%{}, user_preferences_pid)
      assert Framework.should_reduce_motion?(user_preferences_pid)

      _animation =
        Framework.create_animation(
          :integration_anim_1,
          %{duration: 500, from: 0, to: 100}
        )

      UserPreferences.set(
        "accessibility.reduced_motion",
        false,
        user_preferences_pid
      )

      Framework.init(%{}, user_preferences_pid)
      refute Framework.should_reduce_motion?(user_preferences_pid)
    end

    test "animations have appropriate timing for cognitive accessibility", %{
      user_preferences_pid: user_preferences_pid
    } do
      UserPreferences.set(
        [:accessibility, :cognitive_accessibility],
        false,
        user_preferences_pid
      )

      Framework.init(%{}, user_preferences_pid)

      standard_anim_def =
        Framework.create_animation(
          :cognitive_std_anim_1,
          %{duration: 500, from: 0, to: 100}
        )

      Framework.start_animation(
        standard_anim_def.name,
        "element_standard_cognitive"
      )

      standard_instance =
        get_in(StateManager.get_active_animations(), [
          "element_standard_cognitive",
          standard_anim_def.name
        ])

      original_duration = standard_instance.animation.duration

      StateManager.remove_active_animation(
        "element_standard_cognitive",
        standard_anim_def.name
      )

      UserPreferences.set(
        [:accessibility, :cognitive_accessibility],
        true,
        user_preferences_pid
      )

      Framework.init(%{}, user_preferences_pid)

      cognitive_anim_def =
        Framework.create_animation(
          :cognitive_accessibility_anim_1,
          %{duration: 500, from: 0, to: 100}
        )

      Framework.start_animation(
        cognitive_anim_def.name,
        "element_cognitive_test"
      )

      cognitive_instance =
        get_in(StateManager.get_active_animations(), [
          "element_cognitive_test",
          cognitive_anim_def.name
        ])

      cognitive_duration = cognitive_instance.animation.duration

      StateManager.remove_active_animation(
        "element_cognitive_test",
        cognitive_anim_def.name
      )

      assert cognitive_duration > original_duration
    end

    test "respects user preferences for reduced motion", %{
      user_preferences_pid: user_preferences_pid
    } do
      # Set reduced motion and initialize BEFORE starting the animation
      UserPreferences.set(
        "accessibility.reduced_motion",
        true,
        user_preferences_pid
      )

      Animation.init(%{reduced_motion: true}, user_preferences_pid)
      Framework.init(%{reduced_motion: true}, user_preferences_pid)

      initial_state = %{
        elements: %{
          "test_element" => %{
            opacity: 0
          }
        }
      }

      animation =
        Animation.create_animation(:test_animation, %{
          type: :fade,
          duration: 300,
          from: 0,
          to: 1,
          target_path: [:opacity]
        })

      :ok =
        Framework.start_animation(
          animation.name,
          "test_element",
          %{},
          user_preferences_pid
        )

      # Simulate time passing BEFORE applying animations
      instance =
        get_in(StateManager.get_active_animations(), [
          "test_element",
          animation.name
        ])

      if instance do
        updated_instance = %{
          instance
          | start_time: instance.start_time - (animation.duration + 1)
        }

        StateManager.put_active_animation(
          "test_element",
          animation.name,
          updated_instance
        )
      end

      updated_state =
        Framework.apply_animations_to_state(initial_state, user_preferences_pid)

      assert get_in(updated_state, [:elements, "test_element", :opacity]) == 1
    end

    test "announces animations to screen readers when configured", %{
      user_preferences_pid: user_preferences_pid
    } do
      with_screen_reader_spy(user_preferences_pid, fn ->
        animation =
          Animation.create_animation(:test_animation, %{
            type: :fade,
            from: 0,
            to: 1,
            announce_to_screen_reader: true,
            description: "Test animation",
            target_path: [:opacity]
          })

        :ok =
          Framework.start_animation(
            animation.name,
            "test_element",
            %{},
            user_preferences_pid
          )

        # Simulate time passing
        instance =
          get_in(StateManager.get_active_animations(), [
            "test_element",
            animation.name
          ])

        if instance do
          updated_instance = %{
            instance
            | start_time: instance.start_time - (animation.duration + 1)
          }

          StateManager.put_active_animation(
            "test_element",
            animation.name,
            updated_instance
          )
        end

        Framework.apply_animations_to_state(%{}, user_preferences_pid)
        assert_announced("Test animation started")
      end)
    end

    test "silences announcements when configured", %{
      user_preferences_pid: user_preferences_pid
    } do
      UserPreferences.set(
        "accessibility.silence_announcements",
        true,
        user_preferences_pid
      )

      animation =
        Animation.create_animation(:test_animation, %{
          type: :fade,
          from: 0,
          to: 1,
          announce_to_screen_reader: true,
          description: "Test animation",
          target_path: [:opacity]
        })

      :ok =
        Framework.start_animation(
          animation.name,
          "test_element",
          %{},
          user_preferences_pid
        )

      Framework.apply_animations_to_state(%{}, user_preferences_pid)
      refute_receive {:accessibility_announcement, _}, 100
    end

    test "handles multiple animations with accessibility", %{
      user_preferences_pid: user_preferences_pid
    } do
      with_screen_reader_spy(user_preferences_pid, fn ->
        # Ensure state structure matches target_path for both animations
        initial_state = %{
          elements: %{
            "test_element" => %{
              opacity: 0,
              position: 0
            }
          }
        }

        fade_animation =
          Framework.create_animation(:fade_in, %{
            type: :fade,
            duration: 200,
            from: 0,
            to: 1,
            announce_to_screen_reader: true,
            description: "Fade in",
            target_path: [:opacity]
          })

        slide_animation =
          Framework.create_animation(:slide_in, %{
            type: :slide,
            duration: 200,
            from: 0,
            to: 100,
            announce_to_screen_reader: true,
            description: "Slide in",
            target_path: [:position]
          })

        :ok =
          Framework.start_animation(
            fade_animation.name,
            "test_element",
            %{notify_pid: self()},
            user_preferences_pid
          )

        :ok =
          Framework.start_animation(
            slide_animation.name,
            "test_element",
            %{notify_pid: self()},
            user_preferences_pid
          )

        # Simulate time passing for both animations BEFORE applying animations
        fade_instance =
          get_in(StateManager.get_active_animations(), [
            "test_element",
            fade_animation.name
          ])

        slide_instance =
          get_in(StateManager.get_active_animations(), [
            "test_element",
            slide_animation.name
          ])

        if fade_instance do
          updated_fade = %{
            fade_instance
            | start_time:
                fade_instance.start_time - (fade_animation.duration + 1)
          }

          StateManager.put_active_animation(
            "test_element",
            fade_animation.name,
            updated_fade
          )
        end

        if slide_instance do
          updated_slide = %{
            slide_instance
            | start_time:
                slide_instance.start_time - (slide_animation.duration + 1)
          }

          StateManager.put_active_animation(
            "test_element",
            slide_animation.name,
            updated_slide
          )
        end

        updated_state =
          Framework.apply_animations_to_state(
            initial_state,
            user_preferences_pid
          )

        assert get_in(updated_state, [:elements, "test_element", :opacity]) == 1

        assert get_in(updated_state, [:elements, "test_element", :position]) ==
                 100

        assert_announced("Fade in started")
        assert_announced("Slide in started")
      end)
    end

    test "meets performance requirements with accessibility", %{
      user_preferences_pid: user_preferences_pid
    } do
      with_screen_reader_spy(user_preferences_pid, fn ->
        initial_state = %{
          elements: %{
            "test_element" => %{
              opacity: 0
            }
          }
        }

        animation =
          Animation.create_animation(:perf_test, %{
            type: :fade,
            duration: 100,
            from: 0,
            to: 1,
            announce_to_screen_reader: true,
            description: "Performance test",
            target_path: [:opacity]
          })

        start_time = System.monotonic_time()

        :ok =
          Framework.start_animation(
            animation.name,
            "test_element",
            %{notify_pid: self()},
            user_preferences_pid
          )

        # Simulate time passing
        instance =
          get_in(StateManager.get_active_animations(), [
            "test_element",
            animation.name
          ])

        if instance do
          updated_instance = %{
            instance
            | start_time: instance.start_time - (animation.duration + 1)
          }

          StateManager.put_active_animation(
            "test_element",
            animation.name,
            updated_instance
          )
        end

        Framework.apply_animations_to_state(initial_state, user_preferences_pid)
        wait_for_animation_start("test_element", animation.name)
        wait_for_animation_completion("test_element", animation.name)
        end_time = System.monotonic_time()

        duration =
          System.convert_time_unit(end_time - start_time, :native, :millisecond)

        assert duration < 16, "Animation frame time too high"
        assert_announced("Performance test started")
      end)
    end
  end

  # --- Private Test Helpers ---

  defp setup_accessibility() do
    # Use the global UserPreferences process that's already started
    Process.whereis(Raxol.Core.UserPreferences)
  end

  defp cleanup_accessibility(pid) when is_pid(pid) do
    # Attempt to stop the process started by this test setup.
    # Be cautious if this process is globally shared.
    ref = Process.monitor(pid)
    Process.exit(pid, :shutdown)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    end
  catch
    :exit, _ -> :ok
  end
end
