defmodule Exmeralda.Topics.LineCheckTest do
  use ExUnit.Case

  import Exmeralda.Topics.LineCheck

  test "with smaller lines" do
    assert """
           Fun
           In
           the
           Sun
           """
           |> valid?

    assert """
           #{String.duplicate("a", 2000)}
           #{String.duplicate("a", 2000)}
           """
           |> valid?
  end

  test "an empty string" do
    assert ""
           |> valid?
  end

  test "too long strings" do
    refute """
           #{String.duplicate("a", 2001)}
           Short line
           """
           |> valid?

    refute "#{String.duplicate("a", 2001)}"
           |> valid?

    refute """
           test
           #{String.duplicate("a", 2001)}
           """
           |> valid?
  end
end
