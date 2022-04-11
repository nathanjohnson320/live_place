defmodule LivePlaceWeb.PageController do
  use LivePlaceWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
