# How science gets by with a little help from the Beatles
#
# Generates the figures and tables for the paper from the Scopus/Scholar data.
# Run with the repository root as the working directory:
#   inputs are read from data/, results are written to output/ and plots/.

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)
library(ggh4x)
library(eoffice)


# --------------------------------------------------------------------------
# Shared settings
# --------------------------------------------------------------------------

# Colour palette (palette[2] is used as the fill throughout).
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

# Common axis styling, layered on top of theme_bw() in each plot.
axis_theme <- theme(
  panel.grid.major = element_blank(),
  panel.grid.minor = element_blank(),
  axis.title.x = element_text(size = 14),
  axis.title.y = element_text(size = 14),
  axis.text.x  = element_text(size = 12),
  axis.text.y  = element_text(size = 12)
)

dir.create("output", showWarnings = FALSE)
dir.create("plots",  showWarnings = FALSE)


# --------------------------------------------------------------------------
# Helper: build a LaTeX frequency table from a ranked data frame
# --------------------------------------------------------------------------

generate_latex_table <- function(df, item_col, header, colspec,
                                 caption, label, top_n = 25) {
  latex_lines <- c(
    "\\begin{table}[]",
    "\\centering",
    "\\small",
    paste0("\\begin{tabular}{", colspec, "}"),
    "\\toprule",
    header,
    "\\midrule"
  )

  for (i in 1:top_n) {
    rank  <- if (i > 20) sprintf("(%d)", i) else as.character(i)
    item  <- df[[item_col]][i]
    count <- df$n_papers[i]

    # Escape LaTeX special characters in the item label.
    item <- gsub("([%#&_$^{}~\\\\])", "\\\\\\1", item, perl = TRUE)

    latex_lines <- c(latex_lines,
                     sprintf("%-10s & %-35s & %s \\\\", rank, item, count))
  }

  latex_lines <- c(latex_lines,
                   "\\bottomrule",
                   "\\end{tabular}",
                   sprintf("\\caption{%s}", caption),
                   sprintf("\\label{%s}", label),
                   "\\end{table}")

  paste(latex_lines, collapse = "\n")
}


# ==========================================================================
# Song-title references
# ==========================================================================

# --------------------------------------------------------------------------
# Load data
# --------------------------------------------------------------------------

df_refs <- read_delim("data/scopus_song_refs.txt", delim = "\t",
                      escape_double = FALSE, trim_ws = TRUE)

songs <- read_delim("data/beatles_songs.txt", delim = "\t",
                    escape_double = FALSE, trim_ws = TRUE)
songs$song_nr <- seq(0, nrow(songs) - 1)
names(songs)[names(songs) == "song"] <- "song_name"

songs.selected <- read_delim("data/beatles_selected_songs.txt", delim = "\t",
                             escape_double = FALSE, trim_ws = TRUE)
names(songs.selected)[names(songs.selected) == "song"] <- "song_name"
songs <- songs[songs$song_name %in% songs.selected$song_name, ]

scholar <- read_delim("data/scholar_counts.txt", delim = "\t",
                      escape_double = FALSE, trim_ws = TRUE)
df_tags <- read_delim("data/scopus_wordplay_tags.txt", delim = "\t",
                      escape_double = FALSE, trim_ws = TRUE)
df_approx <- read_delim("data/scopus_approx_refs.txt", delim = "\t",
                        escape_double = FALSE, trim_ws = TRUE)


# --------------------------------------------------------------------------
# Filter to selected songs and write the filtered reference list
# --------------------------------------------------------------------------

if (df_refs$row_nr[nrow(df_refs)] + 1 != nrow(df_refs)) {
  stop("Missing refs!")
}

df_refs <- df_refs %>%
  filter(song_name %in% songs$song_name)

print(paste0("Number of papers: ", nrow(df_refs)))

write.table(df_refs, file = "output/scopus_song_refs_filtered.txt", sep = "\t")


