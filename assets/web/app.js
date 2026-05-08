(function () {
  const params = new URLSearchParams(window.location.search);
  const channel = params.get('channel') || 'chemvision';
  let compactMode = params.get('compact') === '1';
  let readOnlyMode = params.get('readOnly') === '1';
  const state = {
    smiles: '',
    atoms: [],
    selectedId: null,
    drag: null,
    molecule: null,
    atomIndexById: new Map(),
    moleculeJson: null,
  };

  const atomList = document.getElementById('atom-list');
  const smilesText = document.getElementById('smiles-text');
  const structureCanvas = document.getElementById('smiles-canvas');
  const engineLabel = document.getElementById('engine-label');
  const hint = document.getElementById('hint');
  let svgDrawer = null;
  let _drawerSize = { w: 0, h: 0 };

  function setCompactMode(enabled) {
    compactMode = Boolean(enabled);
    document.body.classList.toggle('compact-mode', compactMode);
    const renderArea = document.getElementById('render-area');
    if (renderArea) {
      renderArea.classList.toggle('compact-mode', compactMode);
    }
    if (smilesText) {
      smilesText.style.display = compactMode ? 'none' : '';
    }
    if (atomList) {
      atomList.style.display = compactMode ? 'none' : '';
    }
    if (hint) {
      hint.style.display = compactMode ? 'none' : '';
    }
    if (engineLabel) {
      engineLabel.style.display = compactMode ? 'none' : '';
    }
    drawSmiles(state.smiles);
  }

  function setReadOnly(enabled) {
    readOnlyMode = Boolean(enabled);
    if (readOnlyMode) {
      // Hide atom list and interactive elements
      if (atomList) {
        atomList.style.display = 'none';
      }
      if (hint) {
        hint.style.display = 'none';
      }
      // Disable pointer events on the structure view to prevent pan/zoom
      const view = document.getElementById('structure-view');
      if (view) {
        view.style.pointerEvents = 'none';
      }
    }
  }

  const drawerTheme = {
    C: '#e8f6f3',
    O: '#f6b355',
    N: '#9bc4ff',
    S: '#ffd166',
    F: '#b7f171',
    Cl: '#9cd1ff',
    Br: '#f4a6c8',
    I: '#cda2ff',
    P: '#f6d365',
    B: '#9ee493',
    Si: '#c5d1ff',
    H: '#aab4c8',
    BACKGROUND: '#0b0f1a',
  };

  const fallbackAtomicNo = {
    H: 1,
    B: 5,
    C: 6,
    N: 7,
    O: 8,
    F: 9,
    Si: 14,
    P: 15,
    S: 16,
    Cl: 17,
    Br: 35,
    I: 53,
  };

  const fallbackLabel = Object.entries(fallbackAtomicNo).reduce(
    (acc, [label, no]) => {
      acc[no] = label;
      return acc;
    },
    {}
  );

  function postToHost(type, payload) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler(type, payload);
      return;
    }
    if (!window.parent) {
      return;
    }
    window.parent.postMessage({ channel, type, payload }, '*');
  }

  function isOclReady() {
    return Boolean(window.OCL && window.OCL.Molecule);
  }

  function getAtomicNoFromLabel(label) {
    if (isOclReady() && window.OCL.Molecule.getAtomicNoFromLabel) {
      return window.OCL.Molecule.getAtomicNoFromLabel(label);
    }
    return fallbackAtomicNo[label] || 6;
  }

  function getLabelFromAtomicNo(atomicNo) {
    return fallbackLabel[atomicNo] || 'C';
  }

  function moleculeFromSmiles(smiles) {
    if (!isOclReady() || !smiles) {
      return null;
    }
    try {
      return window.OCL.Molecule.fromSmiles(smiles);
    } catch (error) {
      return null;
    }
  }

  function extractAtoms(smiles) {
    const matches = smiles.match(/[A-Z][a-z]?/g);
    if (!matches) {
      return [];
    }
    return matches.map((element, index) => ({
      id: `a${index}`,
      element,
    }));
  }

  function atomsFromMolecule(molecule) {
    if (!molecule || !molecule.getAllAtoms) {
      return [];
    }
    const atoms = [];
    const map = new Map();
    const total = molecule.getAllAtoms();
    for (let i = 0; i < total; i++) {
      let label = '';
      if (molecule.getAtomLabel) {
        label = molecule.getAtomLabel(i);
      }
      if (!label && molecule.getAtomicNo) {
        label = getLabelFromAtomicNo(molecule.getAtomicNo(i));
      }
      label = label || 'C';
      const id = `a${i}`;
      map.set(id, i);
      atoms.push({ id, element: label });
    }
    state.atomIndexById = map;
    return atoms;
  }

  function clearChildren(node) {
    while (node.firstChild) {
      node.removeChild(node.firstChild);
    }
  }

  function updateSmilesDisplay() {
    if (smilesText) {
      smilesText.textContent = `SMILES: ${state.smiles || '-'}`;
    }
  }

  function getSvgDrawer() {
    if (!structureCanvas || !window.SmilesDrawer || !window.SmilesDrawer.SvgDrawer) {
      return null;
    }
    const w = Math.max(80, Math.floor(structureCanvas.clientWidth || 320));
    const h = Math.max(72, Math.floor(w * (compactMode ? 0.62 : 0.7)));
    const padding = compactMode
        ? Math.max(4, Math.floor(Math.min(w, h) * 0.03))
        : Math.max(10, Math.floor(Math.min(w, h) * 0.08));
    const bondLength = compactMode
        ? Math.max(6, Math.floor(Math.min(w, h) * 0.05))
        : Math.max(12, Math.floor(Math.min(w, h) * 0.1));
    if (!svgDrawer || _drawerSize.w !== w || _drawerSize.h !== h) {
      // recreate drawer to match current canvas size
      svgDrawer = new window.SmilesDrawer.SvgDrawer({
        width: w,
        height: h,
        padding: padding,
        bondThickness: 2,
        bondLength: bondLength,
        atomVisualization: 'default',
        themes: {
          custom: drawerTheme,
        },
      });
      _drawerSize = { w, h };
    }
    return svgDrawer;
  }

  function clearSvg() {
    if (!structureCanvas) {
      return;
    }
    while (structureCanvas.firstChild) {
      structureCanvas.removeChild(structureCanvas.firstChild);
    }
  }

  function drawSmiles(smiles) {
    const drawer = getSvgDrawer();
    if (!drawer) {
      clearSvg();
      return;
    }
    if (!smiles) {
      clearSvg();
      return;
    }
    // ensure drawer matches current canvas size before parsing
    // parse and draw, then fit by using drawer dimensions
    window.SmilesDrawer.parse(
      smiles,
      (tree) => {
        clearSvg();
        try {
          drawer.draw(tree, structureCanvas, 'custom', false);
          fitDrawingToViewport();
        } catch (err) {
          // fallback: clear and no-op
          clearSvg();
        }
      },
      () => {
        clearSvg();
      }
    );
  }

  function fitDrawingToViewport() {
    if (!structureCanvas) {
      return;
    }
    const svg = structureCanvas.querySelector('svg');
    if (!svg) {
      return;
    }
    try {
      const bbox = svg.getBBox();
      if (!bbox.width || !bbox.height) {
        return;
      }
      const margin = compactMode ? 12 : 18;
      const viewWidth = structureCanvas.clientWidth || bbox.width;
      const viewHeight = structureCanvas.clientHeight || bbox.height;
      const contentWidth = Math.max(1, bbox.width + margin * 2);
      const contentHeight = Math.max(1, bbox.height + margin * 2);
      svg.setAttribute('viewBox', `${bbox.x - margin} ${bbox.y - margin} ${contentWidth} ${contentHeight}`);
      svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
      svg.style.width = '100%';
      svg.style.height = '100%';
      svg.style.transformOrigin = 'center center';
      const scale = Math.min(viewWidth / contentWidth, viewHeight / contentHeight, compactMode ? 1.6 : 1.35);
      svg.style.transform = `translate(${Math.max(0, (viewWidth - contentWidth * scale) / 2)}px, ${Math.max(0, (viewHeight - contentHeight * scale) / 2)}px) scale(${scale})`;
    } catch (error) {
      const rect = svg.getBoundingClientRect();
      if (!rect.width || !rect.height) {
        return;
      }
      const viewWidth = structureCanvas.clientWidth || rect.width;
      const viewHeight = structureCanvas.clientHeight || rect.height;
      const scale = Math.min(viewWidth / rect.width, viewHeight / rect.height, compactMode ? 1.6 : 1.35);
      const translateX = Math.max(0, (viewWidth - rect.width * scale) / 2);
      const translateY = Math.max(0, (viewHeight - rect.height * scale) / 2);
      svg.style.transformOrigin = 'top left';
      svg.style.transform = `translate(${translateX}px, ${translateY}px) scale(${scale})`;
    }
  }

  function updateSelection() {
    const nodes = atomList.querySelectorAll('.atom');
    nodes.forEach((node) => {
      const id = node.getAttribute('data-atom-id');
      if (id === state.selectedId) {
        node.classList.add('selected');
      } else {
        node.classList.remove('selected');
      }
    });
  }

  function updateSmilesFromMolecule(source) {
    if (!state.molecule || !state.molecule.toSmiles) {
      return;
    }
    try {
      state.smiles = state.molecule.toSmiles();
      updateSmilesDisplay();
      drawSmiles(state.smiles);
      postToHost('onSmilesUpdated', {
        smiles: state.smiles,
        source,
      });
    } catch (error) {
      // Ignore SMILES generation errors for now.
    }
  }

  function selectAtom(atom) {
    state.selectedId = atom.id;
    updateSelection();
    postToHost('onAtomSelected', {
      atomId: atom.id,
      element: atom.element,
    });
  }

  function startDrag(event, atom, node) {
    state.drag = {
      atomId: atom.id,
      element: atom.element,
      startX: event.clientX,
      startY: event.clientY,
      node,
    };
    node.classList.add('dragging');
    node.setPointerCapture(event.pointerId);
  }

  function moveDrag(event) {
    if (!state.drag) {
      return;
    }
    const dx = event.clientX - state.drag.startX;
    const dy = event.clientY - state.drag.startY;
    state.drag.node.style.transform = `translate3d(${dx}px, ${dy}px, 0)`;
  }

  function endDrag(event) {
    if (!state.drag) {
      return;
    }
    const dx = event.clientX - state.drag.startX;
    const dy = event.clientY - state.drag.startY;
    const node = state.drag.node;

    node.classList.remove('dragging');
    node.style.transform = '';

    postToHost('onAtomDragEnd', {
      atomId: state.drag.atomId,
      element: state.drag.element,
      dx,
      dy,
    });

    state.drag = null;
    renderAtoms();
  }

  function renderAtoms() {
    clearChildren(atomList);
    state.atoms.forEach((atom) => {
      const span = document.createElement('span');
      span.className = 'atom';
      span.textContent = atom.element;
      span.setAttribute('data-atom-id', atom.id);

      span.addEventListener('click', () => selectAtom(atom));

      span.addEventListener('pointerdown', (event) => {
        startDrag(event, atom, span);
      });
      span.addEventListener('pointermove', (event) => {
        moveDrag(event);
      });
      span.addEventListener('pointerup', (event) => {
        endDrag(event);
      });

      atomList.appendChild(span);
    });
    updateSelection();
  }

  function renderSmiles(smiles) {
    state.smiles = smiles || '';
    const molecule = moleculeFromSmiles(state.smiles);
    if (molecule) {
      state.molecule = molecule;
      try {
        state.smiles = molecule.toSmiles();
      } catch (error) {
        // Keep original if canonicalization fails.
      }
      state.atoms = atomsFromMolecule(molecule);
    } else {
      state.molecule = null;
      state.atoms = extractAtoms(state.smiles);
    }
    updateSmilesDisplay();
    renderAtoms();
    drawSmiles(state.smiles);
  }

  function updateAtomElement(atomId, element) {
    if (!state.molecule || !state.molecule.setAtomicNo) {
      return;
    }
    const index = state.atomIndexById.get(atomId);
    if (index === undefined) {
      return;
    }
    const atomicNo = getAtomicNoFromLabel(element);
    state.molecule.setAtomicNo(index, atomicNo);
    state.atoms = atomsFromMolecule(state.molecule);
    renderAtoms();
    updateSmilesFromMolecule('edit');
  }

  // Pan and zoom support for the structure viewport.
  (function enablePanZoom() {
    const view = document.getElementById('structure-view');
    let scale = 1;
    let tx = 0;
    let ty = 0;
    let isPanning = false;
    let panStart = { x: 0, y: 0, tx: 0, ty: 0 };

    function applyTransform() {
      if (!structureCanvas) return;
      structureCanvas.style.transform = `translate(${tx}px, ${ty}px) scale(${scale})`;
    }

    view.addEventListener('wheel', (e) => {
      e.preventDefault();
      const delta = -e.deltaY;
      const factor = delta > 0 ? 1.08 : 0.92;
      const newScale = Math.min(4, Math.max(0.3, scale * factor));
      // zoom to pointer
      const rect = structureCanvas.getBoundingClientRect();
      const px = e.clientX - rect.left;
      const py = e.clientY - rect.top;
      const dx = (px - tx) / scale;
      const dy = (py - ty) / scale;
      tx = px - dx * newScale;
      ty = py - dy * newScale;
      scale = newScale;
      applyTransform();
    }, { passive: false });

    view.addEventListener('pointerdown', (e) => {
      // ignore when clicking atoms (they have .atom class)
      const target = e.target;
      if (target && target.classList && target.classList.contains('atom')) {
        return;
      }
      isPanning = true;
      panStart = { x: e.clientX, y: e.clientY, tx, ty };
      view.classList.add('panning');
      view.setPointerCapture(e.pointerId);
    });

    view.addEventListener('pointermove', (e) => {
      if (!isPanning) return;
      const dx = e.clientX - panStart.x;
      const dy = e.clientY - panStart.y;
      tx = panStart.tx + dx;
      ty = panStart.ty + dy;
      applyTransform();
    });

    function endPan(e) {
      if (!isPanning) return;
      isPanning = false;
      try { view.releasePointerCapture(e.pointerId); } catch (_) {}
      view.classList.remove('panning');
    }

    view.addEventListener('pointerup', endPan);
    view.addEventListener('pointercancel', endPan);
  })();

  window.renderSmiles = renderSmiles;
  window.setCompactMode = setCompactMode;
  window.setReadOnly = setReadOnly;
  window.getSmiles = function () {
    if (!state.molecule) {
      return state.smiles;
    }
    return state.molecule.toSmiles();
  };
  window.exportSvg = function () {
    try {
      const container = structureCanvas || document.getElementById('smiles-canvas');
      if (!container) {
        return null;
      }
      const svg = container.querySelector('svg');
      if (!svg) {
        return null;
      }
      const clone = svg.cloneNode(true);
      clone.removeAttribute('transform');
      const styles = clone.querySelectorAll('style');
      styles.forEach(style => style.remove());
      if (!clone.getAttribute('viewBox')) {
        try {
          const bbox = svg.getBBox();
          clone.setAttribute('viewBox', `${bbox.x} ${bbox.y} ${bbox.width} ${bbox.height}`);
        } catch (e) {
          clone.setAttribute('viewBox', '0 0 300 300');
        }
      }
      clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
      clone.setAttribute('width', '300');
      clone.setAttribute('height', '300');
      const svgString = new XMLSerializer().serializeToString(clone);
      return svgString && svgString.length > 50 ? svgString : null;
    } catch (error) {
      console.error('exportSvg error:', error);
      return null;
    }
  };
  window.renderPng = function (scale) {
    scale = scale || 2;
    const container = structureCanvas || document.getElementById('smiles-canvas');
    if (!container) {
      postToHost('exportPngResult', { dataUrl: null });
      return;
    }
    const svg = container.querySelector('svg');
    if (!svg) {
      postToHost('exportPngResult', { dataUrl: null });
      return;
    }
    try {
      const clone = svg.cloneNode(true);
      clone.removeAttribute('transform');
      const styles = clone.querySelectorAll('style');
      styles.forEach(function (s) { s.remove(); });
      if (!clone.getAttribute('viewBox')) {
        try {
          var bbox = svg.getBBox();
          clone.setAttribute('viewBox', bbox.x + ' ' + bbox.y + ' ' + bbox.width + ' ' + bbox.height);
        } catch (e) {
          clone.setAttribute('viewBox', '0 0 300 300');
        }
      }
      clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
      var svgString = new XMLSerializer().serializeToString(clone);
      var vb = clone.getAttribute('viewBox').split(' ').map(Number);
      var w = Math.round((vb[2] || 300) * scale);
      var h = Math.round((vb[3] || 300) * scale);
      var blob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
      var url = URL.createObjectURL(blob);
      var img = new Image();
      img.onload = function () {
        var canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        var ctx = canvas.getContext('2d');
        ctx.fillStyle = '#0b0f1a';
        ctx.fillRect(0, 0, w, h);
        ctx.drawImage(img, 0, 0, w, h);
        URL.revokeObjectURL(url);
        postToHost('exportPngResult', { dataUrl: canvas.toDataURL('image/png') });
      };
      img.onerror = function () {
        URL.revokeObjectURL(url);
        postToHost('exportPngResult', { dataUrl: null });
      };
      img.src = url;
    } catch (err) {
      postToHost('exportPngResult', { dataUrl: null });
    }
  };
  window.setMoleculeJson = function (json) {
    try {
      state.moleculeJson = typeof json === 'string' ? JSON.parse(json) : json;
    } catch (error) {
      state.moleculeJson = null;
    }

    if (state.moleculeJson && state.moleculeJson.smiles) {
      renderSmiles(state.moleculeJson.smiles);
      updateSmilesFromMolecule('snapshot');
      return;
    }

    if (state.moleculeJson && Array.isArray(state.moleculeJson.atoms)) {
      state.atoms = state.moleculeJson.atoms.map((atom, index) => ({
        id: atom.id || `a${index}`,
        element: atom.element || 'C',
      }));
      renderAtoms();
    }
  };
  window.updateAtomElement = updateAtomElement;

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || data.channel !== channel) {
      return;
    }
    const payload = data.payload || {};
    switch (data.type) {
      case 'renderSmiles':
        renderSmiles(payload.smiles);
        break;
      case 'updateAtomElement':
        updateAtomElement(payload.atomId, payload.element);
        break;
      case 'setMoleculeJson':
        window.setMoleculeJson(payload);
        break;
      case 'setReadOnly':
        setReadOnly(payload.readOnly);
        break;
      case 'exportSvg': {
        const svgString = window.exportSvg();
        postToHost('exportSvgResult', { svgString });
        break;
      }
      case 'renderPng':
        window.renderPng(2);
        break;
      default:
        break;
    }
  });

  document.addEventListener('DOMContentLoaded', function () {
    setCompactMode(compactMode);
    if (readOnlyMode) {
      setReadOnly(true);
    }
    postToHost('onBridgeReady', {});
  });
})();
