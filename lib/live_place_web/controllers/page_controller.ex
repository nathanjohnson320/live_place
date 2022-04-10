defmodule LivePlaceWeb.PageController do
  use LivePlaceWeb, :controller

  alias LivePlace.Places

  def index(conn, _params) do
    place = Places.get_active_place!()

    conn |> redirect(to: Routes.place_show_path(conn, :show, place))
  end
end
