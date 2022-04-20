defmodule LivePlace.Places.Sync do
  @moduledoc """
  GenServer that acts as a buffer for writing to the cachex cache and postgres DB
  Also handles the ticker for emitting changes on the socket.
  """
  use GenServer, restart: :transient

  alias LivePlace.Places
  alias LivePlace.Places.Server

  @interval :timer.seconds(10)

  def shutdown(place_id) do
    case lookup_server(place_id) do
      {:ok, pid} -> GenServer.call(pid, :shutdown)
      error -> error
    end
  end

  defp lookup_server(place_id) do
    case Registry.lookup(SyncRegistry, place_id) do
      [{pid, _}] -> {:ok, pid}
      _ -> {:error, :not_found}
    end
  end

  @impl true
  def handle_call(:shutdown, _from, _state) do
    {:stop, :normal, {:ok, nil}, nil}
  end

  @impl true
  def handle_info(:tick, %{place: place, grid: grid} = state) do
    pixels = Places.get_cached_place!(place.id)

    [_broadcast, _cached_view, updated_grid] =
      [
        Task.async(fn ->
          # Processing the queue transforms pixels to uint8 and then broadcasts them to the place endpoint
          # We could also do the transformation in the server to rgb before the buffer insert idk
          place.id
          |> Server.get_and_clear_buffer()
          |> process_queue()
          |> broadcast_buffer(place)
        end),
        Task.async(fn ->
          # Cache the view data
          Cachex.put(
            :places_view_cache,
            place.id,
            Places.place_to_uint8array(Map.put(place, :grid, %{pixels: pixels}))
          )
        end),
        Task.async(fn ->
          # Save grid to DB
          Places.update_grid!(grid, %{pixels: pixels})
        end)
      ]
      |> Task.await_many()

    Process.send_after(self(), :tick, @interval)
    {:noreply, %{state | grid: updated_grid}}
  end

  def process_queue(queue, new_buffer \\ []) do
    case :queue.out(queue) do
      {{:value, {{x, y}, color}}, queue} ->
        process_queue(queue, [%{x: x, y: y, rgb: Places.color_to_rgb(color)} | new_buffer])

      {:empty, _queue} ->
        new_buffer
    end
  end

  def broadcast_buffer([], _place), do: :no_op

  def broadcast_buffer(buffer, place) do
    Phoenix.PubSub.broadcast!(LivePlace.PubSub, place.id, {"update_pixels", %{pixels: buffer}})
  end

  @impl true
  def init(place) do
    # Cache the initial data
    {:ok, _} = Cachex.put(:places_cache, place.id, place.grid.pixels)

    {:ok, _} = Cachex.put(:places_view_cache, place.id, Places.place_to_uint8array(place))

    # Start the process loop to update
    Process.send_after(self(), :tick, :timer.seconds(1))
    {:ok, %{place: Map.delete(place, :grid), grid: place.grid}}
  end

  def start_link(place) do
    GenServer.start_link(__MODULE__, place, name: server_name(place))
  end

  defp server_name(place), do: {:via, Registry, {SyncRegistry, place.id}}
end