# --------------------------------------------------------------------------
# Per-song summary (articles and citations)
# --------------------------------------------------------------------------

df_summary <- df_refs %>%
  group_by(song_nr) %>%
  summarise(
    song_name_check = head(song_name, 1),
    n_papers = n_distinct(cite_nr[cite_nr != -1]),
    total_citations = sum(cited_by, na.rm = TRUE),
    avg_citations = total_citations / n_papers
  )

df_summary <- songs %>%
  select(song_nr, song_name) %>%
  left_join(df_summary, by = "song_nr") %>%
  mutate(
    n_papers = replace_na(n_papers, 0),
    total_citations = replace_na(total_citations, 0),
    avg_citations = replace_na(avg_citations, 0)
  )


# --------------------------------------------------------------------------
# Table: most referenced songs (tab-separated + LaTeX)
# --------------------------------------------------------------------------

beatles <- df_summary[order(df_summary$n_papers, decreasing = TRUE), ]
beatles.table <- beatles[, c("song_name", "n_papers")]
write.table(beatles.table, file = "output/beatles_table.txt", sep = "\t")

latex_table <- generate_latex_table(
  beatles.table[1:25, ],
  item_col = "song_name",
  header   = "Rank & Song & No. articles & Examples\\\\",
  colspec  = "r|>{\\raggedright\\arraybackslash}p{3.5cm}l>{\\raggedright\\arraybackslash}p{9cm}",
  caption  = "The 20 most referred to Beatles' songs in academic article titles on Scopus.",
  label    = "tab:song_frequencies"
)
cat(latex_table, file = "output/beatles_latex_table.tex")


# --------------------------------------------------------------------------
# Figure: distribution of articles per song
# --------------------------------------------------------------------------

p <- ggplot(beatles, aes(x = n_papers)) +
  geom_histogram(fill = palette[2], alpha = 0.8, color = "black", bins = 100) +
  scale_x_continuous(labels = label_comma()) +
  scale_y_continuous(labels = label_comma()) +
  xlab("No. articles") +
  ylab("Frequency") +
  theme_bw() +
  axis_theme
p
toffice(p, "plots/histogram.pptx",
        format = "pptx", width = 6, height = 4.5, units = "in")


# --------------------------------------------------------------------------
# Figure: log-binned frequency with power-law fit
# --------------------------------------------------------------------------

counts <- aggregate(list("count" = beatles$n_papers),
                    list("no.articles" = beatles$n_papers), FUN = length)
counts <- counts[counts$no.articles > 0, ]

n.bins <- 15
log.bins <- seq(log(min(counts$no.articles)), log(max(counts$no.articles)),
                length.out = n.bins + 1)
count.df <- data.frame(bin.center = matrix(0, nrow = n.bins),
                       count = matrix(0, nrow = n.bins))
for (i in 1:n.bins) {
  count.df$bin.center[i] <- exp((log.bins[i] + log.bins[i + 1]) / 2)
  count.df$count[i] <- sum(counts$count[counts$no.articles >= exp(log.bins[i]) &
                                          counts$no.articles < exp(log.bins[i + 1])])
}

fit <- lm(log(count) ~ log(bin.center), data = count.df[count.df$count > 0, ])

newdata <- data.frame(bin.center = exp(seq(log(min(count.df$bin.center)),
                                           log(max(count.df$bin.center)),
                                           length.out = 100)))

pred_log <- predict(fit, newdata = newdata, se.fit = TRUE)
newdata$count <- as.numeric(exp(pred_log$fit))
newdata$lwr   <- as.numeric(exp(pred_log$fit - 1.96 * pred_log$se.fit))
newdata$upr   <- as.numeric(exp(pred_log$fit + 1.96 * pred_log$se.fit))

print(summary(fit)$r.squared)

