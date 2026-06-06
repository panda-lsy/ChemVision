/**
 * Ketcher Bridge Script
 *
 * 在 Ketcher standalone iframe 中加载，提供 postMessage 通信接口。
 * 在 ketcher/index.html 的 </body> 前通过 <script src="../ketcher_bridge.js"> 引入。
 *
 * 通信协议：
 *   接收 (Flutter → Ketcher):
 *     { channel, type: 'setMolecule',  payload: { data: 'SMILES/MOL/RXN' } }
 *     { channel, type: 'getSmiles',    payload: { requestId } }
 *     { channel, type: 'getRxn',       payload: { requestId } }
 *     { channel, type: 'exportSvg',    payload: { data? } }
 *     { channel, type: 'exportPng',    payload: { data? } }
 *     { channel, type: 'setTheme',     payload: { mode: 'dark'/'light' } }
 *     { channel, type: 'setReadOnly',  payload: { readOnly: true/false } }
 *
 *   发送 (Ketcher → Flutter):
 *     { channel, type: 'onBridgeReady' }
 *     { channel, type: 'getSmilesResult', payload: { requestId, smiles } }
 *     { channel, type: 'getRxnResult',    payload: { requestId, rxn } }
 *     { channel, type: 'exportSvgResult', payload: { svgString } }
 *     { channel, type: 'exportPngResult', payload: { dataUrl } }
 *     { channel, type: 'onSmilesUpdated', payload: { smiles } }
 *     { channel, type: 'onError',         payload: { message } }
 */

(function () {
  'use strict';

  let currentChannel = null;
  let lastSmiles = '';
  let pollTimer = null;

  function postToHost(type, payload) {
    if (!currentChannel) return;
    window.parent.postMessage(
      { channel: currentChannel, type: type, payload: payload || {} },
      '*',
    );
  }

  function waitForKetcher() {
    return new Promise((resolve) => {
      if (window.ketcher) {
        resolve(window.ketcher);
        return;
      }
      // Ketcher sets window.ketcher via onInit callback
      const check = setInterval(() => {
        if (window.ketcher) {
          clearInterval(check);
          resolve(window.ketcher);
        }
      }, 200);
      // Timeout after 15s
      setTimeout(() => {
        clearInterval(check);
        resolve(null);
      }, 15000);
    });
  }

  function startSmilesPolling() {
    if (pollTimer) return;
    pollTimer = setInterval(async () => {
      try {
        const ketcher = window.ketcher;
        if (!ketcher) return;
        const smiles = await ketcher.getSmiles();
        if (smiles && smiles !== lastSmiles) {
          lastSmiles = smiles;
          postToHost('onSmilesUpdated', { smiles: smiles });
        }
      } catch (e) {
        // Ignore polling errors
      }
    }, 500);
  }

  window.addEventListener('message', async function (e) {
    const data = e.data;
    if (!data || !data.type) return;

    currentChannel = data.channel;
    const type = data.type;
    const payload = data.payload || {};

    try {
      const ketcher = await waitForKetcher();
      if (!ketcher) {
        postToHost('onError', { message: 'Ketcher 未加载' });
        return;
      }

      switch (type) {
        case 'setMolecule': {
          await ketcher.setMolecule(payload.data || '');
          lastSmiles = '';
          startSmilesPolling();
          break;
        }

        case 'getSmiles': {
          const smiles = await ketcher.getSmiles();
          postToHost('getSmilesResult', {
            requestId: payload.requestId,
            smiles: smiles || '',
          });
          break;
        }

        case 'getRxn': {
          const rxn = await ketcher.getRxn();
          postToHost('getRxnResult', {
            requestId: payload.requestId,
            rxn: rxn || '',
          });
          break;
        }

        case 'exportSvg': {
          const structData = payload.data || (await ketcher.getSmiles()) || '';
          if (ketcher.generateImage) {
            const result = await ketcher.generateImage(structData, {
              outputFormat: 'svg',
            });
            postToHost('exportSvgResult', { svgString: result });
          } else {
            // Fallback: get SVG from the editor's SVG element
            const svgEl = document.querySelector('.Ketcher-root svg');
            if (svgEl) {
              const svgString = new XMLSerializer().serializeToString(svgEl);
              postToHost('exportSvgResult', { svgString: svgString });
            } else {
              postToHost('onError', { message: 'SVG 导出不可用' });
            }
          }
          break;
        }

        case 'exportPng': {
          const structData2 = payload.data || (await ketcher.getSmiles()) || '';
          if (ketcher.generateImage) {
            const result = await ketcher.generateImage(structData2, {
              outputFormat: 'png',
              backgroundColor: '#0b0f1a',
            });
            postToHost('exportPngResult', { dataUrl: result });
          } else {
            postToHost('onError', { message: 'PNG 导出不可用' });
          }
          break;
        }

        case 'setTheme': {
          // Ketcher standalone may not have a public theme API,
          // but we can try toggling CSS classes
          const mode = payload.mode || 'dark';
          document.documentElement.setAttribute('data-theme', mode);
          break;
        }

        case 'setReadOnly': {
          // Ketcher doesn't have a direct read-only API in standalone mode
          // We can disable pointer events on the editor container
          const editor = document.querySelector('.Ketcher-root');
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

  // Signal ready
  waitForKetcher().then(() => {
    postToHost('onBridgeReady', {});
    startSmilesPolling();
  });
})();
