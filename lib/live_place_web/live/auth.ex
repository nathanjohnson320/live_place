defmodule LivePlaceWeb.LiveAuth do
  import Phoenix.LiveView

  alias LivePlace.Accounts
  alias LivePlaceWeb.Router.Helpers, as: Routes

  def on_mount(:default, _params, %{"user_token" => token} = _session, socket) do
    socket =
      assign_new(socket, :current_user, fn ->
        Accounts.get_user_by_session_token(token)
      end)

    if Map.get(socket.assigns, :current_user) &&
         Map.get(socket.assigns.current_user, :confirmed_at) do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must confirm your account before accessing this page")
       |> redirect(to: Routes.user_confirmation_path(socket, :new))}
    end
  end

  def on_mount(:default, _params, _session, socket) do
    {:halt,
     socket
     |> put_flash(:error, "You must login before accessing this page")
     |> redirect(to: Routes.user_session_path(socket, :new))}
  end
end
