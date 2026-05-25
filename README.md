# Beatles Scientific Wordplay

Code for the paper:

> **How science gets by with a little help from the Beatles: Detecting cultural wordplay in scientific literature using large language models**  
> *PLOS One* (under review)

This repository contains the data retrieval and wordplay detection pipeline used to identify Beatles song title and lyric references — including creative wordplay — in academic article titles retrieved from Scopus.

---

## Overview

The pipeline has two stages:

1. **Scopus retrieval** (`scopus.py`) — queries the Elsevier Scopus API for each of 137 curated Beatles song titles and collects matching article metadata.
2. **Wordplay detection** (`wordplay_detection.ipynb`) — uses GPT-4o-mini (via the OpenAI API) with few-shot prompting to classify candidate titles as genuine Beatles wordplay or coincidental matches.

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
│   ├── beatles_songs.txt      # 137 curated Beatles song titles used for search
│   └── beatles_lyrics.txt     # 36 characteristic Beatles lyric phrases
├── prompts/
│   ├── system_prompt.txt      # GPT-4o-mini system prompt for wordplay classification
│   └── user_prompt.txt        # User prompt template with few-shot examples
├── scopus.py                  # Stage 1: Scopus API retrieval
├── wordplay_detection.ipynb   # Stage 2: LLM-based wordplay classification
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

Edit `.env` and fill in:

| Variable | Where to get it |
|---|---|
| `SCOPUS_API_KEY` | [Elsevier Developer Portal](https://dev.elsevier.com/) — requires institutional access |
| `OPENAI_API_KEY` | [OpenAI Platform](https://platform.openai.com/api-keys) |

---

## Usage

### Stage 1 — Scopus retrieval

```bash
python scopus.py
```

Reads `data/beatles_songs.txt` and writes:
- `beatles_scopus.txt` — hit counts per song
- `beatles_scopus_refs.txt` — full bibliographic records

> **Note:** The Scopus API requires an API key with institutional access. Rate limits apply; the script includes a 0.5 s delay between requests.

### Stage 2 — Wordplay detection

Open and run `wordplay_detection.ipynb` in Jupyter:

```bash
jupyter notebook wordplay_detection.ipynb
```

The notebook loads the Scopus results, constructs relaxed queries (leave-one-out search), and calls GPT-4o-mini to classify each candidate title. Outputs are JSON arrays with:

| Field | Description |
|---|---|
| `scopus_id` | Unique Scopus identifier |
| `explanation` | One-sentence LLM reasoning |
| `answer` | `"Yes"` or `"No"` |

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
