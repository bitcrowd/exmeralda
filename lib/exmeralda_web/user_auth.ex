defmodule ExmeraldaWeb.UserAuth do
  use ExmeraldaWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  use Gettext, backend: ExmeraldaWeb.Gettext

  alias Exmeralda.Accounts

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_user(conn, user) do
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_user_in_session(user)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    if live_socket_id = get_session(conn, :live_socket_id) do
      ExmeraldaWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by looking into the session.
  """
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && Accounts.get_user(user_id)
    assign(conn, :current_user, user)
  end

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_user to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_user:

      defmodule ExmeraldaWeb.PageLive do
        use ExmeraldaWeb, :live_view

        on_mount {ExmeraldaWeb.UserAuth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{ExmeraldaWeb.UserAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, gettext("You must log in to access this page."))
        |> Phoenix.LiveView.redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  def on_mount(:ensure_terms, _params, _session, socket) do
    if socket.assigns.current_user.terms_accepted_at do
      {:cont, socket}
    else
      socket = Phoenix.LiveView.redirect(socket, to: ~p"/accept_terms")

      {:halt, socket}
    end
  end

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user_id = session["user_id"] do
        Accounts.get_user(user_id)
      end
    end)
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, gettext("You must log in to access this page."))
      |> maybe_store_return_to()
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  def require_terms(conn, _opts) do
    if conn.assigns[:current_user].terms_accepted_at do
      conn
    else
      conn
      |> redirect(to: ~p"/accept_terms")
      |> halt()
    end
  end

  defp put_user_in_session(conn, user) do
    conn
    |> put_session(:user_id, user.id)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(user.id)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/chat/start"
end
