# Fail when a staged line in R/ or tests/testthat/ calls suppressWarnings() or
# suppressMessages() without a comment naming the condition it silences
# (CODING_STANDARDS.md > Tests). The comment goes on the same line or the line
# above. Only lines added in the staged diff are checked, so older calls do not
# block a commit.
# Usage: Rscript dev/check-suppress.R (the pre-commit hook runs it)
#        Rscript dev/check-suppress.R --all
# With --all, lists every such call in the working tree and never fails; use it
# to find the calls to annotate.
root <- if (basename(getwd()) == "dev") ".." else "."
setwd(root)

pattern <- "suppress(Warnings|Messages)\\b"

# Line numbers of `lines` that call a suppress function with no comment.
bare_calls <- function(lines) {
  hit <- grepl(pattern, lines) & !grepl("#", lines, fixed = TRUE)
  above <- c("", lines[-length(lines)])
  which(hit & !grepl("^\\s*#", above))
}

all_files <- c(
  list.files("R", "\\.R$", full.names = TRUE),
  list.files("tests/testthat", "\\.R$", full.names = TRUE)
)

if ("--all" %in% commandArgs(trailingOnly = TRUE)) {
  for (f in all_files) {
    lines <- readLines(f, warn = FALSE)
    at <- bare_calls(lines)
    if (length(at) > 0) {
      message(paste(
        sprintf("%s:%d: %s", f, at, trimws(lines[at])),
        collapse = "\n"
      ))
    }
  }
  quit(save = "no")
}

# Added line numbers of one file in the staged diff, from its hunk headers
# ("@@ -old,n +start,count @@").
added_lines <- function(f) {
  diff <- system2(
    "git",
    c("diff", "--cached", "-U0", "--", f),
    stdout = TRUE
  )
  heads <- regmatches(
    diff,
    regexpr("\\+[0-9]+(,[0-9]+)?(?= @@)", diff, perl = TRUE)
  )
  unlist(lapply(heads, function(h) {
    parts <- as.integer(strsplit(sub("^\\+", "", h), ",")[[1]])
    count <- if (length(parts) == 2) parts[2] else 1L
    if (count == 0L) integer() else seq(parts[1], length.out = count)
  }))
}

staged <- system2(
  "git",
  c(
    "diff",
    "--cached",
    "--name-only",
    "--diff-filter=AM",
    "--",
    "R",
    "tests/testthat"
  ),
  stdout = TRUE
)
staged <- staged[grepl("\\.R$", staged)]

problems <- character()
for (f in staged) {
  lines <- readLines(f, warn = FALSE)
  at <- intersect(bare_calls(lines), added_lines(f))
  problems <- c(problems, sprintf("%s:%d: %s", f, at, trimws(lines[at])))
}

if (length(problems) > 0) {
  message(paste(problems, collapse = "\n"))
  stop(
    "A suppress call needs a comment naming the condition it silences.",
    call. = FALSE
  )
}