p <- ggplot(count.df[count.df$count > 0, ], aes(x = bin.center, y = count)) +
  geom_ribbon(
    data = newdata,
    aes(x = bin.center, ymin = lwr, ymax = upr),
    fill = "grey85",
    alpha = 0.6,
    inherit.aes = FALSE
  ) +
  geom_line(data = newdata, aes(linetype = "Linear fit"), color = "black") +
  geom_point(shape = 22, fill = palette[2], color = "black", size = 2.5) +
  scale_x_log10(
    breaks = log_breaks(),
    labels = label_comma()
  ) +
  scale_y_log10(
    breaks = log_breaks(n = 4),
    labels = label_comma()
  ) +
  annotation_logticks(sides = "bltr") +
  coord_cartesian(
    ylim = c(1, max(count.df$count) + 10)
  ) +
  scale_linetype_manual(name = "", values = c("Linear fit" = "solid")) +
  xlab("No. articles") +
  ylab("Frequency") +
  theme_bw(base_size = 14) +
  axis_theme +
  theme(
    legend.position = c(0.94, 0.86),
    legend.justification = c(1, 0),
    legend.background = element_rect(fill = "white", color = "black", linewidth = 0.4),
    legend.key.width = unit(1.2, "lines"),
    legend.key.height = unit(1.0, "lines"),
    legend.margin = margin(-17, 7, 3, 5),
    legend.box.margin = margin(4, 4, 4, 4),
    legend.key = element_rect(fill = NA)
  )
p
toffice(p, "plots/histogram_logbinned.pptx",
        format = "pptx", width = 6, height = 4.5, units = "in")


# --------------------------------------------------------------------------
# Figure: total citations vs. number of articles (log-log)
# --------------------------------------------------------------------------

fit <- lm(log(total_citations) ~ log(n_papers),
          data = df_summary[df_summary$total_citations > 0 &
                              df_summary$n_papers > 0, ])

newdata <- data.frame(n_papers = exp(seq(
  log(min(df_summary$n_papers[df_summary$n_papers > 0])),
  log(max(df_summary$n_papers)),
  length.out = 100)))

pred_log <- predict(fit, newdata = newdata, se.fit = TRUE)
newdata$total_citations <- as.numeric(exp(pred_log$fit))
newdata$lwr             <- as.numeric(exp(pred_log$fit - 1.96 * pred_log$se.fit))
newdata$upr             <- as.numeric(exp(pred_log$fit + 1.96 * pred_log$se.fit))

print(summary(fit)$r.squared)

p <- ggplot(df_summary[df_summary$total_citations > 0 & df_summary$n_papers > 0, ],
            aes(x = n_papers, y = total_citations)) +
  geom_ribbon(
    data = newdata,
    aes(x = n_papers, ymin = lwr, ymax = upr),
    fill = "grey85",
    alpha = 0.6,
    inherit.aes = FALSE
  ) +
  geom_line(data = newdata, aes(linetype = "Linear fit"), color = "black") +
  geom_point(size = 2, shape = 21, fill = palette[2], color = "black") +
  scale_linetype_manual(name = "", values = c("Linear fit" = "solid")) +
  scale_x_log10(
    breaks = log_breaks(),
    labels = label_comma()
  ) +
  scale_y_log10(
    breaks = log_breaks(),
    labels = label_comma()
  ) +
  annotation_logticks(sides = "bltr") +
  coord_cartesian() +
  labs(
    x = "No. articles",
    y = "Total citations"
  ) +
  theme_bw(base_size = 14) +
  axis_theme +
  theme(
    legend.position = c(0.93, 0.10),
    legend.justification = c(1, 0),
    legend.background = element_rect(fill = "white", color = "black", linewidth = 0.4),
    legend.key.width = unit(1.2, "lines"),
    legend.key.height = unit(1.0, "lines"),
    legend.margin = margin(-17, 7, 4, 5),
    legend.box.margin = margin(4, 4, 4, 4),
    legend.key = element_rect(fill = NA)
  )
p
toffice(p, "plots/citations_loglog.pptx",
        format = "pptx", width = 6, height = 4.5, units = "in")


# --------------------------------------------------------------------------
# Figure: articles per publication year
# --------------------------------------------------------------------------

