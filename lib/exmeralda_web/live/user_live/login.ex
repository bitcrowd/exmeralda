defmodule ExmeraldaWeb.UserLive.Login do
  use ExmeraldaWeb, :live_view

  def render(assigns) do
    ~H"""
    <.hero_layout>
      <div class="flex items-center flex-col gap-8">
        <img
          src={~p"/images/logo-exmeralda.svg"}
          width="523"
          height="516"
          alt="Exmeralda logo, with stylised circuit board tracks surrounding a central node"
          class="max-w-xs"
        />
        <h1 class="text-5xl font-bold">Welcome</h1>
        <div class="card bg-base-100  w-full md:w-1/2 shrink-0 shadow-2xl">
          <div class="card-body">
            <h2 class="text-xl font-bold">Meet Exmeralda</h2>

            <p class="py-2">
              Exmeralda helps you ask questions about Elixir libraries and get accurate,
              version-specific answers. Powered by Retrieval-Augmented Generation (RAG),
              it combines the latest AI with real documentation to deliver helpful, grounded responses.
            </p>
            <a class="btn bg-black text-white" href={~p"/auth/github"}>
              <svg
                aria-label="GitHub logo"
                width="16"
                height="16"
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
              >
                <path
                  fill="white"
                  d="M12,2A10,10 0 0,0 2,12C2,16.42 4.87,20.17 8.84,21.5C9.34,21.58 9.5,21.27 9.5,21C9.5,20.77 9.5,20.14 9.5,19.31C6.73,19.91 6.14,17.97 6.14,17.97C5.68,16.81 5.03,16.5 5.03,16.5C4.12,15.88 5.1,15.9 5.1,15.9C6.1,15.97 6.63,16.93 6.63,16.93C7.5,18.45 8.97,18 9.54,17.76C9.63,17.11 9.89,16.67 10.17,16.42C7.95,16.17 5.62,15.31 5.62,11.5C5.62,10.39 6,9.5 6.65,8.79C6.55,8.54 6.2,7.5 6.75,6.15C6.75,6.15 7.59,5.88 9.5,7.17C10.29,6.95 11.15,6.84 12,6.84C12.85,6.84 13.71,6.95 14.5,7.17C16.41,5.88 17.25,6.15 17.25,6.15C17.8,7.5 17.45,8.54 17.35,8.79C18,9.5 18.38,10.39 18.38,11.5C18.38,15.32 16.04,16.16 13.81,16.41C14.17,16.72 14.5,17.33 14.5,18.26C14.5,19.6 14.5,20.68 14.5,21C14.5,21.27 14.66,21.59 15.17,21.5C19.14,20.16 22,16.42 22,12A10,10 0 0,0 12,2Z"
                >
                </path>
              </svg>
              Login with GitHub
            </a>
          </div>
        </div>
        <div class="text-center">
          <a
            href="https://github.com/bitcrowd/exmeralda/"
            class="p-4 m-2 rounded-lg flex flex-col items-center gap-2 text-gray-500 text-sm dark:bg-base-300"
          >
            <img
              src={~p"/images/logo-github-light.svg"}
              width="98"
              height="96"
              alt="github logo"
              class="max-w-10 dark:hidden"
            />
            <img
              src={~p"/images/logo-github-dark.svg"}
              width="98"
              height="96"
              alt="github logo"
              class="max-w-10 hidden dark:block"
            /> Star us on GitHub
          </a>
          <hr class="mx-2 border-base-100" />
          <a
            href="https://bitcrowd.net"
            class="p-4 m-2 rounded-lg flex flex-col items-center gap-2 text-gray-500 text-sm dark:bg-base-300"
          >
            Built in Berlin with ♥ by <span class="sr-only">bitcrowd</span>
            <img
              src={~p"/images/logo-bitcrowd-light.svg"}
              width="303"
              height="93"
              alt="bitcrowd logo, a dirigible airship flying amongst clouds"
              class="max-w-32 dark:hidden"
            />
            <img
              src={~p"/images/logo-bitcrowd-dark.svg"}
              width="303"
              height="93"
              alt="bitcrowd logo, a dirigible airship flying amongst clouds"
              class="max-w-32 hidden dark:block"
            />
          </a>
        </div>
      </div>
    </.hero_layout>
    """
  end
end
