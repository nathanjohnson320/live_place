defmodule LivePlaceWeb.PlaceLive.Show do
  use LivePlaceWeb, :live_view

  alias LivePlace.Places

  on_mount LivePlaceWeb.LiveAuth

  @colors Places.colors()
  @initial_pixel %{x: 0, y: 0, color: @colors.white}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Subscribe to place updates
    :ok = Phoenix.PubSub.subscribe(LivePlace.PubSub, id)
    {:ok, socket, layout: {LivePlaceWeb.LayoutView, "empty.html"}}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    place = Places.get_place!(id)

    {:noreply,
     socket
     |> assign(
       page_title: page_title(socket.assigns.live_action),
       place: place,
       show_overlay: false,
       selected_pixel: @initial_pixel
     )
     |> push_event("load_place", %{id: place.id, size: place.size})}
  end

  defp page_title(:show), do: "Show Place"
  defp page_title(:edit), do: "Edit Place"

  @impl true
  def handle_event(
        "select_pixel",
        %{"x" => x, "y" => y},
        %{assigns: %{selected_pixel: selected}} = socket
      ) do
    {:noreply,
     socket
     |> assign(show_overlay: true, selected_pixel: Map.merge(selected, %{x: x, y: y}))}
  end

  @impl true
  def handle_event("select_pixel", _params, socket) do
    {:noreply, socket |> assign(show_overlay: true)}
  end

  @impl true
  def handle_event(
        "confirm_placement",
        _params,
        %{assigns: %{place: place, selected_pixel: %{x: x, y: y, color: color}}} = socket
      ) do
    :ok = Places.Server.place_tile(place.id, {x, y}, color)

    {:noreply,
     socket
     |> assign(show_overlay: false)
     |> push_event("set_pixel", %{x: x, y: y, rgb: Places.color_to_rgb(color)})}
  end

  @impl true
  def handle_event("cancel_placement", _params, socket) do
    {:noreply, socket |> assign(show_overlay: false) |> push_event("clear_overlay", %{})}
  end

  @impl true
  def handle_event(
        "select_color",
        %{"color" => color},
        %{assigns: %{selected_pixel: selected}} = socket
      ) do
    color = Map.get(@colors, String.to_existing_atom(color), @colors.white)

    {:noreply,
     socket
     |> assign(selected_pixel: Map.merge(selected, %{color: color}))
     |> push_event("select_color", %{color: Places.color_to_rgb(color)})}
  end

  def color_style(hex), do: "background-color: ##{hex}"

  def active_color(%{color: selected_color}, color) when selected_color == color,
    do: "active-color"

  def active_color(_selected_pixel, _color), do: ""

  @impl true
  def handle_info({"update_pixels", pixels}, socket) do
    {:noreply, socket |> push_event("sync_pixels", pixels)}
  end
end
