defmodule ExmeraldaWeb.AuthController do
  use ExmeraldaWeb, :controller

  alias Exmeralda.Accounts
  alias ExmeraldaWeb.UserAuth

  def request(conn, _params) do
    config = config(conn)

    {:ok, %{url: url, session_params: session_params}} =
      strategy().authorize_url(config)

    conn
    |> put_session(:session_params, session_params)
    |> redirect(external: url)
  end

  def callback(conn, params) do
    session_params =
      get_session(conn, :session_params)
      |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)

    config =
      conn
      |> config()
      |> Keyword.put(:session_params, session_params)

    with {:ok, %{user: user}} <- strategy().callback(config, params),
         {:ok, user} <-
           Accounts.upsert_user(%{
             github_id: user["sub"],
             github_profile: user["profile"],
             email: user["email"],
             name: user["name"],
             avatar_url: user["picture"]
           }) do
      conn
      |> put_flash(:info, "Signed in successfully!")
      |> UserAuth.log_in_user(user)
    else
      _ ->
        conn
        |> put_flash(:error, gettext("Authentication failed!"))
        |> redirect(to: ~p"/")
    end
  end

  def log_out(conn, _params) do
    UserAuth.log_out_user(conn)
  end

  defp config(conn) do
    Application.get_env(:exmeralda, strategy(), [])
    |> Keyword.put(:redirect_uri, url(conn, ~p"/auth/github/callback"))
  end

  defp strategy do
    Application.fetch_env!(:exmeralda, :auth_strategy)
  end
end
