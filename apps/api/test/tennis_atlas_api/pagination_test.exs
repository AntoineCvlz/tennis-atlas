defmodule TennisAtlasApi.PaginationTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Pagination
  alias TennisAtlasApi.Venues.Venue

  defp insert_venues(count) do
    for n <- 1..count do
      %Venue{}
      |> Venue.changeset(%{name: "Venue #{n}", city: "City", country_code: "FRA"})
      |> Repo.insert!()
    end
  end

  test "paginates the first page" do
    insert_venues(5)
    query = from(v in Venue, order_by: [asc: v.id])

    result = Pagination.paginate(query, Repo, page: 1, page_size: 2)

    assert length(result.entries) == 2
    assert result.page == 1
    assert result.page_size == 2
    assert result.total_count == 5
    assert result.total_pages == 3
  end

  test "paginates a partial last page" do
    insert_venues(5)
    query = from(v in Venue, order_by: [asc: v.id])

    result = Pagination.paginate(query, Repo, page: 3, page_size: 2)

    assert length(result.entries) == 1
    assert result.total_pages == 3
  end

  test "returns an empty page past the end instead of erroring" do
    insert_venues(5)
    query = from(v in Venue, order_by: [asc: v.id])

    result = Pagination.paginate(query, Repo, page: 10, page_size: 2)

    assert result.entries == []
    assert result.total_count == 5
  end

  test "caps page_size at 100" do
    insert_venues(5)
    query = from(v in Venue, order_by: [asc: v.id])

    result = Pagination.paginate(query, Repo, page: 1, page_size: 500)

    assert result.page_size == 100
    assert length(result.entries) == 5
  end

  test "defaults to page 1 and page_size 20 when opts are omitted" do
    insert_venues(5)
    query = from(v in Venue, order_by: [asc: v.id])

    result = Pagination.paginate(query, Repo)

    assert result.page == 1
    assert result.page_size == 20
  end
end
