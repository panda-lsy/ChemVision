# Flutter Web fallback fonts

Production builds mirror the font files referenced by the installed Flutter
Web engine. Their original paths are listed in the Flutter SDK's
`font_fallback_data.dart` and `canvaskit/fonts.dart` files. Noto fonts are
distributed under the SIL Open Font License 1.1; the Roboto fallback used by
the current engine is distributed under the Apache License 2.0. Copyright and
font-specific notices are embedded in the font files.

For a local release build, run `tools/prepare_web_fonts.py` with the Flutter
SDK root and the build's `font-fallback` directory after `flutter build web`.
Without the generated mirror, the bootstrap keeps Flutter's default font URL.
