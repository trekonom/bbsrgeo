# Rebuild README.md from README.Rmd, against the package source in this
# directory (not the installed copy, which may predate your changes).
# Usage: Rscript dev/render-readme.R
#        Rscript dev/render-readme.R --check
# With --check, renders to a temporary file and leaves README.md alone; exits 1
# when README.md differs from what README.Rmd renders to now, i.e. when the
# sample output has drifted from the package's messages and warnings.
pkgload::load_all(quiet = TRUE)
if ("--check" %in% commandArgs(trailingOnly = TRUE)) {
  out <- tempfile(fileext = ".md")
  rmarkdown::render(
    "README.Rmd",
    output_file = basename(out),
    output_dir = dirname(out),
    intermediates_dir = tempdir(),
    knit_root_dir = getwd(),
    quiet = TRUE
  )
  if (!identical(readLines(out), readLines("README.md"))) {
    message("README.md is out of date; run Rscript dev/render-readme.R")
    quit(status = 1)
  }
  message("README.md is up to date.")
  quit(status = 0)
}
rmarkdown::render("README.Rmd", quiet = TRUE)
unlink("README.html")
