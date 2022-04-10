defmodule LivePlaceWeb.PageControllerTest do
  use LivePlaceWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Log in"
  end
end
