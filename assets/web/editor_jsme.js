(function () {
  const params = new URLSearchParams(window.location.search);
  const channel = params.get('channel') || 'chemvision-jsme';
  const initialTheme = (params.get('theme') || 'dark').toLowerCase() === 'light'
    ? 'light'
    : 'dark';
  const state = {
    smiles: '',
    editor: null,
    pollTimer: null,
    healthTimer: null,
    skinObserver: null,
    skinRaf: 0,
    skinApplying: false,
    resetDivDetected: false,
    lastSentSmiles: '',
    bridgeReadySent: false,
    initFailed: false,
    theme: initialTheme,
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

  function showLoading(message) {
    const loading = document.getElementById('loading');
    if (!loading) return;
    if (message) {
      loading.textContent = message;
    }
    loading.style.display = 'flex';
  }

  // 前端状态/操作按钮已移除，保留空函数避免调用报错
  function setStatus() {}
  function updateStatusBySmiles() {}
  function bindQuickActions() {}

  function applyTheme(mode) {
    const normalized = mode === 'light' ? 'light' : 'dark';
    state.theme = normalized;
    document.documentElement.setAttribute('data-theme', normalized);
    scheduleLegacySkinApply();
    debugLog('info', 'theme applied', { mode: normalized });
  }

  function themePalette() {
    if (state.theme === 'light') {
      return {
        panelSoft: '#e8f0ff',
        text: '#153a7a',
        accent: '#1f48b3',
        border: 'rgba(31, 72, 179, 0.36)',
        canvas: '#ffffff',
        svgToolbarBg: '#dce6f5',
        svgToolbarStroke: '#b0c0d8',
        svgToolbarText: '#153a7a',
        svgPanelBg: '#dce6f5',
        svgCanvasBg: '#ffffff',
      };
    }
    return {
      panelSoft: '#16253a',
      text: '#d8e6ff',
      accent: '#38d5c1',
      border: 'rgba(126, 200, 227, 0.35)',
      canvas: '#0f172a',
      svgToolbarBg: '#16253a',
      svgToolbarStroke: 'rgba(126, 200, 227, 0.25)',
      svgToolbarText: '#d8e6ff',
      svgPanelBg: '#16253a',
      svgCanvasBg: '#0f172a',
    };
  }

  // CSS 颜色名 → 规范形式（使 'white' 能匹配 color map 中的 rgb 键）
  const COLOR_NAMES = {
    white: 'rgb(255,255,255)', black: 'rgb(0,0,0)', red: 'rgb(255,0,0)',
    green: 'rgb(0,128,0)', blue: 'rgb(0,0,255)', yellow: 'rgb(255,255,0)',
    cyan: 'rgb(0,255,255)', magenta: 'rgb(255,0,255)', gray: 'rgb(128,128,128)',
    grey: 'rgb(128,128,128)', silver: 'rgb(192,192,192)', orange: 'rgb(255,165,0)',
    transparent: 'rgba(0,0,0,0)',
  };
  // 颜色标准化：去除空格，统一格式，颜色名转 RGB
  function normalizeColor(c) {
    if (!c) return '';
    const s = c.replace(/\s+/g, '').toLowerCase();
    if (s in COLOR_NAMES) return COLOR_NAMES[s];
    return s;
  }
  function isBlack(c) {
    const n = normalizeColor(c);
    if (n === 'rgb(0,0,0)' || n === '#000000' || n === '#000' || n === 'black') {
      return true;
    }
    if (/^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(n)) {
      if (n.length === 4) {
        const r = parseInt(n[1] + n[1], 16);
        const g = parseInt(n[2] + n[2], 16);
        const b = parseInt(n[3] + n[3], 16);
        return r <= 48 && g <= 48 && b <= 48;
      }
      const r = parseInt(n.slice(1, 3), 16);
      const g = parseInt(n.slice(3, 5), 16);
      const b = parseInt(n.slice(5, 7), 16);
      return r <= 48 && g <= 48 && b <= 48;
    }
    const m = n.match(/^rgb\((\d+),(\d+),(\d+)\)$/);
    if (m) {
      const r = Number(m[1]);
      const g = Number(m[2]);
      const b = Number(m[3]);
      return r <= 48 && g <= 48 && b <= 48;
    }
    return false;
  }
  function isWhite(c) {
    const n = normalizeColor(c);
    return n === 'white' || n === '#ffffff' || n === '#fff' || n === 'rgb(255,255,255)';
  }

  // JSME 默认 UI 配色 → 主题色映射（key 全部标准化）
  function buildColorMap(mapRaw) {
    const result = {};
    for (const k in mapRaw) {
      result[normalizeColor(k)] = mapRaw[k];
    }
    return result;
  }
  const SVG_COLOR_MAP_DARK = buildColorMap({
    'rgb(192, 192, 192)': '#16253a',
    'rgb(134, 134, 134)': 'rgba(126, 200, 227, 0.25)',
    'rgb(220, 220, 220)': 'rgba(126, 200, 227, 0.15)',
    'rgb(255, 255, 255)': '#0f172a',
    'rgb(0, 0, 0)': '#d8e8ff',
    '#000': '#d8e8ff',
    '#000000': '#d8e8ff',
    'black': '#d8e8ff',
  });
  const SVG_COLOR_MAP_LIGHT = buildColorMap({
    'rgb(192, 192, 192)': '#dce6f5',
    'rgb(134, 134, 134)': '#b0c0d8',
    'rgb(220, 220, 220)': '#c8d4e8',
    'rgb(255, 255, 255)': '#ffffff',
    '#000': '#153a7a',
    '#000000': '#153a7a',
    'black': '#153a7a',
  });

  function mapColor(raw, colorMap, fallback) {
    const n = normalizeColor(raw);
    if (n in colorMap) return colorMap[n];
    if (n === 'currentcolor') {
      return state.theme === 'light' ? '#153a7a' : '#d8e8ff';
    }
    if (isBlack(n)) {
      return state.theme === 'light' ? '#153a7a' : '#d8e8ff';
    }
    return colorMap[n] || fallback || raw;
  }

  // 判断 SVG 是否为主画布（分子渲染区域）
  function isMainCanvasSvg(svg) {
    const r = svg.getBoundingClientRect();
    const w = r.width || 0;
    const h = r.height || 0;
    return w > 200 && h > 100 && (w / h > 1.5);
  }

  // 获取 SVG 中面积最大的 <rect>（通常是背景）
  function findLargestRect(svg) {
    let best = null;
    let bestArea = 0;
    svg.querySelectorAll('rect').forEach((rect) => {
      const w = parseFloat(rect.getAttribute('width') || '0');
      const h = parseFloat(rect.getAttribute('height') || '0');
      const area = w * h;
      if (area > bestArea) {
        bestArea = area;
        best = rect;
      }
    });
    return best;
  }

  // 深色模式下重映射 SVG 属性中的黑色
  function remapBlackInAttr(el, attrName, bondColor) {
    const raw = el.getAttribute(attrName);
    if (raw && isBlack(raw)) {
      el.setAttribute(attrName, bondColor);
    }
    const style = el.getAttribute('style');
    if (!style) return;
    const re = new RegExp(attrName + '\\s*:\\s*([^;]+)', 'i');
    const m = style.match(re);
    if (m && isBlack(m[1])) {
      el.setAttribute('style', style.replace(re, attrName + ':' + bondColor));
    }
  }

  function remapBlackInAttr(el, attrName, bondColor) {
    const raw = el.getAttribute(attrName);
    if (raw && isBlack(raw)) {
      el.setAttribute(attrName, bondColor);
    } else if (!raw && attrName === 'fill') {
      // SVG 默认 fill=black：无 fill 属性时显式设置
      el.setAttribute('fill', bondColor);
    }
    const style = el.getAttribute('style');
    if (!style) return;
    const re = new RegExp(attrName + '\\s*:\\s*([^;]+)', 'i');
    const m = style.match(re);
    if (m && isBlack(m[1])) {
      el.setAttribute('style', style.replace(re, attrName + ':' + bondColor));
    }
  }

  // 检测 SMILES 按钮眼睛图标：大圆/椭圆白底 + 小圆/椭圆黑瞳
  function findEyeFills(svg) {
    const result = new Set();
    // 同时搜索 circle 和 ellipse
    const candidates = [
      ...Array.from(svg.querySelectorAll('circle')).map((el) => ({
        el, rx: Number(el.getAttribute('r') || '0'), ry: Number(el.getAttribute('r') || '0'),
        cx: Number(el.getAttribute('cx') || '0'), cy: Number(el.getAttribute('cy') || '0'),
        fill: normalizeColor(el.getAttribute('fill') || ''),
      })),
      ...Array.from(svg.querySelectorAll('ellipse')).map((el) => ({
        el, rx: Number(el.getAttribute('rx') || '0'), ry: Number(el.getAttribute('ry') || '0'),
        cx: Number(el.getAttribute('cx') || '0'), cy: Number(el.getAttribute('cy') || '0'),
        fill: normalizeColor(el.getAttribute('fill') || ''),
      })),
    ];
    for (let i = 0; i < candidates.length; i++) {
      const outer = candidates[i];
      const outerR = Math.max(outer.rx, outer.ry);
      if (outerR < 4 || outerR > 20 || !isWhite(outer.fill)) continue;
      for (let j = 0; j < candidates.length; j++) {
        if (i === j) continue;
        const inner = candidates[j];
        const innerR = Math.max(inner.rx, inner.ry);
        if (innerR >= 1 && innerR <= outerR * 0.6 && isBlack(inner.fill)) {
          const dx = Math.abs(outer.cx - inner.cx);
          const dy = Math.abs(outer.cy - inner.cy);
          if (dx < outerR && dy < outerR) {
            result.add(outer.el);
            result.add(inner.el);
          }
        }
      }
    }
    return result;
  }

  function applySvgSkin() {
    const root = document.getElementById('jsme_container');
    if (!root) return;
    const palette = themePalette();
    const colorMap = state.theme === 'light' ? SVG_COLOR_MAP_LIGHT : SVG_COLOR_MAP_DARK;
    const svgs = document.querySelectorAll('svg');

    svgs.forEach((svg) => {
      const r = svg.getBoundingClientRect();
      const w = r.width || 0;
      const h = r.height || 0;
      if (w < 2 || h < 2) return;

      const isCanvas = isMainCanvasSvg(svg);

      if (isCanvas) {
        // ── 主画布：改背景 + 重映射所有黑色元素 ──
        const bgRect = findLargestRect(svg);
        if (bgRect) {
          const fill = bgRect.getAttribute('fill') || '';
          if (isWhite(fill)) bgRect.setAttribute('fill', palette.svgCanvasBg);
        }
        if (state.theme === 'dark') {
          const bondColor = '#e0e8f0';
          svg.querySelectorAll('line').forEach((el) => remapBlackInAttr(el, 'stroke', bondColor));
          svg.querySelectorAll('path').forEach((el) => { remapBlackInAttr(el, 'stroke', bondColor); remapBlackInAttr(el, 'fill', bondColor); });
          svg.querySelectorAll('circle').forEach((el) => remapBlackInAttr(el, 'fill', bondColor));
          svg.querySelectorAll('ellipse').forEach((el) => { remapBlackInAttr(el, 'fill', bondColor); remapBlackInAttr(el, 'stroke', bondColor); });
          svg.querySelectorAll('polygon, polyline').forEach((el) => { remapBlackInAttr(el, 'stroke', bondColor); remapBlackInAttr(el, 'fill', bondColor); });
          svg.querySelectorAll('text').forEach((el) => { const f = el.getAttribute('fill'); if (!f || isBlack(f)) el.setAttribute('fill', bondColor); });
        }
        return;
      }

      // ── 工具栏/侧栏：重映射全部元素，仅保留 SMILES 眼睛原色 ──
      const eyeSet = findEyeFills(svg);

      function remapAttr(el, attr) {
        const raw = el.getAttribute(attr);
        if (!raw) return;
        const mapped = mapColor(raw, colorMap);
        if (mapped !== raw) el.setAttribute(attr, mapped);
      }

      svg.querySelectorAll('rect').forEach((el) => remapAttr(el, 'fill'));
      svg.querySelectorAll('line').forEach((el) => remapAttr(el, 'stroke'));
      svg.querySelectorAll('path').forEach((el) => { remapAttr(el, 'stroke'); remapAttr(el, 'fill'); });
      svg.querySelectorAll('ellipse').forEach((el) => { remapAttr(el, 'fill'); remapAttr(el, 'stroke'); });
      svg.querySelectorAll('polygon').forEach((el) => { remapAttr(el, 'stroke'); remapAttr(el, 'fill'); });
      svg.querySelectorAll('text').forEach((el) => el.setAttribute('fill', palette.svgToolbarText));
      svg.querySelectorAll('circle').forEach((el) => { if (!eyeSet.has(el)) remapAttr(el, 'fill'); });
    });
  }

  function applyLegacySkin() {
    try {
      if (state.skinApplying) return;
      state.skinApplying = true;
      const root = document.getElementById('jsme_container');
      if (!root) return;
      const palette = themePalette();
      const rootRect = root.getBoundingClientRect();
      if (!rootRect.width || !rootRect.height) return;

      root.style.background = palette.canvas;
      root.style.border = `1px solid ${palette.border}`;
      root.style.borderRadius = '12px';
      root.style.overflow = 'hidden';

      const nodes = root.querySelectorAll('div, td, span, button, a');
      nodes.forEach((node) => {
        const rect = node.getBoundingClientRect();
        if (!rect.width || !rect.height) return;
        const cs = window.getComputedStyle(node);
        const text = (node.textContent || '').trim();
        const isToolbarCell = rect.top - rootRect.top < 44 && rect.height <= 44;
        const isSideCell =
          rect.left - rootRect.left < 46 && rect.height <= 40 && rect.width <= 42;
        const isTinyTool =
          rect.width <= 44 &&
          rect.height <= 44 &&
          (text.length <= 3 || cs.cursor === 'pointer');

        if (isToolbarCell || isSideCell || isTinyTool) {
          node.classList.add('chemvision-skin-tool');
          node.style.setProperty('background', palette.panelSoft, 'important');
          node.style.setProperty('color', palette.text, 'important');
          node.style.setProperty('border-color', palette.border, 'important');
          node.style.setProperty('box-sizing', 'border-box', 'important');
          node.style.setProperty('border-radius', '8px', 'important');
          const imgs = node.querySelectorAll('img');
          imgs.forEach((img) => {
            if (state.theme === 'light') {
              img.style.setProperty('filter', 'saturate(0.9) hue-rotate(0deg)', 'important');
            } else {
              img.style.setProperty('filter', 'invert(0.92) hue-rotate(155deg) saturate(0.9)', 'important');
            }
          });
        }

        if (isSideCell && text.length >= 1 && text.length <= 2) {
          node.classList.add('chemvision-skin-side');
          node.style.setProperty('font-weight', '700', 'important');
          node.style.setProperty('color', palette.accent, 'important');
        }
      });

      const canvases = root.querySelectorAll('canvas, svg');
      canvases.forEach((canvas) => {
        canvas.style.background = palette.canvas;
        canvas.style.borderColor = palette.border;
      });

      const resetDivs = root.querySelectorAll('.jsa-resetDiv');
      if (resetDivs.length > 0 && !state.resetDivDetected) {
        state.resetDivDetected = true;
        debugLog('info', 'jsa-resetDiv detected', { count: resetDivs.length });
      }
      resetDivs.forEach((node) => {
        node.style.setProperty('background', 'transparent', 'important');
        node.style.setProperty('color', palette.text, 'important');
        node.style.setProperty('border-color', 'transparent', 'important');
        node.style.setProperty('box-shadow', 'none', 'important');
      });

      // SVG 级样式：直接修改工具栏/侧栏/画布的 SVG 元素颜色
      applySvgSkin();
    } catch (error) {
      debugLog('warn', 'applyLegacySkin failed', { error: String(error) });
    } finally {
      state.skinApplying = false;
    }
  }

  function scheduleLegacySkinApply() {
    if (state.skinRaf) {
      cancelAnimationFrame(state.skinRaf);
    }
    state.skinRaf = requestAnimationFrame(() => {
      state.skinRaf = 0;
      applyLegacySkin();
    });
  }

  function watchLegacyUiMutations() {
    if (state.skinObserver) return;
    state.skinObserver = new MutationObserver(() => {
      if (state.skinApplying) return;
      scheduleLegacySkinApply();
    });
    state.skinObserver.observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['fill', 'stroke', 'style', 'class'],
    });
  }

  function scheduleRenderHealthCheck() {
    if (state.healthTimer) {
      clearTimeout(state.healthTimer);
      state.healthTimer = null;
    }
    state.healthTimer = setTimeout(() => {
      state.healthTimer = null;
      const root = document.getElementById('jsme_container');
      if (!root) {
        debugLog('warn', 'render health: container missing');
        return;
      }
      const rect = root.getBoundingClientRect();
      const childCount = root.children ? root.children.length : 0;
      const hasCanvas = root.querySelectorAll('canvas,svg').length;
      debugLog('info', 'render health snapshot', {
        width: Math.round(rect.width || 0),
        height: Math.round(rect.height || 0),
        childCount,
        hasCanvas,
        hasEditor: Boolean(state.editor),
      });
      if (hasCanvas > 0 || childCount > 0) {
        hideLoading();
        return;
      }
      showLoading('JSME 渲染异常，正在回退样式…');
      setStatus(`SMILES 长度 ${(state.smiles || '').length} · UI加载异常`);
      const style = document.getElementById('chemvision-jsme-modern-style');
      if (style) {
        style.remove();
      }
      disposeSkinWatchers();
    }, 1600);
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
      #jsme_container .chemvision-skin-tool {
        border: 1px solid var(--action-border) !important;
      }
      #jsme_container .chemvision-skin-side {
        text-shadow: 0 0 8px rgba(56, 213, 193, 0.22) !important;
      }
      :root[data-theme='light'] #jsme_container .chemvision-skin-side {
        text-shadow: 0 0 8px rgba(31, 72, 179, 0.18) !important;
      }
      #jsme_container .jsa-resetDiv {
        background: transparent !important;
        color: var(--title) !important;
        border-color: transparent !important;
      }
      #jsme_container .jsa-resetDiv td,
      #jsme_container .jsa-resetDiv div,
      #jsme_container .jsa-resetDiv span,
      #jsme_container .jsa-resetDiv button {
        color: var(--title) !important;
        border-color: transparent !important;
      }
      #jsme_container .jsa-resetDiv td {
        background: transparent !important;
      }
      #jsme_container .jsa-resetDiv img {
        filter: invert(0.92) hue-rotate(155deg) saturate(0.9) !important;
      }
      :root[data-theme='light'] #jsme_container .jsa-resetDiv img {
        filter: saturate(0.9) hue-rotate(0deg) !important;
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
    if (state.skinRaf) {
      cancelAnimationFrame(state.skinRaf);
      state.skinRaf = 0;
    }
    if (state.healthTimer) {
      clearTimeout(state.healthTimer);
      state.healthTimer = null;
    }
  }

  function disposeSkinWatchers() {
    if (state.skinObserver) {
      state.skinObserver.disconnect();
      state.skinObserver = null;
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
    updateStatusBySmiles(smiles);
    postToHost('onSmilesUpdated', { smiles });
  }

  function setSmiles(smiles) {
    state.smiles = smiles || '';
    updateStatusBySmiles(state.smiles);
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
    // 详细诊断：检查 GWT 加载状态
    const diag = {
      attempt,
      hasJSApplet: Boolean(window.JSApplet),
      hasJSME: Boolean(window.JSApplet && window.JSApplet.JSME),
      loadedFlag: Boolean(window.__chemvisionJsmeLoaded),
      scriptCount: document.querySelectorAll('script').length,
      pageUrl: location.href,
    };
    if (attempt === 0 || attempt % 10 === 0) {
      debugLog('info', 'initEditor attempt', diag);
    }
    // 第一次尝试时检查 GWT 模块是否已下载
    if (attempt === 1 && !window.__chemvisionJsmeLoaded) {
      debugLog('warn', 'GWT module NOT loaded after 200ms — jsmeOnLoad never called', {
        hasJSApplet: Boolean(window.JSApplet),
        baseURI: document.baseURI,
      });
    }
    if ((attempt === 6 || attempt === 15) && !window.JSApplet && typeof window.__chemvisionEnsureJsmeCore === 'function') {
      window.__chemvisionEnsureJsmeCore(`init-attempt-${attempt}`);
    }
    if (window.JSApplet && window.JSApplet.JSME) {
      try {
        setStatus(`SMILES 长度 ${(state.smiles || '').length} · 初始化中`);
        state.editor = new window.JSApplet.JSME(
          'jsme_container',
          '100%',
          '100%',
          { options: 'star' }
        );
        injectModernEditorStyles();
        applyTheme(state.theme);
        showLoading('正在构建编辑器界面…');
        if (state.smiles) {
          setSmiles(state.smiles);
        }
        state.lastSentSmiles = getSmiles();
        clearPollTimer();
        state.pollTimer = window.setInterval(emitSmilesIfChanged, 450);
        watchLegacyUiMutations();
        if (!state.bridgeReadySent) {
          state.bridgeReadySent = true;
          postToHost('onBridgeReady', {});
        }
        debugLog('info', 'JSME initialized successfully');
        updateStatusBySmiles(state.lastSentSmiles || state.smiles);
        scheduleLegacySkinApply();
        scheduleRenderHealthCheck();
        return;
      } catch (error) {
        state.initFailed = true;
        setStatus(`SMILES 长度 ${(state.smiles || '').length} · 初始化失败`);
        reportError('初始化 JSME 失败', { error: String(error), stack: error && error.stack ? String(error.stack) : null });
        return;
      }
    }
    if (attempt >= 80) {
      setStatus(`SMILES 长度 ${(state.smiles || '').length} · 加载超时`);
      reportError('JSME 加载超时，请检查网络后重试', {
        hasJSApplet: Boolean(window.JSApplet),
        hasJSME: Boolean(window.JSApplet && window.JSApplet.JSME),
        pageUrl: location.href,
        baseURI: document.baseURI,
        scriptCount: document.querySelectorAll('script').length,
        loadedFlag: Boolean(window.__chemvisionJsmeLoaded),
      });
      state.initFailed = true;
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
    if (data.type !== 'setSmiles' && data.type !== 'setTheme') {
      debugLog('info', 'bridge message received', { type: data.type });
    }
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

  window.addEventListener('beforeunload', () => {
    clearPollTimer();
    disposeSkinWatchers();
  });
  window.addEventListener('pagehide', () => {
    clearPollTimer();
    disposeSkinWatchers();
  });
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
    bindQuickActions();
    applyTheme(state.theme);
    setStatus(`SMILES 长度 ${(state.smiles || '').length} · 等待内核`);
    debugLog('info', 'DOMContentLoaded', {
      loadedFlag: Boolean(window.__chemvisionJsmeLoaded),
      hasInitHook: typeof window.__chemvisionInitJsme === 'function',
      pageUrl: location.href,
      baseURI: document.baseURI,
      hasJSApplet: Boolean(window.JSApplet),
    });
    if (window.__chemvisionJsmeLoaded) {
      initEditor(0);
      return;
    }
    window.setTimeout(() => initEditor(0), 200);
    window.setTimeout(() => {
      if (!state.editor && !window.JSApplet && typeof window.__chemvisionEnsureJsmeCore === 'function') {
        window.__chemvisionEnsureJsmeCore('dom-timeout-1000ms');
      }
    }, 1000);
    // GWT 加载超时检测：8 秒后仍未加载则输出详细诊断
    window.setTimeout(() => {
      if (!state.editor && !state.initFailed) {
        debugLog('error', 'GWT load timeout — detailed diagnostics', {
          loadedFlag: Boolean(window.__chemvisionJsmeLoaded),
          hasJSApplet: Boolean(window.JSApplet),
          hasJSME: Boolean(window.JSApplet && window.JSApplet.JSME),
          scriptTags: document.querySelectorAll('script').length,
          pageUrl: location.href,
          baseURI: document.baseURI,
          readyState: document.readyState,
        });
      }
    }, 8000);
  });
})();
