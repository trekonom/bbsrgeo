# Fail when a steering doc names a file or function that no longer exists.
# Checks the backticked `R/x.R`-style paths and `name()` calls in CLAUDE.md,
# GLOSSARY.md, CODING_STANDARDS.md and docs/. A `name()` is known if R/ defines
# it or a package from DESCRIPTION (or base R) exports it; `pkg::name()` is
# skipped. The .scratch/ issue files are history and are not checked.
# Usage: Rscript dev/check-refs.R (the pre-commit hook runs it)
root <- if (basename(getwd()) == "dev") ".." else "."
setwd(root)

docs <- c(
  "CLAUDE.md",
  "GLOSSARY.md",
  "CODING_STANDARDS.md",
  list.files("docs", "\\.md$", recursive = TRUE, full.names = TRUE)
)
docs <- docs[file.exists(docs)]

defined <- unlist(lapply(
  list.files("R", "\\.R$", full.names = TRUE),
  function(f) {
    vapply(
      parse(f, keep.source = FALSE),
      function(e) {
        if (
          is.call(e) &&
            as.character(e[[1]]) %in% c("<-", "=") &&
            is.symbol(e[[2]])
        ) {
          as.character(e[[2]])
        } else {
          NA_character_
        }
      },
      character(1)
    )
  }
))

desc <- read.dcf("DESCRIPTION", c("Imports", "Suggests"))
packages <- unique(c(
  "base",
  "stats",
  "utils",
  "tools",
  "testthat",
  trimws(sub("\\(.*", "", unlist(strsplit(desc[!is.na(desc)], ","))))
))
exported <- unlist(lapply(packages, function(pkg) {
  tryCatch(getNamespaceExports(pkg), error = function(e) character())
}))
known <- unique(c(defined[!is.na(defined)], exported))

problems <- character()
for (doc in docs) {
  lines <- readLines(doc, warn = FALSE)
  for (i in seq_along(lines)) {
    line <- lines[i]
    # `R/x.R`, `tests/testthat/test-x.R`, `dev/x.sh`: a path with an extension.
    paths <- regmatches(
      line,
      gregexpr(
        "`((R|dev|tests|docs|data-raw|data)/[^`*<> ]+\\.[A-Za-z]+)`",
        line
      )
    )[[1]]
    for (path in gsub("`", "", paths)) {
      if (!file.exists(path)) {
        problems <- c(
          problems,
          sprintf("%s:%d: file `%s` does not exist", doc, i, path)
        )
      }
    }
    calls <- regmatches(
      line,
      gregexpr(
        "(?<![:\\w.])`[A-Za-z_.][A-Za-z0-9_.]*\\(\\)`",
        line,
        perl = TRUE
      )
    )[[1]]
    for (name in gsub("[`()]", "", calls)) {
      if (!(name %in% known)) {
        problems <- c(
          problems,
          sprintf("%s:%d: function `%s()` is not defined", doc, i, name)
        )
      }
    }
  }
}

if (length(problems) > 0) {
  message(paste(problems, collapse = "\n"))
  stop(
    "Steering docs name files or functions that do not exist.",
    call. = FALSE
  )
}
