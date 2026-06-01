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
- 4,120 exact song title / lyric references identified
- 1,251 instances of creative wordplay detected
- 137 Beatles songs in the curated search list (see `data/beatles_songs.txt`)
- 36 characteristic lyric phrases (see `data/beatles_lyrics.txt`)

---

## Repository structure

```
.
├── data/
│   ├── beatles_songs.txt          # 137 curated Beatles song titles used for search
│   ├── beatles_lyrics.txt         # 36 characteristic Beatles lyric phrases
│   ├── beatles_selected_songs.txt # song subset used for the published analysis
│   └── shared/                    # minimal-column reference data (data availability)
├── prompts/
│   ├── system_prompt.txt          # GPT-4o-mini system prompt for wordplay classification
│   └── user_prompt.txt            # User prompt template with few-shot examples
├── wordplay_pipeline.ipynb        # Full pipeline: exact + approximate retrieval + LLM tagging
├── scopus.py                      # Standalone CLI for the exact-retrieval stage
├── prepare_shared_data.py         # Export minimal-column copies of the reference data
├── Generate_Plots.R               # Reproduce the paper's figures and tables
├── requirements.txt
├── .env.example
└── .gitignore
```

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

The data export under `data/shared/` was generated as minimal-column copies of the retrieved references (`paper_nr`, `song_nr`, `song_name`, `year`, `cited_by`, `doi`), for data-availability purposes:

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

The 137 songs in `data/beatles_songs.txt` were selected from the full Beatles discography by excluding:
- Cover songs and songs not originally written by the Beatles
- Titles too generic to yield reliable matches (e.g., *Get Back*, *Yesterday*)
- Titles too obscure to plausibly appear as deliberate references

Songs were matched from their release year onward. Queries are case- and punctuation-insensitive; articles (*a*, *an*, *the*) and auxiliary forms of *to be* may be omitted.

---

## License

Code: [MIT License](LICENSE)

Song titles and lyric phrases are the property of their respective rights holders and are listed here solely for scholarly research purposes under fair use.
