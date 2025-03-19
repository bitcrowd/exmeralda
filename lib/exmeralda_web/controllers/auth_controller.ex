defmodule ExmeraldaWeb.AuthController do
  use ExmeraldaWeb, :controller

  def request(conn, _params) do
    {:ok, %{url: url, session_params: session_params}} =
      conn
      |> config()
      |> strategy().authorize_url()

    conn
    |> put_session(:session_params, session_params)
    |> redirect(external: url)
  end

  def callback(conn, params) do
    session_params = get_session(conn, :session_params)

    conn
    |> config()
    |> Keyword.put(:session_params, session_params)
    |> strategy().callback(params)
    |> case do
      {:ok, %{user: user_info}} ->
          dbg(user_info)
        conn
        |> put_session(:user, user_info)
        |> put_flash(:info, "Signed in successfully!")
        |> redirect(to: "/")

      {:error, _} ->
        conn
        |> put_flash(:error, gettext("Authentication failed!"))
        |> redirect(to: "/")
    end
  end

  defp config(conn) do
    Application.get_env(:exmeralda, strategy(), [])
    |> Keyword.put(:redirect_uri, url(conn, ~p"/auth/github/callback"))
  end

  defp strategy do
    Application.fetch_env!(:exmeralda, :auth_strategy)
  end
end
