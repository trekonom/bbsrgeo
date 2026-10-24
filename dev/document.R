# Regenerate NAMESPACE and man/*.Rd from the roxygen comments in R/*.R, and
# fail on a roxygen warning (roxygen2 reports those as messages starting with
# "✖", e.g. a link that does not resolve).
# Usage: Rscript dev/document.R
warnings <- character()
withCallingHandlers(
  roxygen2::roxygenise(),
  message = function(m) {
    if (startsWith(conditionMessage(m), "✖")) {
      warnings <<- c(warnings, conditionMessage(m))
    }
  }
)
if (length(warnings) > 0) {
  stop(
    length(warnings),
    " roxygen warning(s); see the lines marked with a cross above.",
    call. = FALSE
  )
}
