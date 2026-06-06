# How science gets by with a little help from the Beatles
#
# Subject-area (discipline) distribution of the articles that reference the most
# frequently matched Beatles song titles. Reads Scopus "Analyze by subject area"
# exports from data/subjects/ and writes the figure to plots/ as a PowerPoint
# (via eoffice), matching the plotting style of Generate_Plots.R.
#
# Run with the repository root as the working directory.

library(dplyr)
library(ggplot2)
library(scales)
library(eoffice)


# --------------------------------------------------------------------------
# Shared settings (identical to Generate_Plots.R)
# --------------------------------------------------------------------------

palette <- c(
  "#0e0e9a",
  "#0085ca",
  "#00b388",
  "#6ba539",
  "#cedc00",
  "#ed8b00",
  "#da291c",
  "#d0006f",
  "#8a1b61"
)

axis_theme <- theme(
  panel.grid.major = element_blank(),
  panel.grid.minor = element_blank(),
  axis.title.x = element_text(size = 14),
  axis.title.y = element_text(size = 14),
  axis.text.x  = element_text(size = 12),
  axis.text.y  = element_text(size = 12)
)

dir.create("plots", showWarnings = FALSE)


# --------------------------------------------------------------------------
# Helper: parse a Scopus "Analyze by subject area" CSV export
# --------------------------------------------------------------------------
# The export has a preamble, then a "SUBJECT AREA," header, then rows of the
# form  "Social Sciences,""71"""  (subject name, then a quoted article count).

parse_scopus_subjects <- function(path) {
  lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
  start <- which(grepl("SUBJECT AREA", lines))[1]
  rows  <- lines[(start + 1):length(lines)]
  rows  <- rows[nzchar(trimws(rows))]
  m <- regmatches(rows, regexec('^"?(.*),""([0-9]+)"""?$', rows))
  data.frame(
    subject = vapply(m, `[`, "", 2),
    count   = as.integer(vapply(m, `[`, "", 3)),
    stringsAsFactors = FALSE
  )
}


# --------------------------------------------------------------------------
# Load and combine the per-song subject exports
# --------------------------------------------------------------------------

files <- list.files("data/subjects", pattern = "_subjects\\.csv$",
                    full.names = TRUE)

subjects <- bind_rows(lapply(files, parse_scopus_subjects)) %>%
  group_by(subject) %>%
  summarise(n_articles = sum(count), .groups = "drop") %>%
  arrange(desc(n_articles))

print(paste0("Subject areas: ", nrow(subjects),
             "; subject assignments: ", sum(subjects$n_articles)))


# --------------------------------------------------------------------------
# Figure: articles per subject area (all areas, sorted)
# --------------------------------------------------------------------------
# An article may be assigned to several subject areas, so the bars sum to more
# than the number of articles.

p <- ggplot(subjects, aes(x = reorder(subject, n_articles), y = n_articles)) +
  geom_col(fill = palette[2], color = "black", alpha = 0.8, width = 0.76) +
  geom_text(aes(label = n_articles), hjust = -0.3, size = 3.1) +
  coord_flip(clip = "off") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.13)),
                     labels = label_comma()) +
  labs(x = NULL, y = "No. articles") +
  theme_bw(base_size = 13) +
  axis_theme +
  theme(
    axis.text.y = element_text(size = 10.5),
    plot.margin = margin(5, 10, 5, 5)
  )
p

toffice(p, "plots/subject_areas.pptx",
        format = "pptx", width = 8.2, height = 6.3, units = "in")
