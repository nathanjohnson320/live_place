defmodule LivePlace.Places.SyncTest do
  use LivePlace.DataCase

  alias LivePlace.Places
  alias LivePlace.Places.{Server, Sync}
  alias LivePlace.Repo

  import LivePlace.PlacesFixtures

  describe "sync" do
    test "should process the queue of updates into rgb pixels" do
      place = place_fixture() |> Repo.preload(:grid)

      Server.place_tile(place.id, {0, 0}, "FF4500")
      Server.place_tile(place.id, {1, 1}, "000000")
      {:ok, buffer} = Server.get_and_clear_buffer(place.id)

      assert Sync.process_queue(buffer) == [
               %{rgb: [0, 0, 0, 255], x: 1, y: 1},
               %{rgb: [255, 69, 0, 255], x: 0, y: 0}
             ]
    end

    test "tick should update caches, save to DB, and broadcast" do
      %{id: place_id} = place = place_fixture(%{size: 20}) |> Repo.preload(:grid)

      Phoenix.PubSub.subscribe(LivePlace.PubSub, place.id)

      Server.place_tile(place.id, {0, 0}, "FF4500")
      Server.place_tile(place.id, {1, 1}, "000000")

      [{sync, _}] = Registry.lookup(SyncRegistry, place.id)

      updated_view = [
        [255, 69, 0, 255],
        [255, 255, 255, 255],
        [255, 255, 255, 255],
        [0, 0, 0, 255]
      ]

      updated_pixels = %{
        {0, 0} => "FF4500",
        {0, 1} => "FFFFFF",
        {1, 0} => "FFFFFF",
        {1, 1} => "000000"
      }

      send(sync, :tick)

      assert_receive {"update_pixels",
                      %{
                        pixels: [
                          %{rgb: [0, 0, 0, 255], x: 1, y: 1},
                          %{rgb: [255, 69, 0, 255], x: 0, y: 0}
                        ]
                      }}

      assert [
               [255, 69, 0, 255],
               [255, 255, 255, 255],
               [255, 255, 255, 255],
               [0, 0, 0, 255] | _rest
             ] = Places.get_cached_place_view!(place_id)

      assert %{grid: %{pixels: ^updated_pixels}} =
               Repo.get!(LivePlace.Places.Place, place_id) |> Repo.preload(:grid)

      # Second tick should have no changes
      send(sync, :tick)

      refute_receive {"update_pixels", _}

      assert [
               [255, 69, 0, 255],
               [255, 255, 255, 255],
               [255, 255, 255, 255],
               [0, 0, 0, 255] | _rest
             ] = Places.get_cached_place_view!(place_id)

      assert %{grid: %{pixels: ^updated_pixels}} =
               Repo.get!(LivePlace.Places.Place, place_id) |> Repo.preload(:grid)
    end
  end
end
