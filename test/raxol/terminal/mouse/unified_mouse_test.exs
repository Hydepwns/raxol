defmodule Raxol.Terminal.Mouse.UnifiedMouseTest do
  use ExUnit.Case
  alias Raxol.Terminal.Mouse.UnifiedMouse

  setup do
    {:ok, _pid} = UnifiedMouse.start_link()
    :ok
  end

  describe "mouse creation" do
    test 'creates mouse context with default configuration' do
      assert {:ok, mouse_id} = UnifiedMouse.create_mouse()
      assert {:ok, mouse_state} = UnifiedMouse.get_mouse_state(mouse_id)
      assert mouse_state.config.tracking == :all
      assert mouse_state.config.sgr_mode == true
      assert mouse_state.config.urxvt_mode == false
      assert mouse_state.config.pixel_mode == false
    end

    test 'creates mouse context with custom configuration' do
      config = %{
        tracking: :button,
        sgr_mode: false,
        urxvt_mode: true,
        pixel_mode: true
      }

      assert {:ok, mouse_id} = UnifiedMouse.create_mouse(config)
      assert {:ok, mouse_state} = UnifiedMouse.get_mouse_state(mouse_id)
      assert mouse_state.config.tracking == :button
      assert mouse_state.config.sgr_mode == false
      assert mouse_state.config.urxvt_mode == true
      assert mouse_state.config.pixel_mode == true
    end

    test 'first mouse context becomes active' do
      assert {:ok, mouse_id} = UnifiedMouse.create_mouse()
      assert {:ok, active_id} = UnifiedMouse.get_active_mouse()
      assert mouse_id == active_id
    end
  end

  describe "mouse management" do
    test 'gets list of all mouse contexts' do
      assert {:ok, mouse1} = UnifiedMouse.create_mouse()
      assert {:ok, mouse2} = UnifiedMouse.create_mouse()
      assert {:ok, mouse3} = UnifiedMouse.create_mouse()

      mice = UnifiedMouse.get_mice()
      assert length(mice) == 3
      assert mouse1 in mice
      assert mouse2 in mice
      assert mouse3 in mice
    end

    test 'sets active mouse context' do
      assert {:ok, mouse1} = UnifiedMouse.create_mouse()
      assert {:ok, mouse2} = UnifiedMouse.create_mouse()

      assert :ok = UnifiedMouse.set_active_mouse(mouse2)
      assert {:ok, active_id} = UnifiedMouse.get_active_mouse()
      assert active_id == mouse2
    end

    test 'handles non-existent mouse context' do
      assert {:error, :mouse_not_found} = UnifiedMouse.set_active_mouse(999)
      assert {:error, :mouse_not_found} = UnifiedMouse.get_mouse_state(999)
    end
  end

  describe "mouse operations" do
    test 'processes mouse event' do
      assert {:ok, mouse_id} = UnifiedMouse.create_mouse()

      event = %{
        button: :left,
        action: :press,
        modifiers: [:shift],
        x: 100,
        y: 200
      }

      assert :ok = UnifiedMouse.process_mouse_event(mouse_id, event)
      assert {:ok, mouse_state} = UnifiedMouse.get_mouse_state(mouse_id)
      assert mouse_state.position == {100, 200}
      assert mouse_state.button_state == %{left: :pressed}
      assert mouse_state.modifiers == [:shift]
    end

    test 'gets mouse position' do
      assert {:ok, mouse_id} = UnifiedMouse.create_mouse()

      event = %{
        button: :left,
        action: :press,
        modifiers: [],
        x: 150,
        y: 250
      }

      assert :ok = UnifiedMouse.process_mouse_event(mouse_id, event)
      assert {:ok, {150, 250}} = UnifiedMouse.get_mouse_position(mouse_id)
    end

    test 'gets mouse button state' do
      assert {:ok, mouse_id} = UnifiedMouse.create_mouse()

      event = %{
        button: :right,
        action: :press,
        modifiers: [],
        x: 100,
        y: 200
      }

      assert :ok = UnifiedMouse.process_mouse_event(mouse_id, event)
      assert {:ok, button_state} = UnifiedMouse.get_mouse_button_state(mouse_id)
      assert button_state == %{right: :pressed}
    end

    test 'closes mouse context' do
      assert {:ok, mouse_id} = UnifiedMouse.create_mouse()
      assert :ok = UnifiedMouse.close_mouse(mouse_id)
      assert {:error, :mouse_not_found} = UnifiedMouse.get_mouse_state(mouse_id)
    end

    test 'closing active mouse updates active mouse' do
      assert {:ok, mouse1} = UnifiedMouse.create_mouse()
      assert {:ok, mouse2} = UnifiedMouse.create_mouse()

      assert :ok = UnifiedMouse.set_active_mouse(mouse1)
      assert :ok = UnifiedMouse.close_mouse(mouse1)
      assert {:ok, active_id} = UnifiedMouse.get_active_mouse()
      assert active_id == mouse2
    end
  end

  describe "mouse configuration" do
    test 'updates mouse configuration' do
      assert {:ok, mouse_id} = UnifiedMouse.create_mouse()

      new_config = %{
        tracking: :drag,
        sgr_mode: false,
        urxvt_mode: true
      }

      assert :ok = UnifiedMouse.update_mouse_config(mouse_id, new_config)
      assert {:ok, mouse_state} = UnifiedMouse.get_mouse_state(mouse_id)
      assert mouse_state.config.tracking == :drag
      assert mouse_state.config.sgr_mode == false
      assert mouse_state.config.urxvt_mode == true
    end

    test 'updates mouse manager configuration' do
      config = %{
        max_mice: 5,
        default_tracking: :drag,
        default_sgr_mode: false,
        default_urxvt_mode: true,
        default_pixel_mode: true
      }

      assert :ok = UnifiedMouse.update_config(config)
    end
  end

  describe "cleanup" do
    test 'cleans up all mouse contexts' do
      assert {:ok, mouse1} = UnifiedMouse.create_mouse()
      assert {:ok, mouse2} = UnifiedMouse.create_mouse()

      assert :ok = UnifiedMouse.cleanup()
      assert UnifiedMouse.get_mice() == []
      assert {:error, :no_active_mouse} = UnifiedMouse.get_active_mouse()
    end
  end

  describe "error handling" do
    test 'handles invalid mouse operations' do
      assert {:error, :mouse_not_found} = UnifiedMouse.set_active_mouse(999)
      assert {:error, :mouse_not_found} = UnifiedMouse.get_mouse_state(999)

      assert {:error, :mouse_not_found} =
               UnifiedMouse.update_mouse_config(999, %{})

      assert {:error, :mouse_not_found} = UnifiedMouse.close_mouse(999)

      assert {:error, :mouse_not_found} =
               UnifiedMouse.process_mouse_event(999, %{})

      assert {:error, :mouse_not_found} = UnifiedMouse.get_mouse_position(999)

      assert {:error, :mouse_not_found} =
               UnifiedMouse.get_mouse_button_state(999)
    end
  end
end
