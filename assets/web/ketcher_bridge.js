/**
 * Ketcher Bridge Script v2
 *
 * 在 Ketcher standalone iframe 中加载，提供 postMessage 通信接口。
 * 等待 Ketcher 的 init 事件后再暴露 API。
 */

(function () {
  'use strict';

  let currentChannel = null;
  let lastSmiles = '';
  let pollTimer = null;
  let ketcherReady = false;

  function postToHost(type, payload) {
    if (!currentChannel) return;
    window.parent.postMessage(
      { channel: currentChannel, type: type, payload: payload || {} },
      '*',
    );
  }

  function waitForKetcher() {
    return new Promise((resolve) => {
      if (ketcherReady && window.ketcher) {
        resolve(window.ketcher);
        return;
      }
      const check = setInterval(() => {
        if (window.ketcher) {
          ketcherReady = true;
          clearInterval(check);
          resolve(window.ketcher);
        }
      }, 300);
      setTimeout(() => {
        clearInterval(check);
        resolve(null);
      }, 20000);
    });
  }

  function startSmilesPolling() {
    if (pollTimer) return;
    pollTimer = setInterval(async () => {
      try {
        const ketcher = window.ketcher;
        if (!ketcher || typeof ketcher.getSmiles !== 'function') return;
        const smiles = await ketcher.getSmiles();
        if (smiles !== undefined && smiles !== null && smiles !== lastSmiles) {
          lastSmiles = smiles;
          postToHost('onSmilesUpdated', { smiles: smiles });
        }
      } catch (e) {
        // Ignore polling errors
      }
    }, 600);
  }

  // 监听 Ketcher 自身的 init 事件（由 main.js 中 onInit 回调发送）
  window.addEventListener('message', function (e) {
    if (e.data && e.data.eventType === 'init') {
      ketcherReady = true;
      startSmilesPolling();
    }
  });

  // 监听 Flutter 发来的指令
  window.addEventListener('message', async function (e) {
    const data = e.data;
    if (!data || !data.type || !data.channel) return;

    currentChannel = data.channel;
    const type = data.type;
    const payload = data.payload || {};

    try {
      const ketcher = await waitForKetcher();
      if (!ketcher) {
        postToHost('onError', { message: 'Ketcher 未加载（超时 20s）' });
        return;
      }

      switch (type) {
        case 'setMolecule': {
          try {
            await ketcher.setMolecule(payload.data || '');
            lastSmiles = '';
            startSmilesPolling();
            postToHost('onSetMoleculeSuccess', {});
          } catch (err) {
            postToHost('onError', { message: 'setMolecule 失败: ' + String(err) });
          }
          break;
        }

        case 'getSmiles': {
          try {
            const smiles = await ketcher.getSmiles();
            postToHost('getSmilesResult', {
              requestId: payload.requestId,
              smiles: smiles || '',
            });
          } catch (err) {
            postToHost('getSmilesResult', {
              requestId: payload.requestId,
              smiles: '',
            });
          }
          break;
        }

        case 'getRxn': {
          try {
            const rxn = await ketcher.getRxn();
            postToHost('getRxnResult', {
              requestId: payload.requestId,
              rxn: rxn || '',
            });
          } catch (err) {
            postToHost('getRxnResult', {
              requestId: payload.requestId,
              rxn: '',
            });
          }
          break;
        }

        case 'exportSvg': {
          try {
            // 使用 Ketcher 内置的 SVG 导出
            if (ketcher.generateImage) {
              const structData = payload.data || (await ketcher.getSmiles()) || '';
              const result = await ketcher.generateImage(structData, { outputFormat: 'svg' });
              postToHost('exportSvgResult', { svgString: result });
            } else {
              // 回退：从 DOM 中提取 SVG
              const svgEl = document.querySelector('#root svg');
              if (svgEl) {
                const clone = svgEl.cloneNode(true);
                clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
                const svgString = new XMLSerializer().serializeToString(clone);
                postToHost('exportSvgResult', { svgString: svgString });
              } else {
                postToHost('onError', { message: 'SVG 导出不可用' });
              }
            }
          } catch (err) {
            postToHost('onError', { message: 'SVG 导出失败: ' + String(err) });
          }
          break;
        }

        case 'exportPng': {
          try {
            if (ketcher.generateImage) {
              const structData = payload.data || (await ketcher.getSmiles()) || '';
              const result = await ketcher.generateImage(structData, {
                outputFormat: 'png',
                backgroundColor: '#0b0f1a',
              });
              postToHost('exportPngResult', { dataUrl: result });
            } else {
              postToHost('onError', { message: 'PNG 导出不可用' });
            }
          } catch (err) {
            postToHost('onError', { message: 'PNG 导出失败: ' + String(err) });
          }
          break;
        }

        case 'setTheme': {
          const mode = payload.mode || 'dark';
          if (mode === 'dark') {
            document.documentElement.style.setProperty('color-scheme', 'dark');
            document.body.style.backgroundColor = '#0d1627';
            // 注入暗色主题 CSS
            let style = document.getElementById('cv-dark-theme');
            if (!style) {
              style = document.createElement('style');
              style.id = 'cv-dark-theme';
              style.textContent = `
                :root { color-scheme: dark; }
                body { background: #0d1627 !important; }
                #root { background: #0d1627 !important; }
                .Ketcher-module_editor__MWDZk,
                .editor-container,
                .polymer-editor-ref,
                [class*="editor"],
                [class*="canvas"] {
                  background: #0f172a !important;
                }
                .Ketcher-module_toolbar__MWLPQ,
                [class*="toolbar"],
                [class*="menu"],
                [class*="panel"],
                [class*="sidebar"],
                [class*="modal"],
                [class*="dialog"],
                [class*="dropdown"],
                [class*="popup"] {
                  background: #0f172a !important;
                  color: #e9eef5 !important;
                  border-color: rgba(255,255,255,0.1) !important;
                }
                [class*="button"],
                button {
                  background: rgba(255,255,255,0.08) !important;
                  color: #e9eef5 !important;
                  border-color: rgba(255,255,255,0.12) !important;
                }
                [class*="button"]:hover,
                button:hover {
                  background: rgba(56,213,193,0.2) !important;
                }
                input, select, textarea {
                  background: rgba(255,255,255,0.05) !important;
                  color: #e9eef5 !important;
                  border-color: rgba(255,255,255,0.12) !important;
                }
                [class*="label"],
                [class*="text"],
                [class*="title"],
                span, p, h1, h2, h3, h4, h5, h6 {
                  color: #e9eef5 !important;
                }
                [class*="icon"],
                svg:not([class*="struct"]):not([class*="molecule"]) {
                  fill: #b9c7de !important;
                }
                .Ketcher-module_canvas__*,
                [class*="canvas"] svg {
                  background: #0f172a !important;
                }
              `;
              document.head.appendChild(style);
            }
          } else {
            document.documentElement.style.removeProperty('color-scheme');
            document.body.style.backgroundColor = '';
            const style = document.getElementById('cv-dark-theme');
            if (style) style.remove();
          }
          break;
        }

        case 'setReadOnly': {
          const editor = document.querySelector('#root');
          if (editor) {
            editor.style.pointerEvents = payload.readOnly ? 'none' : '';
          }
          break;
        }

        default:
          break;
      }
    } catch (err) {
      postToHost('onError', { message: String(err) });
    }
  });

  // Signal ready when ketcher is available
  waitForKetcher().then((ketcher) => {
    if (ketcher) {
      ketcherReady = true;
      postToHost('onBridgeReady', {});
      startSmilesPolling();
    }
  });
})();
