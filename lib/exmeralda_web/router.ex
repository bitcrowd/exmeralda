defmodule ExmeraldaWeb.Router do
  use ExmeraldaWeb, :router

  import ExmeraldaWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExmeraldaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  if Application.compile_env(:exmeralda, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ExmeraldaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  scope "/", ExmeraldaWeb do
    pipe_through :browser

    delete "/auth/log_out", AuthController, :log_out
  end

  scope "/", ExmeraldaWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/auth/github", AuthController, :request
    get "/auth/github/callback", AuthController, :callback

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{ExmeraldaWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/", UserLive.Login, :new
    end
  end

  scope "/", ExmeraldaWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{ExmeraldaWeb.UserAuth, :ensure_authenticated}] do
      live "/chat/start", ChatLive.Index, :new
      live "/chat/:id", ChatLive.Index, :show
      live "/auth/settings", UserLive.Settings, :edit
    end
  end
end
