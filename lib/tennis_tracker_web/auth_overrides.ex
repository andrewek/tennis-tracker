defmodule TennisTrackerWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  alias AshAuthentication.Phoenix.Components

  override Components.Banner do
    set :image_url, nil
    set :dark_image_url, nil
    set :href_url, nil
    set :text, "Tennis Tracker"
    set :text_class, "text-3xl font-bold tracking-tight text-center"
  end
end
