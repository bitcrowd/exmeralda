defmodule Exmeralda.Emails do
  import Swoosh.Email
  import Phoenix.Component

  defp email_layout(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <style>
          body {
            font-family: system-ui, sans-serif;
            margin: 3em auto;
            overflow-wrap: break-word;
            word-break: break-all;
            max-width: 1024px;
            padding: 0 1em;
          }
        </style>
      </head>
      <body>
        {render_slot(@inner_block)}
      </body>
    </html>
    """
  end

  def ingestion_in_progress_email(%{name: name, email: email}) do
    from = {"Exmeralda", "exmeralda@bitcrowd.net"}
    to = {name, email}
    subject = "We are ingesting your library"

    assigns = %{}

    body =
      ~H"""
      <.email_layout>
        <h1>We are ingesting your library</h1>

        <p>
          The ingestion process typically takes some time. Watch your <a href="https://exmeralda.chat/ingestions">ingestion in realtime</a>.
        </p>
      </.email_layout>
      """

    build_email(from, to, subject, body)
  end

  defp build_email(from, to, subject, body) do
    html = heex_to_html(body)
    text = html_to_text(html)

    new()
    |> to(to)
    |> from(from)
    |> subject(subject)
    |> html_body(html)
    |> text_body(text)
  end

  defp heex_to_html(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp html_to_text(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("body")
    |> Floki.text(sep: "\n\n")
  end
end
