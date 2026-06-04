# Beatles Scientific Wordplay

Code for the paper:

> **How science gets by with a little help from the Beatles: Detecting cultural wordplay in scientific literature using large language models**  
> *Under review*

This repository contains the data retrieval and wordplay detection pipeline used to identify Beatles song title and lyric references — including creative wordplay — in academic article titles retrieved from Scopus.

---

## Overview

The pipeline has three stages, all implemented in `wordplay_pipeline.ipynb`:

1. **Exact retrieval** — queries the Elsevier Scopus API for titles that match a Beatles song or lyric verbatim (allowing a dropped article, a parenthetical part, or removed periods).
2. **Approximate retrieval** — relaxed leave-one-out queries (each non-article word dropped in turn) that surface candidates for wordplay which omits or changes one word.
3. **Wordplay detection** — GPT-4o-mini (via the OpenAI API) with few-shot prompting classifies each candidate as genuine Beatles wordplay or a coincidental match.

`scopus.py` is a standalone command-line alternative for the exact retrieval stage (see *Download the Scopus data* below).

**Key numbers from the paper:**
- 2,306 exact song title / lyric references identified
- 1,247 instances of creative wordplay detected
- 112 curated Beatles songs used in the published analysis (see `data/beatles_selected_songs.txt`)
- 36 characteristic lyric phrases (see `data/beatles_lyrics.txt`)

---

## Repository structure

```
.
├── data/
│   ├── beatles_songs.txt          # full Beatles discography (search list)
│   ├── beatles_lyrics.txt         # 36 characteristic Beatles lyric phrases
│   ├── beatles_selected_songs.txt # 112 curated songs used in the published analysis
│   └── shared/                    # shareable data for data availability
│       ├── titles_exact.txt              # 2048 exact song-title references
│       ├── titles_wordplay.txt           #  694 song-title wordplay references
│       ├── lyrics_exact.txt              #  258 exact lyric references
│       ├── lyrics_wordplay.txt           #  553 lyric wordplay references
│       ├── wordplay_candidates.txt       # approximate candidates seen by the classifier
│       └── wordplay_annotation_sample.csv  # 300-title human validation set
├── prompts/
│   ├── system_prompt.txt          # GPT-4o-mini system prompt for wordplay classification
│   └── user_prompt.txt            # User prompt template with few-shot examples
├── wordplay_pipeline.ipynb        # Full pipeline: exact + approximate retrieval + LLM tagging
├── annotation_validation.ipynb    # Human validation: precision/recall/F1 + inter-annotator agreement
├── scopus.py                      # Standalone CLI for the exact-retrieval stage
├── prepare_shared_data.py         # Export minimal-column copies of the reference data
├── Generate_Plots.R               # Reproduce the paper's figures and tables
├── requirements.txt
├── .env.example
└── .gitignore
```

---

## Validation of the wordplay classifier

To validate the GPT-4o-mini classifier, all three authors independently annotated a stratified
sample of 300 wordplay candidates (150 the model labelled as wordplay, 150 as not), blind to the
model's predictions and to one another's labels. Taking the majority human label as ground truth:

- **LLM vs. human majority:** precision 0.46, NPV 0.91, recall 0.83, F1 0.59, Cohen's κ 0.37
- **Inter-annotator agreement:** pairwise Cohen's κ 0.76–0.86, Fleiss' κ 0.82

Because the sample is balanced 1:1 by the model's label, precision and NPV are unbiased for the
full candidate set, while recall, F1, and accuracy are conditional on the balanced design. False
positives are dominated by *misattributed* wordplay — genuine puns, but on a different song,
artist, or source than the one supplied.

- `annotation_validation.ipynb` — reproduces every metric with 95% bootstrap confidence intervals
- `data/shared/wordplay_annotation_sample.csv` — the 300 titles with each rater's Yes/No label and the majority vote

---

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/gabybudel/beatles-scientific-wordplay.git
cd beatles-scientific-wordplay
```

### 2. Create and activate a Python 3.10 environment

With conda:

```bash
conda create -n beatles python=3.10.13
conda activate beatles
```

Or with pyenv + venv:

```bash
pyenv install 3.10.13
pyenv local 3.10.13
python -m venv .venv && source .venv/bin/activate
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure API keys

