defmodule ExmeraldaWeb.AuthController do
  use ExmeraldaWeb, :controller

  alias Assent.Strategy.Github

  def request(conn, _params) do
    {:ok, %{url: url, session_params: session_params}} =
      conn
      |> config()
      |> Github.authorize_url()

    conn
    |> put_session(:session_params, session_params)
    |> redirect(external: url)
  end

  def callback(conn, params) do
    session_params = get_session(conn, :session_params)

    conn
    |> config()
    |> Keyword.put(:session_params, session_params)
    |> Github.callback(params)
    |> case do
      {:ok, %{user: user_info} = ret} ->
        conn
        |> put_session(:user, user_info)
        |> put_flash(:info, "Signed in successfully! #{inspect(ret)}")
        |> redirect(to: "/")

      {:error, reason} ->
        conn
        |> put_flash(:error, gettext("Authentication failed"))
        |> redirect(to: "/")
    end
  end

  defp config(conn) do
    Application.fetch_env!(:exmeralda, :github)
    |> Keyword.put(:redirect_uri, url(conn, ~p"/auth/github/callback"))
  end
end
