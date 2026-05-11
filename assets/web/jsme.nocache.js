(function () {
  var urls = [
    'https://cdn.jsdelivr.net/npm/jsme-editor@2024.4.29/jsme.nocache.js',
    'https://jsme-editor.github.io/dist/jsme/jsme.nocache.js',
  ];

  function sendDebug(level, message, extra) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('onDebugLog', {
        ts: new Date().toISOString(),
        level: level,
        message: message,
        extra: extra || null,
      });
    }
    try {
      var text = '[JSME-BOOT:' + level + '] ' + message;
      if (level === 'error') {
        console.error(text, extra || '');
      } else if (level === 'warn') {
        console.warn(text, extra || '');
      } else {
        console.log(text, extra || '');
      }
    } catch (_) {}
  }

  function tryLoad(index) {
    if (index >= urls.length) {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('onEditorActionError', {
          message: 'JSME 内核加载失败，请检查网络或稍后重试',
        });
      }
      return;
    }
    var src = urls[index];
    sendDebug('info', 'Loading JSME core script', { index: index, src: src });
    var script = document.createElement('script');
    script.src = src;
    script.async = true;
    script.crossOrigin = 'anonymous';
    script.onload = function () {
      sendDebug('info', 'JSME core script loaded', { src: src });
    };
    script.onerror = function () {
      sendDebug('warn', 'JSME core script load failed', { src: src });
      tryLoad(index + 1);
    };
    document.head.appendChild(script);
  }

  tryLoad(0);
})();
