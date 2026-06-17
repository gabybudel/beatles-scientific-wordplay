"""
Export the four shareable reference datasets that back the paper's results.

For each retrieved reference file in data/, keep only the columns that are safe to
publish (song_name, title, year, cited_by, doi), keep every real Scopus record (drop
only no-hit placeholders), order songs by descending reference count and rows within a
song by descending year, and assign a fresh sequential paper_nr as an anonymous
identifier. The song is identified by song_name (the retrieval-time song_nr is dropped:
it indexed a snapshot of the song list and is not stable across datasets).

The four result datasets and their expected sizes (the paper's headline numbers):

    data/shared/titles_exact.txt     – exact song-title references            (2048)
    data/shared/titles_wordplay.txt  – song-title wordplay references          (694)
    data/shared/lyrics_exact.txt     – exact lyric references                  (189)
    data/shared/lyrics_wordplay.txt  – lyric wordplay references               (553)

    data/shared/wordplay_candidates.txt – approximate (pre-classification)
        wordplay candidates the classifier saw, kept for transparency.

Title-wordplay sources cover both selected and de-selected songs; passing the selected
song list filters the title datasets to the 112 songs used in the published analysis
(this is what reduces the title-wordplay set from 697 to 694).

The two wordplay sets are then finalized by a two-annotator manual re-verification
(recorded outside this repository): confirmed false positives are removed and one
duplicate record is dropped, reducing the published data/shared/titles_wordplay.txt to
554 rows and data/shared/lyrics_wordplay.txt to 408 rows — the wordplay counts reported
in the paper. (The full "Love is all you need" group is kept: those titles play on
"Attention is all you need", itself a play on the lyric.) The expected sizes below
describe the pre-verification export.

Usage
-----
    python prepare_shared_data.py
"""

import os

import pandas as pd

SELECTED_SONGS = "data/beatles_selected_songs.txt"

SHARED_COLUMNS = ["song_name", "title", "year", "cited_by", "doi"]


def load_selected_songs(path: str = SELECTED_SONGS) -> set:
    songs = pd.read_csv(path, sep="\t", encoding="utf-8", dtype=str)
    return set(songs["song"].str.strip())


def prepare(fin: str, fout: str, selected: set | None = None,
            expected: int | None = None) -> None:
    df = pd.read_csv(fin, sep="\t", encoding="utf-8", dtype=str)

    # Keep every real Scopus record; drop only no-hit placeholders. A returned record
    # always has a scopus_id and a title, but year/doi may legitimately be blank.
    df = df[df["scopus_id"].notna() & (df["scopus_id"].str.strip() != "")]
    df = df[df["title"].notna() & (df["title"].str.strip() != "")]

    if selected is not None:
        df = df[df["song_name"].isin(selected)]

    # Order songs by descending reference count, then rows within a song by descending
    # year (blank years sort last). song_name breaks ties between equally frequent songs.
    df = df.assign(
        _count=df.groupby("song_name")["song_name"].transform("size"),
        _year=pd.to_numeric(df["year"], errors="coerce"),
    )
    df = df.sort_values(
        by=["_count", "song_name", "_year"],
        ascending=[False, True, False],
        kind="stable",
        na_position="last",
    )

    shared = df[SHARED_COLUMNS].copy()
    shared.insert(0, "paper_nr", range(len(shared)))

    if expected is not None and len(shared) != expected:
        raise AssertionError(f"{fout}: expected {expected} rows, got {len(shared)}")

    os.makedirs(os.path.dirname(fout), exist_ok=True)
    shared.to_csv(fout, sep="\t", encoding="utf-8", index=False)
    print(f"{fout}: {len(shared)} rows")


def main() -> None:
    selected = load_selected_songs()

    # Four result datasets (sizes asserted against the paper's reported counts).
    prepare("data/scopus_song_refs.txt", "data/shared/titles_exact.txt",
            selected=selected, expected=2048)
    prepare("data/scopus_song_wordplay_refs.txt", "data/shared/titles_wordplay.txt",
            selected=selected, expected=694)
    prepare("data/scopus_lyric_refs.txt", "data/shared/lyrics_exact.txt",
            expected=189)
    prepare("data/scopus_lyric_wordplay_refs.txt", "data/shared/lyrics_wordplay.txt",
            expected=553)

    # Approximate wordplay candidates (pre-classification), kept for transparency.
    prepare("data/scopus_approx_refs.txt", "data/shared/wordplay_candidates.txt")


if __name__ == "__main__":
    main()
