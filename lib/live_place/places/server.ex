defmodule LivePlace.Places.Server do
  @moduledoc """
  Handles keeping track of the board and buffering requests to update it.
  The only thing that interacts with this directly should be the live views (to push new pixels)
  and the Sync to pull the buffer
  """
  use GenServer, restart: :transient

  # CLIENT FNs
  def place_tile(place_id, coordinates, color) do
    case lookup_server(place_id) do
      {:ok, pid} -> GenServer.cast(pid, {:update_color, coordinates, color})
      error -> error
    end
  end

  def shutdown(place_id) do
    case lookup_server(place_id) do
      {:ok, pid} -> GenServer.call(pid, :shutdown)
      error -> error
    end
  end

  @doc ~S"""
  get_and_clear_buffer returns the queue of pixels to process, empty on retrieve and maybe one
  day we'll add code to put it back on failure
  """
  def get_and_clear_buffer(place_id) do
    case lookup_server(place_id) do
      {:ok, pid} -> GenServer.call(pid, {:get, :buffer})
      error -> error
    end
  end

  def lookup_server(place_id) do
    case Registry.lookup(PlaceRegistry, place_id) do
      [{pid, _}] -> {:ok, pid}
      _ -> {:error, :not_found}
    end
  end

  # SERVER FNs
  @impl true
  def init(place) do
    {:ok, %{place: place, buffer: :queue.new()}}
  end

  @impl true
  def handle_call({:get, :place}, _from, state) do
    # Primarily for tests, returns pixel data from state
    {:reply, {:ok, state.place.grid.pixels}, state}
  end

  @impl true
  def handle_call({:get, :id}, _from, state) do
    # Primarily for tests, returns id from state
    {:reply, {:ok, state.place.id}, state}
  end

  @impl true
  def handle_call({:get, :buffer}, _from, state) do
    # returns the buffer, used by the sync
    {:reply, {:ok, state.buffer}, %{state | buffer: :queue.new()}}
  end

  @impl true
  def handle_call(:shutdown, _from, _state) do
    # Call that terminates the genserver
    {:stop, :normal, {:ok, nil}, nil}
  end

  @impl true
  def handle_cast({:update_color, coordinates, color}, state) do
    # Update the pixel in the grid, put the new coordinate in our buffer for the sync to use
    updated_state =
      state.place.grid.pixels[coordinates]
      |> put_in(color)
      |> Map.update!(:buffer, &:queue.in({coordinates, color}, &1))

    {:ok, _} = Cachex.put(:places_cache, updated_state.place.id, updated_state.place.grid.pixels)

    {:noreply, updated_state}
  end

  # Function needed for dynamic supervisor start_child
  def start_link(place) do
    GenServer.start_link(__MODULE__, place, name: server_name(place))
  end

  # Server name :via so we can lookup the place by its id inside the registry
  defp server_name(place), do: {:via, Registry, {PlaceRegistry, place.id}}
end
