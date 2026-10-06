defmodule TennisAtlasApiWeb.QueryParams do
  # `cast/3` is this module's own public API, so import everything from
  # Ecto.Changeset *except* its own `cast/3` — otherwise the import would
  # shadow this function and calling `cast/3` below would recurse into
  # itself instead of reaching Ecto.Changeset.cast/3.
  import Ecto.Changeset, except: [cast: 3]

  @pagination_types %{page: :integer, page_size: :integer}
  @pagination_defaults %{page: 1, page_size: 20}

  def cast(params, types \\ %{}, required \\ []) do
    all_types = Map.merge(@pagination_types, types)

    # Every key in `all_types` must exist in `data`, even as nil — otherwise
    # `apply_changes/1` below omits any filter the caller didn't supply
    # instead of returning it as `nil`, and callers matching on e.g.
    # `%{surface: nil}` would fail against a map missing the key entirely.
    data =
      all_types
      |> Map.new(fn {key, _type} -> {key, nil} end)
      |> Map.merge(@pagination_defaults)

    changeset =
      {data, all_types}
      |> Ecto.Changeset.cast(params, Map.keys(all_types))
      |> validate_number(:page, greater_than: 0)
      |> validate_number(:page_size, greater_than: 0)
      |> validate_required(required)

    if changeset.valid? do
      {:ok, apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end
end
