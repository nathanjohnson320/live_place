defmodule LivePlace.Places do
  @moduledoc """
  The Places context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi

  alias LivePlace.Repo
  alias LivePlace.Places.{Grid, Place}
  alias LivePlace.Accounts.User

  @colors %{
    red: "FF4500",
    orange: "FFA800",
    yellow: "FFD635",
    dark_green: "00A368",
    light_green: "7EED56",
    dark_blue: "2450A4",
    blue: "369DEA",
    light_blue: "51E9F4",
    dark_purple: "811E9F",
    purple: "B44AC0",
    pink: "FF99AA",
    brown: "9C6926",
    black: "000000",
    gray: "898D90",
    light_gray: "D4D7D9",
    white: "FFFFFF"
  }

  @rgb %{
    "FF4500" => [255, 69, 0, 255],
    "FFA800" => [255, 168, 0, 255],
    "FFD635" => [255, 214, 53, 255],
    "00A368" => [0, 163, 104, 255],
    "7EED56" => [126, 237, 86, 255],
    "2450A4" => [36, 80, 164, 255],
    "369DEA" => [54, 157, 234, 255],
    "51E9F4" => [81, 233, 244, 255],
    "811E9F" => [129, 30, 159, 255],
    "B44AC0" => [180, 74, 192, 255],
    "FF99AA" => [255, 153, 170, 255],
    "9C6926" => [156, 105, 38, 255],
    "000000" => [0, 0, 0, 255],
    "898D90" => [137, 141, 144, 255],
    "D4D7D9" => [212, 215, 217, 255],
    "FFFFFF" => [255, 255, 255, 255]
  }

  def colors(), do: @colors

  @doc """
  Returns the list of places.

  ## Examples

      iex> list_places()
      [%Place{}, ...]

  """
  def list_places do
    Repo.all(Place)
  end

  @doc """
  Gets a single place.

  Raises `Ecto.NoResultsError` if the Place does not exist.

  ## Examples

      iex> get_place!(123)
      %Place{}

      iex> get_place!(456)
      ** (Ecto.NoResultsError)

  """
  def get_place!(id), do: Repo.get!(Place, id)

  def get_active_place!() do
    query =
      from(place in Place,
        where: place.active
      )

    Repo.one!(query)
  end

  def get_cached_place!(id), do: Cachex.get!(:places_cache, id)
  def get_cached_place_view!(id), do: Cachex.get!(:places_view_cache, id)

  @doc """
  Creates a place.

  ## Examples

      iex> create_place(%{field: value})
      {:ok, %Place{}}

      iex> create_place(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_place(%User{} = user, attrs \\ %{}) do
    Multi.new()
    |> Multi.insert(
      :place,
      %Place{user_id: user.id} |> Place.changeset(attrs)
    )
    |> Multi.insert(:grid, fn %{place: place} ->
      Grid.changeset(%Grid{place_id: place.id}, %{pixels: generate_grid(place.size)})
    end)
    |> Multi.run(:sync, fn _repo, %{place: place, grid: grid} ->
      boot_sync_server(%{place | grid: grid})
    end)
    |> Multi.run(:server, fn _repo, %{place: place, grid: grid} ->
      boot_place_server(%{place | grid: grid})
    end)
    |> Repo.transaction()
  end

  def render_place(place) do
    for {{x, y}, color} <- place do
      [x, y, color]
    end
  end

  def generate_grid(max \\ 1000) do
    for i <- Range.new(0, max - 1),
        j <- Range.new(0, max - 1),
        into: %{},
        do: {{i, j}, @colors.white}
  end

  def place_to_uint8array(place) do
    for x <- Range.new(0, place.size - 1),
        y <- Range.new(0, place.size - 1) do
      color_to_rgb(place.grid.pixels[{x, y}])
    end
  end

  def color_to_rgb(color), do: Map.get(@rgb, color)

  @doc """
  Updates a place.

  ## Examples

      iex> update_place(place, %{field: new_value})
      {:ok, %Place{}}

      iex> update_place(place, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_place(%Place{} = place, attrs) do
    place
    |> Place.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a place.

  ## Examples

      iex> delete_place(place)
      {:ok, %Place{}}

      iex> delete_place(place)
      {:error, %Ecto.Changeset{}}

  """
  def delete_place(%Place{} = place) do
    Multi.new()
    |> Multi.delete(:place, place)
    |> Multi.run(:terminate_sync, fn _repo, %{place: place} ->
      LivePlace.Places.Sync.shutdown(place.id)
    end)
    |> Multi.run(:terminate_server, fn _repo, %{place: place} ->
      LivePlace.Places.Server.shutdown(place.id)
    end)
    |> Repo.transaction()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking place changes.

  ## Examples

      iex> change_place(place)
      %Ecto.Changeset{data: %Place{}}

  """
  def change_place(%Place{} = place, attrs \\ %{}) do
    Place.changeset(place, attrs)
  end

  @doc ~S"""
  Startup all the genservers for each place
  """
  def load_places() do
    places =
      from(place in Place,
        join: grid in assoc(place, :grid),
        preload: [grid: grid]
      )
      |> Repo.all()

    # Should probably handle errors here. Oh well
    Enum.map(places, &boot_sync_server/1)
    Enum.map(places, &boot_place_server/1)
  end

  def boot_place_server(place) do
    DynamicSupervisor.start_child(LivePlace.DynamicSupervisor, {LivePlace.Places.Server, place})
  end

  def boot_sync_server(place) do
    DynamicSupervisor.start_child(LivePlace.DynamicSupervisor, {LivePlace.Places.Sync, place})
  end

  @doc """
  Returns the list of grids.

  ## Examples

      iex> list_grids()
      [%Grid{}, ...]

  """
  def list_grids do
    Repo.all(Grid)
  end

  @doc """
  Gets a single grid.

  Raises `Ecto.NoResultsError` if the Grid does not exist.

  ## Examples

      iex> get_grid!(123)
      %Grid{}

      iex> get_grid!(456)
      ** (Ecto.NoResultsError)

  """
  def get_grid!(id), do: Repo.get!(Grid, id)

  @doc """
  Creates a grid.

  ## Examples

      iex> create_grid(%{field: value})
      {:ok, %Grid{}}

      iex> create_grid(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_grid(attrs \\ %{}) do
    %Grid{}
    |> Grid.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a grid.

  ## Examples

      iex> update_grid(grid, %{field: new_value})
      {:ok, %Grid{}}

      iex> update_grid(grid, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_grid(%Grid{} = grid, attrs) do
    grid
    |> Grid.changeset(attrs)
    |> Repo.update()
  end

  def update_grid!(%Grid{} = grid, attrs) do
    grid
    |> Grid.changeset(attrs)
    |> Repo.update!()
  end

  @doc """
  Deletes a grid.

  ## Examples

      iex> delete_grid(grid)
      {:ok, %Grid{}}

      iex> delete_grid(grid)
      {:error, %Ecto.Changeset{}}

  """
  def delete_grid(%Grid{} = grid) do
    Repo.delete(grid)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking grid changes.

  ## Examples

      iex> change_grid(grid)
      %Ecto.Changeset{data: %Grid{}}

  """
  def change_grid(%Grid{} = grid, attrs \\ %{}) do
    Grid.changeset(grid, attrs)
  end
end
