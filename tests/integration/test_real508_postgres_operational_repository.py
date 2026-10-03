from sgoda.operational_platform.postgres_repository import (
    PostgreSQLOperationalRepository,
)


class FakeCursor:
    def __init__(self, connection):
        self.connection = connection
        self.result = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def execute(self, sql, params=None):
        normalized = " ".join(sql.split()).lower()

        assert normalized.startswith("select ")
        assert "insert " not in normalized
        assert "update " not in normalized
        assert "delete " not in normalized

        self.connection.queries.append((normalized, params))

        if "count(*)" in normalized:
            self.result = [(508,)]
            return

        if "select audio_puinave" in normalized:
            if params == ("000508",):
                self.result = [
                    ("audio/pu/000508.mp3",)
                ]
            else:
                self.result = []
            return

        if "where identificador = %s" in normalized:
            if params == ("000001",):
                self.result = [
                    (
                        "000001",
                        "A",
                        "Mí",
                        "audio/pu/000001.mp3",
                        {"archivo": "REAL508.xlsx"},
                        {
                            "escritura_puinave": "(a)",
                            "lote_audio_puinave": 1,
                        },
                        True,
                    )
                ]
            else:
                self.result = []
            return

        self.result = [
            (
                "000001",
                "A",
                "Mí",
                "audio/pu/000001.mp3",
                {"archivo": "REAL508.xlsx"},
                {"escritura_puinave": "(a)"},
                True,
            ),
            (
                "000508",
                "IWINSOGPÖNJIN",
                "Mezquinoso-a",
                "audio/pu/000508.mp3",
                {"archivo": "REAL508.xlsx"},
                {"escritura_puinave": " (ibìsokpöngìn) "},
                True,
            ),
        ]

    def fetchone(self):
        if not self.result:
            return None
        return self.result[0]

    def fetchall(self):
        return list(self.result or [])


class FakeConnection:
    def __init__(self):
        self.queries = []

    def cursor(self):
        return FakeCursor(self)


def repository():
    connection = FakeConnection()
    return PostgreSQLOperationalRepository(connection), connection


def test_get_entry_preserves_operational_contract():
    repo, connection = repository()

    entry = repo.get_entry("000001")

    assert entry["entry_id"] == "000001"
    assert entry["puinave"] == "A"
    assert entry["spanish"] == "Mí"
    assert entry["validated"] is True
    assert entry["metadata"]["escritura_puinave"] == "(a)"
    assert entry["metadata"]["origen"]["archivo"] == "REAL508.xlsx"

    assert len(connection.queries) == 1


def test_get_entry_not_found():
    repo, _ = repository()

    assert repo.get_entry("999999") is None


def test_media_for_preserves_real508_audio_contract():
    repo, _ = repository()

    media = repo.media_for("000508")

    assert len(media) == 1
    assert media[0]["resource_type"] == "audio"
    assert media[0]["language"] == "pu"
    assert media[0]["path"].endswith("000508.mp3")


def test_media_for_not_found():
    repo, _ = repository()

    assert repo.media_for("999999") == ()


def test_all_entries_preserves_ordered_contract():
    repo, _ = repository()

    entries = repo.all_entries()

    assert len(entries) == 2
    assert entries[0]["entry_id"] == "000001"
    assert entries[-1]["entry_id"] == "000508"


def test_count_returns_database_count():
    repo, _ = repository()

    assert repo.count() == 508


def test_repository_is_select_only():
    repo, connection = repository()

    repo.get_entry("000001")
    repo.media_for("000508")
    repo.all_entries()
    repo.count()

    sql = " ".join(
        query
        for query, _ in connection.queries
    )

    assert "insert " not in sql
    assert "update " not in sql
    assert "delete " not in sql
    assert "drop " not in sql
    assert "alter " not in sql
