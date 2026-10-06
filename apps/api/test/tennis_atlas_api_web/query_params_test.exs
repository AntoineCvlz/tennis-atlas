defmodule TennisAtlasApiWeb.QueryParamsTest do
  use ExUnit.Case, async: true

  alias TennisAtlasApiWeb.QueryParams

  test "defaults page and page_size when absent" do
    assert {:ok, %{page: 1, page_size: 20}} = QueryParams.cast(%{})
  end

  test "casts page and page_size from string params" do
    assert {:ok, %{page: 2, page_size: 50}} =
             QueryParams.cast(%{"page" => "2", "page_size" => "50"})
  end

  test "rejects page below 1" do
    assert {:error, changeset} = QueryParams.cast(%{"page" => "0"})
    refute changeset.valid?
  end

  test "rejects a non-numeric page" do
    assert {:error, _changeset} = QueryParams.cast(%{"page" => "abc"})
  end

  test "casts extra typed fields and leaves them nil when absent" do
    types = %{
      surface: Ecto.ParameterizedType.init(Ecto.Enum, values: [:clay, :grass, :hard, :indoor])
    }

    assert {:ok, %{surface: nil}} = QueryParams.cast(%{}, types)
    assert {:ok, %{surface: :clay}} = QueryParams.cast(%{"surface" => "clay"}, types)
    assert {:error, changeset} = QueryParams.cast(%{"surface" => "nope"}, types)
    assert %{surface: ["is invalid"]} = errors_on(changeset)
  end

  test "enforces required fields" do
    assert {:error, changeset} = QueryParams.cast(%{}, %{ranking_type: :string}, [:ranking_type])
    assert %{ranking_type: ["can't be blank"]} = errors_on(changeset)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
