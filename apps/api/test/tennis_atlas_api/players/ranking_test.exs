defmodule TennisAtlasApi.Players.RankingTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Players.{Player, Ranking}
  alias TennisAtlasApi.Repo

  defp player_fixture do
    %Player{}
    |> Player.changeset(%{
      first_name: "Test",
      last_name: "Player",
      slug: "test-player-#{System.unique_integer([:positive])}",
      country_code: "FRA"
    })
    |> Repo.insert!()
  end

  test "changeset with valid attributes is valid" do
    player = player_fixture()

    changeset =
      Ranking.changeset(%Ranking{}, %{
        player_id: player.id,
        ranking_type: :atp,
        position: 1,
        points: 10_000,
        as_of_date: ~D[2025-06-01]
      })

    assert changeset.valid?
  end

  test "changeset requires all fields" do
    changeset = Ranking.changeset(%Ranking{}, %{})

    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.player_id == ["can't be blank"]
    assert errors.ranking_type == ["can't be blank"]
    assert errors.position == ["can't be blank"]
    assert errors.points == ["can't be blank"]
    assert errors.as_of_date == ["can't be blank"]
  end

  test "(player_id, ranking_type, as_of_date) must be unique" do
    player = player_fixture()

    attrs = %{
      player_id: player.id,
      ranking_type: :atp,
      position: 1,
      points: 10_000,
      as_of_date: ~D[2025-06-01]
    }

    {:ok, _ranking} = Ranking.changeset(%Ranking{}, attrs) |> Repo.insert()
    {:error, changeset} = Ranking.changeset(%Ranking{}, attrs) |> Repo.insert()

    assert %{player_id: ["has already been taken"]} = errors_on(changeset)
  end
end
