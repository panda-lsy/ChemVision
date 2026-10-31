{{flutter_js}}
{{flutter_build_config}}

// Production builds contain the fallback font mirror. During `flutter run`,
// it is absent, so keep Flutter's usual fallback URL for local development.
const localFontBase = new URL('font-fallback/', document.baseURI);
fetch(new URL('manifest.json', localFontBase), { cache: 'no-store' })
  .then((response) => response.ok ? response.json() : null)
  .catch(() => null)
  .then((manifest) => _flutter.loader.load({
    config: manifest && manifest.version === 1
      ? { fontFallbackBaseUrl: localFontBase.href }
      : {},
  }));
