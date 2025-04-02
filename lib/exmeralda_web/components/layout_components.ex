defmodule ExmeraldaWeb.LayoutComponents do
  use ExmeraldaWeb, :component

  def navbar_layout(assigns) do
    ~H"""
    <nav class="navbar bg-base-100 shadow-sm" aria-label="main">
      <div class="flex-1">
        <label :if={assigns[:drawer]} for="nav-drawer">
          <.icon name="hero-bars-3" class="m-2 lg:hidden" />
        </label>
        <a class="btn btn-ghost text-xl" href={~p"/"}>Exmeralda</a>
      </div>
      <div class="flex-none">
        <div class="dropdown dropdown-end">
          <div tabindex="0" role="button" class="btn btn-ghost btn-circle avatar">
            <div class="w-10 rounded-full">
              <img title={@user.name} src={@user.avatar_url} />
            </div>
          </div>
          <ul
            tabindex="0"
            class="menu menu-sm dropdown-content bg-base-300 rounded-box z-1 mt-3 w-52 p-2 shadow"
          >
            <li>
              <.link href={~p"/auth/settings"}>
                <.icon name="hero-cog-6-tooth" />
                {gettext("Settings")}
              </.link>
            </li>
            <li>
              <.link href={~p"/auth/log_out"} method="delete">
                <.icon name="hero-arrow-right-start-on-rectangle" />
                {gettext("Logout")}
              </.link>
            </li>
          </ul>
        </div>
      </div>
    </nav>
    <.drawer :if={assigns[:drawer]} drawer_id="nav-drawer" inside_navbar>
      <:side>
        {render_slot(@drawer)}
      </:side>
      {render_slot(@inner_block)}
    </.drawer>
    <div :if={!assigns[:drawer]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp drawer(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open">
      <input id={@drawer_id} type="checkbox" class="drawer-toggle" />
      <div class={["drawer-side z-40", full_screen_height(assigns)]}>
        <label for={@drawer_id} aria-label="close sidebar" class="drawer-overlay"></label>
        <nav class="bg-base-200 min-h-full flex flex-col place-content-between" aria-label="chats">
          <div>
            {render_slot(@side)}
          </div>
          <a
            href="https://bitcrowd.net"
            class="p-4 m-2 rounded-lg flex flex-col gap-2 text-gray-500 text-sm hover:bg-white"
          >
            Built in Berlin with ♥ by <span class="sr-only">bitcrowd</span>
            <img
              src={~p"/images/logo-bitcrowd.svg"}
              width="303"
              height="93"
              alt="bitcrowd logo, a dirigible airship flying amongst clouds"
              class="max-w-32"
            />
          </a>
        </nav>
      </div>
      <main class="drawer-content">
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end

  def hero_layout(assigns) do
    ~H"""
    <div class={["hero bg-base-200", full_screen_height(assigns)]}>
      <div class="hero-content">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  def full_screen_height(assigns) do
    if Map.has_key?(assigns, :inside_navbar), do: "h-[calc(100vh-4rem)]", else: "h-screen"
  end
end
