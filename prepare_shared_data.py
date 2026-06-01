"""
Export shareable, minimal-column copies of the Scopus reference data.

For each raw reference file in data/, keep only the columns that are safe to publish
(song_nr, song_name, year, cited_by, doi), drop no-hit placeholder rows, and assign a
fresh sequential paper_nr as an anonymous identifier. Scholar data and the raw
title/author/venue/scopus_id columns are intentionally excluded.

Usage
-----
    python prepare_shared_data.py

Output
------
    data/shared/song_refs.txt    – exact song-title references
    data/shared/lyric_refs.txt   – exact lyric references
    data/shared/approx_refs.txt  – approximate (wordplay-candidate) references
"""

import os

import pandas as pd

SOURCES = {
    "data/scopus_song_refs.txt": "data/shared/song_refs.txt",
    "data/scopus_lyric_refs.txt": "data/shared/lyric_refs.txt",
    "data/scopus_approx_refs.txt": "data/shared/approx_refs.txt",
}

SHARED_COLUMNS = ["song_nr", "song_name", "year", "cited_by", "doi"]


def prepare(fin: str, fout: str) -> None:
    df = pd.read_csv(fin, sep="\t", encoding="utf-8", dtype=str)

    # Drop no-hit placeholder rows (no Scopus record / no resolved year).
    df = df[df["scopus_id"].notna() & (df["scopus_id"].str.strip() != "")]
    df = df[df["year"].notna() & (df["year"].str.strip() != "")]

    shared = df[SHARED_COLUMNS].copy()
    shared.insert(0, "paper_nr", range(len(shared)))

    os.makedirs(os.path.dirname(fout), exist_ok=True)
    shared.to_csv(fout, sep="\t", encoding="utf-8", index=False)
    print(f"{fout}: {len(shared)} rows")


def main() -> None:
    for fin, fout in SOURCES.items():
        prepare(fin, fout)


if __name__ == "__main__":
    main()
