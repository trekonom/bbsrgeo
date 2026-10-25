#' Check that the names of one code are constant within a transition
#'
#' Within one `ags_old`/`year_from`/`year_to` group `name_old` should be one
#' name, and likewise `name_new` within an `ags_new` group. A code with more
#' than one distinct name in one transition is reported (e.g. 07235000 in
#' 2011 -> 2012 with the name Bernkastel-Wittlich). Missing names are ignored.
#' Reported as one warning, without a cause.
#'
#' @param data Tibble read by [bbsr_crosswalk_read()].
#' @return A `finding()`, or `NULL` when nothing is found.
#' @noRd
bbsrgeo_check_names <- function(data) {
  inconsistent <- function(code_col, name_col) {
    if (!all(c(code_col, name_col) %in% names(data))) {
      return(NULL)
    }
    d <- data.frame(
      code = data[[code_col]],
      name = data[[name_col]],
      year_from = data$year_from,
      year_to = data$year_to
    )
    d <- unique(d[!is.na(d$name), , drop = FALSE])
    key <- paste(d$code, d$year_from, d$year_to)
    n_names <- stats::ave(seq_len(nrow(d)), key, FUN = length)
    d <- d[n_names > 1, , drop = FALSE]
    if (nrow(d) == 0) {
      return(NULL)
    }
    d <- d[order(d$code, d$year_from), , drop = FALSE]
    groups <- split(d, paste(d$code, d$year_from, d$year_to), drop = TRUE)
    list(
      code_col = code_col,
      n = length(groups),
      examples = purrr::map_chr(
        unname(utils::head(groups, MAX_FINDING_EXAMPLES)),
        function(g) {
          sprintf(
            "%s '%s' (%d -> %d): %s",
            code_col,
            g$code[1],
            g$year_from[1],
            g$year_to[1],
            paste0("'", g$name, "'", collapse = ", ")
          )
        }
      )
    )
  }

  found <- purrr::compact(list(
    inconsistent("ags_old", "name_old"),
    inconsistent("ags_new", "name_new")
  ))
  if (length(found) == 0) {
    return(NULL)
  }
  finding(
    "The names of one code differ within a transition:",
    purrr::map(found, function(f) {
      finding_item(
        sprintf("%s group(s) with more than one name", f$code_col),
        f$n,
        f$examples
      )
    }),
    "Please check the original file if in doubt."
  )
}