```bash
cp .env.example .env
```

Obtain API keys form the respective providers. Edit `.env` and fill in:

| Variable | Where to get it |
|---|---|
| `SCOPUS_API_KEY` | [Elsevier Developer Portal](https://dev.elsevier.com/) — requires institutional access |
| `OPENAI_API_KEY` | [OpenAI Platform](https://platform.openai.com/api-keys) |

---

## Usage

> **Note:** The Scopus API requires an API key with institutional access. Rate limits apply, so the retrieval steps include a short delay between requests.

### Full pipeline — `wordplay_pipeline.ipynb`

Open and run the notebook end-to-end in Jupyter:

```bash
jupyter notebook wordplay_pipeline.ipynb
```

It runs all three stages and writes its results into `data/`:

| Stage | What it does | Output |
|---|---|---|
| 1a — Exact retrieval | Verbatim title matches for songs and lyrics | `data/scopus_song_refs.txt`, `data/scopus_lyric_refs.txt` |
| 1b — Approximate retrieval | Leave-one-out queries for wordplay candidates | `data/scopus_approx_refs.txt` |
| 2 — Wordplay detection | GPT-4o-mini classification of candidates | `data/scopus_wordplay_tags.txt` |

The Stage 2 tags file has columns `scopus_id`, `explanation`, and `wordplay` (`"Yes"`/`"No"`).

### Download the raw Scopus data with the standalone script

`scopus.py` is for just downloading the raw data from the exact-retrieval stage:

```bash
python scopus.py            # writes beatles_scopus.txt + beatles_scopus_refs.txt
```

It reads `data/beatles_songs.txt` and writes per-song hit counts (`beatles_scopus.txt`) and full bibliographic records (`beatles_scopus_refs.txt`). It includes a 0.5 s delay between requests.

### Data export

`prepare_shared_data.py` exports the four result datasets that back the paper's tables,
plus the approximate wordplay candidates, under `data/shared/`:

| File | Rows | Contents |
|---|---|---|
| `titles_exact.txt` | 2048 | exact song-title references (selected songs) |
| `titles_wordplay.txt` | 694 | song-title wordplay references (selected songs) |
| `lyrics_exact.txt` | 258 | exact lyric references |
| `lyrics_wordplay.txt` | 553 | lyric wordplay references |
| `wordplay_candidates.txt` | — | approximate candidates the classifier saw, before filtering to wordplay |

Each file keeps the columns `paper_nr`, `song_nr`, `song_name`, `title`, `year`,
`cited_by`, `doi` — the article title is retained (matching the annotation set), while
Scholar data and the raw author/venue/scopus_id columns are excluded. Rows are ordered
by descending per-song reference count, then by descending year within each song. The
title datasets are filtered to the 112 selected songs, which is what reduces the
song-title wordplay set to 694 (four de-selected songs contributed one wordplay each).

```bash
python prepare_shared_data.py
```

---

## LLM classification details

- **Model:** `gpt-4o-mini`
- **Temperature:** `0.0` (deterministic)
- **Prompting strategy:** Few-shot with 5 human-annotated examples (see `prompts/`)
- **Chain-of-thought:** The model explains its reasoning before giving a binary answer
- **Batch size:** 25 titles per API call; up to 1,000 candidates per song

The few-shot examples in `prompts/user_prompt.txt` cover both positive cases (genuine wordplay) and hard negatives (coincidental word overlap).

---

## Song curation

`data/beatles_songs.txt` is the full Beatles discography (215 songs + year, the core
catalogue sourced from Wikipedia's *List of songs recorded by the Beatles*). The 112 songs
in `data/beatles_selected_songs.txt` were selected from it by excluding:
- Cover songs and songs not originally written by the Beatles
- Titles too generic to yield reliable matches (e.g., *Get Back*, *Yesterday*)
- Titles too obscure to plausibly appear as deliberate references

Songs were matched from their release year onward. Queries are case- and punctuation-insensitive; articles (*a*, *an*, *the*) and auxiliary forms of *to be* may be omitted.

---

## License

Code: [MIT License](LICENSE)

Song titles and lyric phrases are the property of their respective rights holders and are listed here solely for scholarly research purposes under fair use.
