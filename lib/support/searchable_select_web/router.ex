defmodule SearchableSelectWeb.Router do
  use SearchableSelectWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {SearchableSelectWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{"content-security-policy" => "default-src 'self'"}
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SearchableSelectWeb do
    pipe_through :browser

    live "/", ShowcaseLive
    live "/lc", LiveComponentTest
  end
end
