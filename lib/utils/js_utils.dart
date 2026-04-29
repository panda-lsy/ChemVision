String escapeForSingleQuotedJs(String input) {
  return input.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
}
