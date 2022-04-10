defmodule LivePlaceWeb.Controllers.PlaceController do
  use LivePlaceWeb, :controller

  alias LivePlace.Places

  def show(conn, %{"id" => id}) do
    send_resp(conn, 200, Places.get_cached_place_view!(id))
  end
end
