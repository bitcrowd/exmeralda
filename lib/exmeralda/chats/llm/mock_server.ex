# defmodule Exmeralda.Chats.LLM.MockServer do
#   use Plug.Router

#   plug Plug.Parsers, parsers: [:json],
#                     pass:  ["text/*"],
#                     json_decoder: Poison

#   plug :match
#   plug :dispatch

#   post "/chat/completions" do
#     Plug.Conn.send_resp(conn, 200, %{})
#   end
# end