df_yearly <- df_refs %>%
  filter(!is.na(year)) %>%
  count(year, name = "n_papers")

p <- ggplot(df_yearly, aes(x = year, y = n_papers)) +
  geom_col(fill = palette[2], color = "black", alpha = 0.8) +
  labs(
    x = "Publication year",
    y = "No. articles"
  ) +
  scale_x_continuous(
    breaks = seq(1965, 2025, by = 15),
    minor_breaks = seq(1964, 2025, by = 1),
    guide = "axis_minor"
  ) +
  theme_bw() +
  axis_theme
p
toffice(p, "plots/papers_by_year.pptx",
        format = "pptx", width = 6, height = 4, units = "in")


# --------------------------------------------------------------------------
# Figure: Google Scholar vs. Scopus article counts
# --------------------------------------------------------------------------

names(scholar)[names(scholar) == "paper_count"] <- "scholar"
names(df_summary)[names(df_summary) == "n_papers"] <- "scopus"
combined <- merge(df_summary[, c("song_nr", "song_name", "scopus")], scholar,
                  id = c("song_nr", "song_name"))
combined <- combined[order(combined$song_nr), ]
plot.df <- combined[combined$scopus > 0 & combined$scholar > 0, ]

# Log-binned mean of Scopus counts across Scholar counts (for the fit).
n.bins <- 20
log.bins <- seq(log(min(plot.df$scholar)), log(max(plot.df$scholar)),
                length.out = n.bins + 1)
count.df <- data.frame(scholar = matrix(0, nrow = n.bins),
                       scopus = matrix(0, nrow = n.bins))
for (i in 1:n.bins) {
  count.df$scholar[i] <- exp((log.bins[i] + log.bins[i + 1]) / 2)
  count.df$scopus[i] <- mean(plot.df$scopus[plot.df$scholar > exp(log.bins[i]) &
                                              plot.df$scholar <= exp(log.bins[i + 1])])
}

fit <- lm(log(scopus) ~ log(scholar), data = count.df[count.df$scopus > 0, ])

regdata <- data.frame(scholar = exp(seq(log(0.9),
                                        log(max(plot.df$scholar)),
                                        length.out = 100)))

pred_log <- predict(fit, newdata = regdata, se.fit = TRUE)
regdata$scopus <- as.numeric(exp(pred_log$fit))
regdata$lwr    <- as.numeric(exp(pred_log$fit - 1.96 * pred_log$se.fit))
regdata$upr    <- as.numeric(exp(pred_log$fit + 1.96 * pred_log$se.fit))

line_45 <- data.frame(
  scholar = c(0.9, 1.05 * min(max(plot.df$scholar), max(plot.df$scopus))),
  scopus  = c(0.9, 1.05 * min(max(plot.df$scholar), max(plot.df$scopus)))
)

p <- ggplot(plot.df, aes(x = scholar, y = scopus)) +
  geom_ribbon(
    data = regdata,
    aes(x = scholar, ymin = lwr, ymax = upr),
    fill = "grey85",
    alpha = 0.6,
    inherit.aes = FALSE
  ) +
  geom_line(
    data = line_45,
    aes(x = scholar, y = scopus, linetype = "Line 45°", group = 1),
    color = "black"
  ) +
  geom_line(data = regdata, aes(x = scholar, y = scopus, linetype = "Linear fit"),
            color = "black") +
  geom_point(shape = 21, fill = palette[2], color = "black", size = 2.5) +
  scale_x_log10(
    breaks = log_breaks(),
    labels = label_comma()
  ) +
  scale_y_log10(
    breaks = log_breaks(),
    labels = label_comma()
  ) +
  annotation_logticks(sides = "bltr") +
  coord_fixed(
    xlim = c(0.9, 1.05 * max(plot.df$scholar)),
    ylim = c(0.9, 1.05 * max(plot.df$scopus))
  ) +
  xlab("Google Scholar") +
  ylab("Scopus") +
  scale_linetype_manual(
    name = "",
    values = c("Line 45°" = "dashed", "Linear fit" = "solid")
  ) +
  theme_bw() +
  axis_theme +
  theme(
    legend.position = c(0.08, 0.92),
    legend.justification = c(0, 1),
    legend.background = element_rect(fill = "white", color = "black", linewidth = 0.4),
    legend.key.width = unit(1.2, "lines"),
    legend.key.height = unit(0.8, "lines"),
    legend.margin = margin(-13, 6, 3, 5),
    legend.box.margin = margin(4, 4, 4, 4),
    legend.key = element_rect(fill = NA)
  )
