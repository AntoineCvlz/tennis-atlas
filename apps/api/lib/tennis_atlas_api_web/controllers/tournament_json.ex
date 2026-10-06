defmodule TennisAtlasApiWeb.TournamentJSON do
  alias TennisAtlasApi.Tournaments.Tournament

  def index(%{tournaments: tournaments, meta: meta}) do
    %{data: for(t <- tournaments, do: summary(t)), meta: meta}
  end

  def show(%{tournament: tournament}) do
    %{data: detail(tournament)}
  end

  defp summary(%Tournament{} = t) do
    %{
      id: t.id,
      name: t.name,
      slug: t.slug,
      category: t.category,
      surface: t.surface,
      venue: venue(t.venue)
    }
  end

  defp detail(%Tournament{} = t) do
    t
    |> summary()
    |> Map.merge(%{
      description: t.description,
      logo_url: t.logo_url,
      hero_image_url: t.hero_image_url,
      editions: for(e <- t.editions, do: edition_summary(e))
    })
  end

  defp edition_summary(edition) do
    %{
      id: edition.id,
      year: edition.year,
      start_date: edition.start_date,
      end_date: edition.end_date,
      status: edition.status
    }
  end

  defp venue(nil), do: nil

  defp venue(venue),
    do: %{id: venue.id, name: venue.name, city: venue.city, country_code: venue.country_code}
end
