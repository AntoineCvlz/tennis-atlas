defmodule TennisAtlasApi.Pagination do
  import Ecto.Query

  @default_page 1
  @default_page_size 20
  @max_page_size 100

  def paginate(queryable, repo, opts \\ []) do
    page = opts |> Keyword.get(:page, @default_page) |> max(1)

    page_size =
      opts
      |> Keyword.get(:page_size, @default_page_size)
      |> min(@max_page_size)
      |> max(1)

    total_count = repo.aggregate(queryable, :count)
    total_pages = ceil(total_count / page_size)

    entries =
      queryable
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> repo.all()

    %{
      entries: entries,
      page: page,
      page_size: page_size,
      total_count: total_count,
      total_pages: total_pages
    }
  end
end
