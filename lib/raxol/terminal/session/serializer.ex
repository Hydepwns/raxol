defmodule Raxol.Terminal.Session.Serializer do
  @moduledoc """
  Handles serialization and deserialization of terminal session state.
  """

  alias Raxol.Terminal.{Session, Emulator, Renderer, ScreenBuffer}
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  @doc """
  Serializes a session state to a map that can be stored and later restored.
  """
  @spec serialize(Session.t()) :: map()
  def serialize(%Session{} = session) do
    %{
      id: session.id,
      width: session.width,
      height: session.height,
      title: session.title,
      theme: session.theme,
      emulator: serialize_emulator(session.emulator),
      renderer: serialize_renderer(session.renderer)
    }
  end

  @doc """
  Deserializes a session state from a map.
  """
  @spec deserialize(map()) :: {:ok, Session.t()} | {:error, term()}
  def deserialize(%{
        id: id,
        width: width,
        height: height,
        title: title,
        theme: theme,
        emulator: emulator_data,
        renderer: renderer_data
      }) do
    with {:ok, emulator} <- deserialize_emulator(emulator_data),
         {:ok, renderer} <- deserialize_renderer(renderer_data) do
      session = %Session{
        id: id,
        width: width,
        height: height,
        title: title,
        theme: theme,
        emulator: emulator,
        renderer: renderer
      }

      {:ok, session}
    end
  end

  def deserialize(_invalid_data), do: {:error, :invalid_session_data}

  # Private functions for serializing/deserializing components

  defp serialize_emulator(%EmulatorStruct{} = emulator) do
    %{
      active_buffer_type: emulator.active_buffer_type,
      main_screen_buffer: serialize_screen_buffer(emulator.main_screen_buffer),
      alternate_screen_buffer: serialize_screen_buffer(emulator.alternate_screen_buffer),
      scrollback_limit: emulator.scrollback_limit
    }
  end

  defp serialize_renderer(%Renderer{} = renderer) do
    %{
      screen_buffer: serialize_screen_buffer(renderer.screen_buffer),
      theme: renderer.theme
    }
  end

  defp serialize_screen_buffer(%ScreenBuffer{} = buffer) do
    %{
      width: buffer.width,
      height: buffer.height,
      cells: buffer.cells,
      cursor: buffer.cursor
    }
  end

  defp deserialize_emulator(%{
         active_buffer_type: active_buffer_type,
         main_screen_buffer: main_buffer_data,
         alternate_screen_buffer: alt_buffer_data,
         scrollback_limit: scrollback_limit
       }) do
    with {:ok, main_buffer} <- deserialize_screen_buffer(main_buffer_data),
         {:ok, alt_buffer} <- deserialize_screen_buffer(alt_buffer_data) do
      emulator = %EmulatorStruct{
        active_buffer_type: active_buffer_type,
        main_screen_buffer: main_buffer,
        alternate_screen_buffer: alt_buffer,
        scrollback_limit: scrollback_limit
      }

      {:ok, emulator}
    end
  end

  defp deserialize_renderer(%{screen_buffer: buffer_data, theme: theme}) do
    with {:ok, buffer} <- deserialize_screen_buffer(buffer_data) do
      renderer = %Renderer{
        screen_buffer: buffer,
        theme: theme
      }

      {:ok, renderer}
    end
  end

  defp deserialize_screen_buffer(%{
         cells: cells,
         scrollback: scrollback,
         scrollback_limit: scrollback_limit,
         selection: selection,
         scroll_region: scroll_region,
         width: width,
         height: height
       }) do
    screen_buffer = %ScreenBuffer{
      cells: cells,
      scrollback: scrollback,
      scrollback_limit: scrollback_limit,
      selection: selection,
      scroll_region: scroll_region,
      width: width,
      height: height
    }

    {:ok, screen_buffer}
  end
end
