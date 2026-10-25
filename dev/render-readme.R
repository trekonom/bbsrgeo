# Rebuild README.md from README.Rmd, against the package source in this
# directory (not the installed copy, which may predate your changes).
# Usage: Rscript dev/render-readme.R
pkgload::load_all(quiet = TRUE)
rmarkdown::render("README.Rmd", quiet = TRUE)
unlink("README.html")
