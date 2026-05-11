(function () {
  const params = new URLSearchParams(window.location.search);
  const channel = params.get('channel') || 'chemvision-jsme';
  const state = {
    smiles: '',
    editor: null,
    pollTimer: null,
    lastSentSmiles: '',
    bridgeReadySent: false,
    initFailed: false,
    theme: 'dark',
  };

  function now() {
    return new Date().toISOString();
  }

  function postToHost(type, payload) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler(type, payload);
      return;
    }
    if (!window.parent) return;
    window.parent.postMessage({ channel, type, payload }, '*');
  }

  function debugLog(level, message, extra) {
    const payload = {
      ts: now(),
      level,
      message,
      extra: extra || null,
    };
    try {
      postToHost('onDebugLog', payload);
    } catch (_) {}
    try {
      const text = `[JSME:${level}] ${message}`;
      if (level === 'error') {
        console.error(text, extra || '');
      } else if (level === 'warn') {
        console.warn(text, extra || '');
      } else {
        console.log(text, extra || '');
      }
    } catch (_) {}
  }

  function hideLoading() {
    const loading = document.getElementById('loading');
    if (loading) {
      loading.style.display = 'none';
    }
  }

  function applyTheme(mode) {
    const normalized = mode === 'light' ? 'light' : 'dark';
    state.theme = normalized;
    document.documentElement.setAttribute('data-theme', normalized);
    const badge = document.getElementById('mode-badge');
    if (badge) {
      badge.textContent = normalized === 'light' ? '日间模式' : '夜间模式';
    }
    debugLog('info', 'theme applied', { mode: normalized });
  }

  function injectModernEditorStyles() {
    if (document.getElementById('chemvision-jsme-modern-style')) {
      return;
    }
    const style = document.createElement('style');
    style.id = 'chemvision-jsme-modern-style';
    style.textContent = `
      #jsme_container button,
      #jsme_container input,
      #jsme_container select {
        border-radius: 10px !important;
      }
      #jsme_container [class*="tool"],
      #jsme_container [class*="button"] {
        transition: all .18s ease !important;
      }
      #jsme_container [class*="tool"]:hover,
      #jsme_container [class*="button"]:hover {
        filter: brightness(1.05);
      }
    `;
    document.head.appendChild(style);
  }

  function setTheme(mode) {
    applyTheme((mode || '').toLowerCase());
  }

  function reportError(message, extra) {
    debugLog('error', message, extra);
    postToHost('onEditorActionError', { message, extra: extra || null });
  }

  function clearPollTimer() {
    if (state.pollTimer) {
      clearInterval(state.pollTimer);
      state.pollTimer = null;
    }
  }

  function getSmiles() {
    const editor = state.editor;
    if (!editor) return state.smiles || '';
    try {
      return editor.smiles() || '';
    } catch (error) {
      debugLog('warn', 'editor.smiles() failed', {
        error: String(error),
      });
      return state.smiles || '';
    }
  }

  function emitSmilesIfChanged() {
    const smiles = getSmiles();
    if (smiles === state.lastSentSmiles) return;
    state.lastSentSmiles = smiles;
    state.smiles = smiles;
    postToHost('onSmilesUpdated', { smiles });
  }

  function setSmiles(smiles) {
    state.smiles = smiles || '';
    debugLog('info', 'setSmiles called', {
      length: state.smiles.length,
      editorReady: Boolean(state.editor),
    });
    if (!state.editor) return;
    try {
      if (!state.smiles) {
        if (state.editor.reset) {
          state.editor.reset();
        } else if (state.editor.readGenericMolecularInput) {
          state.editor.readGenericMolecularInput('');
        }
      } else if (state.editor.readGenericMolecularInput) {
        state.editor.readGenericMolecularInput(state.smiles);
      } else if (state.editor.readMolecule) {
        state.editor.readMolecule(state.smiles);
      }
      emitSmilesIfChanged();
    } catch (error) {
      reportError('设置结构失败', { error: String(error) });
    }
  }

  function initEditor(attempt) {
    if (state.initFailed) {
      return;
    }
    if (state.editor) {
      debugLog('info', 'initEditor skipped: already ready');
      return;
    }
    debugLog('info', 'initEditor attempt', {
      attempt,
      hasJSApplet: Boolean(window.JSApplet),
      hasJSME: Boolean(window.JSApplet && window.JSApplet.JSME),
      baseHref: document.baseURI,
      location: window.location.href,
    });
    if (window.JSApplet && window.JSApplet.JSME) {
      try {
        state.editor = new window.JSApplet.JSME(
          'jsme_container',
          '100%',
          '100%',
          { options: 'star' }
        );
        injectModernEditorStyles();
        applyTheme(state.theme);
        hideLoading();
        if (state.smiles) {
          setSmiles(state.smiles);
        }
        state.lastSentSmiles = getSmiles();
        clearPollTimer();
        state.pollTimer = window.setInterval(emitSmilesIfChanged, 450);
        if (!state.bridgeReadySent) {
          state.bridgeReadySent = true;
          postToHost('onBridgeReady', {});
        }
        debugLog('info', 'JSME initialized successfully');
        return;
      } catch (error) {
        state.initFailed = true;
        reportError('初始化 JSME 失败', { error: String(error), stack: error && error.stack ? String(error.stack) : null });
        return;
      }
    }
    if (attempt >= 80) {
      reportError('JSME 加载超时，请检查网络后重试', {
        hasJSApplet: Boolean(window.JSApplet),
        hasJSME: Boolean(window.JSApplet && window.JSApplet.JSME),
      });
      return;
    }
    window.setTimeout(() => initEditor(attempt + 1), 200);
  }

  window.setSmiles = setSmiles;
  window.setTheme = setTheme;
  window.getSmiles = getSmiles;
  window.__chemvisionInitJsme = function () {
    initEditor(0);
  };

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || data.channel !== channel) return;
    const payload = data.payload || {};
    debugLog('info', 'bridge message received', { type: data.type });
    switch (data.type) {
      case 'setSmiles':
      case 'renderSmiles':
        setSmiles(payload.smiles || '');
        break;
      case 'getSmilesRequest':
        postToHost('getSmilesResult', {
          requestId: payload.requestId,
          smiles: getSmiles(),
        });
        break;
      case 'setTheme':
        setTheme(payload.mode || 'dark');
        break;
      default:
        break;
    }
  });

  window.addEventListener('beforeunload', clearPollTimer);
  window.addEventListener('pagehide', clearPollTimer);
  window.addEventListener('error', (event) => {
    reportError('JSME 页面脚本异常', {
      message: event.message,
      source: event.filename,
      line: event.lineno,
      column: event.colno,
      error: event.error ? String(event.error) : null,
    });
  });
  window.addEventListener('unhandledrejection', (event) => {
    reportError('JSME 页面 Promise 未处理异常', {
      reason: event.reason ? String(event.reason) : null,
    });
  });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      clearPollTimer();
    } else if (state.editor && !state.pollTimer) {
      state.pollTimer = window.setInterval(emitSmilesIfChanged, 450);
    }
  });

  document.addEventListener('DOMContentLoaded', () => {
    applyTheme(state.theme);
    debugLog('info', 'DOMContentLoaded', {
      loadedFlag: Boolean(window.__chemvisionJsmeLoaded),
      hasInitHook: typeof window.__chemvisionInitJsme === 'function',
    });
    if (window.__chemvisionJsmeLoaded) {
      initEditor(0);
      return;
    }
    window.setTimeout(() => initEditor(0), 200);
  });
})();
