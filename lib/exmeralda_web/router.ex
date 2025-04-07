defmodule ExmeraldaWeb.Router do
  use ExmeraldaWeb, :router

  import ExmeraldaWeb.UserAuth
  import Oban.Web.Router

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

    live "/terms", UserLive.Terms
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
      on_mount: [
        {ExmeraldaWeb.UserAuth, :ensure_authenticated}
      ] do
      live "/accept_terms", UserLive.AcceptTerms
      live "/auth/settings", UserLive.Settings, :edit
    end
  end

  scope "/", ExmeraldaWeb do
    pipe_through [:browser, :require_authenticated_user, :require_terms]

    live_session :require_authenticated_user_with_terms,
      on_mount: [
        {ExmeraldaWeb.UserAuth, :ensure_authenticated},
        {ExmeraldaWeb.UserAuth, :ensure_terms}
      ] do
      live "/chat/start", ChatLive.Index, :new
      live "/chat/:id", ChatLive.Index, :show
      live "/library/new", LibraryLive.Index, :new
    end
  end

  scope "/", ExmeraldaWeb do
    pipe_through [:browser, :admin_auth]

    oban_dashboard("/oban")

    scope "/admin", Admin do
      live_session :require_admin_authenticated_user,
        on_mount: [{ExmeraldaWeb.UserAuth, :ensure_authenticated}] do
        live "/", LibraryLive.Index, :index
        live "/library/:id", LibraryLive.Show, :show
      end
    end
  end

  defp admin_auth(conn, _opts) do
    if admin_auth = Application.get_env(:exmeralda, :admin_auth) do
      Plug.BasicAuth.basic_auth(conn, admin_auth)
    else
      conn
    end
  end
end
