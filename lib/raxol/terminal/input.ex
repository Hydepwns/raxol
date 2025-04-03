defmodule Raxol.Terminal.Input do
  @moduledoc """
  Input processing module for handling keyboard and mouse events.
  
  This module provides functionality for:
  - Keyboard input handling
  - Mouse input support
  - Input event system
  - Input buffering
  - Input validation
  """

  @type key_event :: {:key, key :: atom, modifiers :: list(atom)}
  @type mouse_event :: {:mouse, x :: integer, y :: integer, button :: atom, modifiers :: list(atom)}
  @type event :: key_event | mouse_event

  @doc """
  Processes raw input data and returns a list of events.
  """
  def process_input(data) do
    case parse_input(data) do
      {:key, key} -> [{:key, key, []}]
      {:mouse, x, y, button} -> [{:mouse, x, y, button, []}]
      {:unknown, _} -> []
    end
  end

  @doc """
  Buffers input events for processing.
  """
  def buffer_events(events, buffer \\ []) do
    Enum.reduce(events, buffer, fn event, acc ->
      case event do
        {:key, _, _} -> [event | acc]
        {:mouse, _, _, _, _} -> [event | acc]
        _ -> acc
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Validates an input event.
  """
  def validate_event(event) do
    case event do
      {:key, key, modifiers} when is_atom(key) and is_list(modifiers) ->
        {:ok, event}
      
      {:mouse, x, y, button, modifiers} 
        when is_integer(x) and is_integer(y) and is_atom(button) and is_list(modifiers) ->
        {:ok, event}
      
      _ ->
        {:error, :invalid_event}
    end
  end

  # Private functions

  defp parse_input(<<?\e, rest::binary>>) do
    case rest do
      <<"[", rest::binary>> ->
        parse_escape_sequence(rest)
      
      <<"O", rest::binary>> ->
        parse_function_key(rest)
      
      _ ->
        {:unknown, rest}
    end
  end

  defp parse_input(<<char::utf8, _::binary>>) do
    {:key, char}
  end

  defp parse_input(_), do: {:unknown, ""}

  defp parse_escape_sequence(sequence) do
    case sequence do
      <<x::binary-1, ";", y::binary-1, "M", _::binary>> ->
        {x, _} = Integer.parse(x)
        {y, _} = Integer.parse(y)
        {:mouse, x, y, :left}
      
      <<x::binary-1, ";", y::binary-1, "m", _::binary>> ->
        {x, _} = Integer.parse(x)
        {y, _} = Integer.parse(y)
        {:mouse, x, y, :release}
      
      <<"A", _::binary>> -> {:key, :up}
      <<"B", _::binary>> -> {:key, :down}
      <<"C", _::binary>> -> {:key, :right}
      <<"D", _::binary>> -> {:key, :left}
      <<"H", _::binary>> -> {:key, :home}
      <<"F", _::binary>> -> {:key, :end}
      <<"2~", _::binary>> -> {:key, :insert}
      <<"3~", _::binary>> -> {:key, :delete}
      <<"5~", _::binary>> -> {:key, :page_up}
      <<"6~", _::binary>> -> {:key, :page_down}
      _ -> {:unknown, sequence}
    end
  end

  defp parse_function_key(sequence) do
    case sequence do
      <<"P", _::binary>> -> {:key, :f1}
      <<"Q", _::binary>> -> {:key, :f2}
      <<"R", _::binary>> -> {:key, :f3}
      <<"S", _::binary>> -> {:key, :f4}
      _ -> {:unknown, sequence}
    end
  end
end 