p
toffice(p, "plots/scholar_vs_scopus.pptx",
        format = "pptx", width = 4, height = 4, units = "in")

# Pearson correlation, raw and log scale, with 95% CIs.
res1 <- cor.test(plot.df$scholar, plot.df$scopus)
print(res1)
print(res1$conf.int)

nonzero <- subset(plot.df, scholar > 0 & scopus > 0)
res2 <- cor.test(log(nonzero$scholar), log(nonzero$scopus))
print(res2)
print(res2$conf.int)


# --------------------------------------------------------------------------
# Inspect an individual wordplay explanation
# --------------------------------------------------------------------------

df_wordplay <- merge(df_tags, df_approx, by = "scopus_id")
df_wordplay <- df_wordplay[c("scopus_id", "song_name", "title",
                             "wordplay", "explanation")]
print(df_wordplay$explanation[df_wordplay$scopus_id == "SCOPUS_ID:0020727578"])


# ==========================================================================
# Lyric references
# ==========================================================================

# --------------------------------------------------------------------------
# Load data
# --------------------------------------------------------------------------

df_lyrics <- read_delim("data/scopus_lyric_refs.txt", delim = "\t",
                        escape_double = FALSE, trim_ws = TRUE)
songs <- read_delim("data/beatles_lyrics.txt", delim = "\t",
                    escape_double = FALSE, trim_ws = TRUE)
songs$song_nr <- seq(0, nrow(songs) - 1)
names(songs)[names(songs) == "song"] <- "song_name"

df_lyrics <- df_lyrics %>%
  filter(song_name %in% songs$lyric)

print(paste0("Number of papers: ", nrow(df_lyrics)))


# --------------------------------------------------------------------------
# Per-lyric summary
# --------------------------------------------------------------------------

df_summary <- df_lyrics %>%
  group_by(song_nr) %>%
  summarise(
    song_name_check = head(song_name, 1),
    n_papers = n_distinct(cite_nr[cite_nr != -1]),
    total_citations = sum(cited_by, na.rm = TRUE),
    avg_citations = total_citations / n_papers
  )

df_summary <- songs %>%
  select(song_nr, lyric) %>%
  left_join(df_summary, by = "song_nr") %>%
  mutate(
    n_papers = replace_na(n_papers, 0),
    total_citations = replace_na(total_citations, 0),
    avg_citations = replace_na(avg_citations, 0)
  )


# --------------------------------------------------------------------------
# Table: most referenced lyrics (tab-separated + LaTeX)
# --------------------------------------------------------------------------

beatles <- df_summary[order(df_summary$n_papers, decreasing = TRUE), ]
beatles.table <- beatles[, c("lyric", "n_papers")]
write.table(beatles.table, file = "output/beatles_lyrics_table.txt", sep = "\t")

latex_table <- generate_latex_table(
  beatles.table,
  item_col = "lyric",
  header   = "Nr. & Lyric & Articles & Examples\\\\",
  colspec  = "r|>{\\raggedright\\arraybackslash}p{3.2cm}l>{\\raggedright\\arraybackslash}p{10.3cm}",
  caption  = "The most referred to Beatles' lyrics in academic article titles on Scopus.",
  label    = "tab:lyrics_frequencies"
)
cat(latex_table, file = "output/beatles_latex_lyrics_table.tex")
