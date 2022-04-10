defmodule LivePlace.PlacesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LivePlace.Places` context.
  """

  @doc """
  Generate a place.
  """
  def place_fixture(attrs \\ %{}) do
    user = LivePlace.AccountsFixtures.user_fixture()

    attrs =
      Enum.into(attrs, %{
        name: "test",
        size: 2
      })

    {:ok, %{place: place}} = LivePlace.Places.create_place(user, attrs)

    place
  end

  @doc """
  Generate a grid.
  """
  def grid_fixture(attrs \\ %{}) do
    {:ok, grid} =
      attrs
      |> Enum.into(%{
        pixels: "some pixels"
      })
      |> LivePlace.Places.create_grid()

    grid
  end
end
