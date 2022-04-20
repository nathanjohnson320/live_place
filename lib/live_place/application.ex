defmodule LivePlace.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      LivePlace.Repo,
      # Start the Telemetry supervisor
      LivePlaceWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: LivePlace.PubSub},
      # Start the Endpoint (http/https)
      LivePlaceWeb.Endpoint,
      Supervisor.child_spec({Cachex, name: :places_cache}, id: :places_cache),
      Supervisor.child_spec({Cachex, name: :places_view_cache}, id: :places_view_cache),
      {Registry, keys: :unique, name: PlaceRegistry},
      {Registry, keys: :unique, name: SyncRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: LivePlace.DynamicSupervisor}

      # Start a worker by calling: LivePlace.Worker.start_link(arg)
      # {LivePlace.Worker, arg}
    ]

    children =
      if env() != "test" do
        children ++ [Task.child_spec(&LivePlace.Places.load_places/0)]
      else
        children
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LivePlace.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LivePlaceWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def env(), do: System.get_env("MIX_ENV")
end
