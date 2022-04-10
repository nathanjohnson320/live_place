defmodule LivePlace.Places.ServerTest do
  use LivePlace.DataCase

  alias LivePlace.Places.Server

  import LivePlace.AccountsFixtures

  describe "server" do
    test "should boot a server with place data and id" do
      user = user_fixture()

      {:ok, %{place: place, server: server}} =
        LivePlace.Places.create_place(user, %{name: "test"})

      assert GenServer.call(server, {:get, :id}) == {:ok, place.id}

      assert GenServer.call(server, {:get, :place}) ==
               {:ok,
                %{{1, 1} => "FFFFFF", {0, 0} => "FFFFFF", {0, 1} => "FFFFFF", {1, 0} => "FFFFFF"}}
    end

    test "places colors on the board" do
      user = user_fixture()

      {:ok, %{place: place, server: server}} =
        LivePlace.Places.create_place(user, %{size: 2, name: "test"})

      assert Server.place_tile(place.id, {1, 1}, "FF0000") == :ok

      assert GenServer.call(server, {:get, :place}) ==
               {:ok,
                %{{1, 1} => "FF0000", {0, 0} => "FFFFFF", {0, 1} => "FFFFFF", {1, 0} => "FFFFFF"}}
    end

    test "should terminate a server when told to shutdown" do
      user = user_fixture()
      {:ok, %{server: server}} = LivePlace.Places.create_place(user, %{name: "test"})

      assert GenServer.call(server, :shutdown) == {:ok, nil}
      refute Process.alive?(server)
    end
  end
end
