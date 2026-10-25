# Fail when a steering doc names a file or function that no longer exists.
# Checks the backticked `R/x.R`-style paths and `name()` calls in CLAUDE.md,
# GLOSSARY.md, CODING_STANDARDS.md and docs/. A `name()` is known if R/ defines
# it or a package from DESCRIPTION (or base R) exports it; `pkg::name()` is
# skipped. The .scratch/ issue files are history and are not checked.
# Usage: Rscript dev/check-refs.R (the pre-commit hook runs it)
#        Rscript dev/check-refs.R --diff [rev]
# With --diff, instead lists the doc lines that name a function whose
# definition in R/ was added, removed or changed since `rev` (default HEAD, so
# uncommitted work; a branch review passes the merge-base). A name that still
# exists can no longer do what the doc says, which the check above cannot see.
# Only lists; never fails. A reviewer or the author reads each line.
root <- if (basename(getwd()) == "dev") ".." else "."
setwd(root)

docs <- c(
  "CLAUDE.md",
  "GLOSSARY.md",
  "CODING_STANDARDS.md",
  list.files("docs", "\\.md$", recursive = TRUE, full.names = TRUE)
)
docs <- docs[file.exists(docs)]

args <- commandArgs(trailingOnly = TRUE)
if ("--diff" %in% args) {
  rev <- args[which(args == "--diff") + 1]
  if (is.na(rev)) {
    rev <- "HEAD"
  }
  # Deparsed top-level function definitions of one source text, by name.
  definitions <- function(lines) {
    exprs <- tryCatch(
      parse(text = lines, keep.source = FALSE),
      error = function(e) expression()
    )
    out <- list()
    for (e in exprs) {
      if (
        is.call(e) &&
          as.character(e[[1]]) %in% c("<-", "=") &&
          is.symbol(e[[2]]) &&
          is.call(e[[3]]) &&
          identical(as.character(e[[3]][[1]]), "function")
      ) {
        out[[as.character(e[[2]])]] <- paste(deparse(e[[3]]), collapse = "\n")
      }
    }
    out
  }
  changed <- character()
  for (f in list.files("R", "\\.R$", full.names = TRUE)) {
    old <- suppressWarnings(system2(
      "git",
      c("show", sprintf("%s:%s", rev, f)),
      stdout = TRUE,
      stderr = FALSE
    ))
    old <- definitions(old)
    new <- definitions(readLines(f, warn = FALSE))
    for (name in union(names(old), names(new))) {
      if (!identical(old[[name]], new[[name]])) {
        changed <- c(changed, name)
      }
    }
  }
  # Also functions whose file was deleted since `rev`.
  removed <- setdiff(
    system2(
      "git",
      c("diff", "--name-only", "--diff-filter=D", rev, "--", "R"),
      stdout = TRUE
    ),
    character()
  )
  for (f in removed) {
    old <- definitions(system2(
      "git",
      c("show", sprintf("%s:%s", rev, f)),
      stdout = TRUE
    ))
    changed <- c(changed, names(old))
  }
  changed <- unique(changed)
  hits <- character()
  for (doc in docs) {
    lines <- readLines(doc, warn = FALSE)
    for (name in changed) {
      at <- grep(sprintf("`%s()`", name), lines, fixed = TRUE)
      hits <- c(hits, sprintf("%s:%d: %s", doc, at, trimws(lines[at])))
    }
  }
  if (length(hits) == 0) {
    message("No doc names a function changed since ", rev, ".")
  } else {
    message(
      "Docs naming a function changed since ",
      rev,
      "; check each still says what the function does:\n",
      paste(sort(unique(hits)), collapse = "\n")
    )
  }
  quit(save = "no")
}

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
