"""
Fetch Scopus records for a list of Beatles song titles.

Usage
-----
1. Copy .env.example to .env and fill in your SCOPUS_API_KEY.
2. Run:  python scopus.py

Output
------
beatles_scopus.txt       – one row per song: query details and total hit count
beatles_scopus_refs.txt  – one row per result: bibliographic metadata
"""

import json
import os
import re
import time

import numpy as np
import requests
from dotenv import load_dotenv

load_dotenv()
MY_API_KEY = os.environ["SCOPUS_API_KEY"]


def fetch_json_entry(json_table, key):
    return json_table[key] if key in json_table else np.nan


def get_scopus_data(nr, song_name, fout1, fout2):
    batch_size = 100
    base = "https://api.elsevier.com/content/search/scopus"
    name1_collapsed = re.sub(" +", "+", song_name.lower())
    query = f'TITLE%28"{name1_collapsed}"'
    if "(" in song_name and ")" in song_name:
        name2 = song_name[: song_name.index("(")].strip()
        name2_collapsed = re.sub(" +", "+", name2.lower())
        query += f'+OR+"{name2_collapsed}"'
    query += "%29"

    url = f"{base}?query={query}&count={batch_size}"
    print(url)
    resp = requests.get(
        url,
        headers={"Accept": "application/json", "X-ELS-APIKey": MY_API_KEY},
    )
    results = json.loads(resp.text.encode("utf-8"))
    no_primary = results["search-results"]["opensearch:totalResults"]

    with open(fout1, "a", encoding="utf-8") as f_out:
        f_out.write(f"{nr}\t{song_name}\t{query}\t{no_primary}\n")

    no_primary = int(no_primary) if str(no_primary).isdigit() else 0
    print(f"Results to fetch: {no_primary}")

    if no_primary > 0:
        cite_nr = 1
        batch_nr = 0
        while batch_nr * batch_size < no_primary:
            if "search-results" in results and "entry" in results["search-results"]:
                entries = results["search-results"]["entry"]
                print(
                    f"Fetch [{batch_nr*batch_size}, "
                    f"{min((batch_nr+1)*batch_size - 1, no_primary - 1)}]"
                )
                for entry in entries:
                    scopus_id_full = fetch_json_entry(entry, "dc:identifier")
                    scopus_id = (
                        scopus_id_full.split(":")[-1]
                        if scopus_id_full == scopus_id_full and ":" in str(scopus_id_full)
                        else ""
                    )
                    row = "\t".join(
                        str(fetch_json_entry(entry, k))
                        for k in [
                            "dc:title",
                            "citedby-count",
                            "dc:creator",
                            "prism:publicationName",
                            "prism:doi",
                            "prism:coverDisplayDate",
                        ]
                    )
                    with open(fout2, "a", encoding="utf-8") as f_out:
                        f_out.write(f"{nr}\t{song_name}\t{cite_nr}\t{scopus_id}\t{row}\n")
                    cite_nr += 1

            batch_nr += 1
            new_url = url + f"&start={batch_nr*batch_size}"
            if batch_nr * batch_size < no_primary:
                resp = requests.get(
                    new_url,
                    headers={"Accept": "application/json", "X-ELS-APIKey": MY_API_KEY},
                )
                results = json.loads(resp.text.encode("utf-8"))


def get_songs(fname):
    with open(fname, encoding="utf-8") as f:
        return [line.strip().strip('"') for line in f if line.strip()]


def main():
    fname = "data/beatles_songs.txt"
    fout1 = "beatles_scopus.txt"
    fout2 = "beatles_scopus_refs.txt"

    with open(fout1, "w", encoding="utf-8") as f:
        f.write("nr\tsong\tcollapsed\tno_primary\n")
    with open(fout2, "w", encoding="utf-8") as f:
        f.write("song_nr\tsong_name\tcite_nr\tscopus_id\ttitle\tcited_by\t"
                "author\tvenue\tdoi\tcover_date\n")

    for nr, song in enumerate(get_songs(fname), start=1):
        get_scopus_data(nr, song, fout1, fout2)
        time.sleep(0.5)


if __name__ == "__main__":
    main()
