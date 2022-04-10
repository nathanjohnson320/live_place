defmodule LivePlace.PlacesTest do
  use LivePlace.DataCase

  alias LivePlace.Places

  describe "places" do
    alias LivePlace.Places.Place

    import LivePlace.PlacesFixtures
    import LivePlace.AccountsFixtures

    @invalid_attrs %{size: nil}

    test "list_places/0 returns all places" do
      place = place_fixture()
      assert Places.list_places() == [place]
    end

    test "get_place!/1 returns the place with given id" do
      place = place_fixture()
      assert Places.get_place!(place.id) == place
    end

    test "create_place/1 with valid data creates a place and starts the server" do
      user = user_fixture()
      valid_attrs = %{size: 2, name: "Test"}

      assert {:ok, %{grid: grid, place: %Place{}, server: server}} =
               Places.create_place(user, valid_attrs)

      assert grid.pixels == Places.generate_grid(2)
      assert is_pid(server)
    end

    test "create_place/1 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, :place, %Ecto.Changeset{}, _} = Places.create_place(user, @invalid_attrs)
    end

    test "update_place/2 with valid data updates the place" do
      new_user = LivePlace.AccountsFixtures.user_fixture()
      place = place_fixture()

      update_attrs = %{user_id: new_user.id}

      assert {:ok, %Place{} = place} = Places.update_place(place, update_attrs)
      assert place.user_id == new_user.id
    end

    test "update_place/2 with invalid data returns error changeset" do
      place = place_fixture()
      assert {:error, %Ecto.Changeset{}} = Places.update_place(place, @invalid_attrs)
      assert place == Places.get_place!(place.id)
    end

    test "delete_place/1 deletes the place and shuts down server" do
      place = place_fixture()
      [{server, _}] = Registry.lookup(PlaceRegistry, place.id)

      assert {:ok, %{place: %Place{}}} = Places.delete_place(place)
      assert_raise Ecto.NoResultsError, fn -> Places.get_place!(place.id) end
      refute Process.alive?(server)
    end

    test "change_place/1 returns a place changeset" do
      place = place_fixture()
      assert %Ecto.Changeset{} = Places.change_place(place)
    end

    test "load_places/0 starts all servers" do
      for _i <- 1..3 do
        place = place_fixture()
        [{pid, _}] = Registry.lookup(PlaceRegistry, place.id)
        assert is_pid(pid)
        Process.exit(pid, :shutdown)
        refute Process.alive?(pid)
      end

      assert [server1, server2, server3] = Places.load_places() |> Enum.map(&elem(&1, 1))
      assert Process.alive?(server1)
      assert Process.alive?(server2)
      assert Process.alive?(server3)
    end
  end

  describe "grids" do
    alias LivePlace.Places.Grid

    import LivePlace.PlacesFixtures

    @invalid_attrs %{pixels: nil}

    test "list_grids/0 returns all grids" do
      grid = grid_fixture()
      assert Places.list_grids() == [grid]
    end

    test "get_grid!/1 returns the grid with given id" do
      grid = grid_fixture()
      assert Places.get_grid!(grid.id) == grid
    end

    test "create_grid/1 with valid data creates a grid" do
      valid_attrs = %{pixels: "some pixels"}

      assert {:ok, %Grid{} = grid} = Places.create_grid(valid_attrs)
      assert grid.pixels == "some pixels"
    end

    test "create_grid/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Places.create_grid(@invalid_attrs)
    end

    test "update_grid/2 with valid data updates the grid" do
      grid = grid_fixture()
      update_attrs = %{pixels: "some updated pixels"}

      assert {:ok, %Grid{} = grid} = Places.update_grid(grid, update_attrs)
      assert grid.pixels == "some updated pixels"
    end

    test "update_grid/2 with invalid data returns error changeset" do
      grid = grid_fixture()
      assert {:error, %Ecto.Changeset{}} = Places.update_grid(grid, @invalid_attrs)
      assert grid == Places.get_grid!(grid.id)
    end

    test "delete_grid/1 deletes the grid" do
      grid = grid_fixture()
      assert {:ok, %Grid{}} = Places.delete_grid(grid)
      assert_raise Ecto.NoResultsError, fn -> Places.get_grid!(grid.id) end
    end

    test "change_grid/1 returns a grid changeset" do
      grid = grid_fixture()
      assert %Ecto.Changeset{} = Places.change_grid(grid)
    end
  end
end
