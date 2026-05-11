(function () {
  const params = new URLSearchParams(window.location.search);
  const channel = params.get('channel') || 'chemvision';
  let compactMode = params.get('compact') === '1';
  let readOnlyMode = params.get('readOnly') === '1';
  const state = {
    smiles: '',
    atoms: [],
    selectedId: null,
    molecule: null,
    atomIndexById: new Map(),
    moleculeJson: null,
    history: [],
    future: [],
  };

  const atomList = document.getElementById('atom-list');
  const smilesText = document.getElementById('smiles-text');
  const structureCanvas = document.getElementById('smiles-canvas');
  const engineLabel = document.getElementById('engine-label');
  const hint = document.getElementById('hint');
  let svgDrawer = null;
  let _drawerSize = { w: 0, h: 0 };
  let _drawRequestId = 0;

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
      if (atomList) {
        atomList.style.display = 'none';
      }
      if (hint) {
        hint.style.display = 'none';
      }
    }
  }

  function setNonInteractive(disabled) {
    // Disable pointer events on the entire iframe container
    // so Flutter widgets above can receive taps/clicks
    const value = disabled ? 'none' : '';
    const container = document.getElementById('container');
    if (container) {
      container.style.pointerEvents = value;
    }
    const view = document.getElementById('structure-view');
    if (view) {
      view.style.pointerEvents = value;
    }
    if (structureCanvas) {
      structureCanvas.style.pointerEvents = value;
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

  function snapshotMolecule(molecule) {
    if (!molecule) {
      return null;
    }
    try {
      if (molecule.toMolfile) {
        return { type: 'molfile', data: molecule.toMolfile() };
      }
      if (molecule.toSmiles) {
        return { type: 'smiles', data: molecule.toSmiles() };
      }
    } catch (error) {
      return null;
    }
    return null;
  }

  function restoreMolecule(snapshot) {
    if (!snapshot || !isOclReady()) {
      return null;
    }
    try {
      if (snapshot.type === 'molfile' && window.OCL.Molecule.fromMolfile) {
        return window.OCL.Molecule.fromMolfile(snapshot.data);
      }
      if (snapshot.type === 'smiles') {
        return window.OCL.Molecule.fromSmiles(snapshot.data);
      }
    } catch (error) {
      return null;
    }
    return null;
  }

  function pushHistory() {
    if (!state.molecule) {
      return;
    }
    const snap = snapshotMolecule(state.molecule);
    if (!snap) {
      return;
    }
    state.history.push(snap);
    if (state.history.length > 50) {
      state.history.shift();
    }
    state.future = [];
  }

  function restoreCurrentMolecule(source) {
    if (!state.molecule) {
      return;
    }
    state.atoms = atomsFromMolecule(state.molecule);
    state.selectedId = null;
    renderAtoms();
    updateSmilesFromMolecule(source);
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
    const requestId = ++_drawRequestId;
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
        if (requestId !== _drawRequestId) {
          return;
        }
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
        if (requestId !== _drawRequestId) {
          return;
        }
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
      svg.style.pointerEvents = 'none';
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
      svg.style.pointerEvents = 'none';
      svg.style.transformOrigin = 'top left';
      svg.style.transform = `translate(${translateX}px, ${translateY}px) scale(${scale})`;
    }
  }

  function updateSelection() {
    if (!atomList) {
      return;
    }
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

  function renderAtoms() {
    if (!atomList) {
      return;
    }
    clearChildren(atomList);
    state.atoms.forEach((atom) => {
      const span = document.createElement('span');
      span.className = 'atom';
      span.textContent = atom.element;
      span.setAttribute('data-atom-id', atom.id);

      span.addEventListener('click', () => selectAtom(atom));

      atomList.appendChild(span);
    });
    updateSelection();
  }

  function renderSmiles(smiles) {
    state.smiles = smiles || '';
    const molecule = moleculeFromSmiles(state.smiles);
    state.history = [];
    state.future = [];
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
    pushHistory();
    const atomicNo = getAtomicNoFromLabel(element);
    state.molecule.setAtomicNo(index, atomicNo);
    restoreCurrentMolecule('edit');
  }

  function reportEditorError(message, action) {
    postToHost('onEditorActionError', {
      action,
      message,
    });
  }

  function deleteAtom(atomId) {
    if (!state.molecule || !state.molecule.deleteAtom) {
      reportEditorError('当前结构暂不支持删除原子', 'deleteAtom');
      return;
    }
    const index = state.atomIndexById.get(atomId);
    if (index === undefined) {
      reportEditorError('未找到目标原子', 'deleteAtom');
      return;
    }
    if (state.molecule.getAllAtoms && state.molecule.getAllAtoms() <= 1) {
      reportEditorError('至少需要保留一个原子', 'deleteAtom');
      return;
    }
    try {
      pushHistory();
      state.molecule.deleteAtom(index);
      restoreCurrentMolecule('deleteAtom');
    } catch (error) {
      reportEditorError('删除原子失败', 'deleteAtom');
    }
  }

  function setBondTypeForAtom(atomId, bondType) {
    if (!state.molecule) {
      reportEditorError('当前结构暂不支持修改键型', 'setBondType');
      return;
    }
    const index = state.atomIndexById.get(atomId);
    if (index === undefined) {
      reportEditorError('未找到目标原子', 'setBondType');
      return;
    }
    if (!state.molecule.getConnAtoms || !state.molecule.getConnBond || !state.molecule.setBondType) {
      reportEditorError('当前结构暂不支持修改键型', 'setBondType');
      return;
    }
    const conn = state.molecule.getConnAtoms(index);
    if (!conn) {
      reportEditorError('该原子没有可修改的键', 'setBondType');
      return;
    }
    const bondIndex = state.molecule.getConnBond(index, 0);
    if (bondIndex === undefined || bondIndex < 0) {
      reportEditorError('未找到可修改的键', 'setBondType');
      return;
    }
    const nextType = Number(bondType) || 1;
    try {
      pushHistory();
      state.molecule.setBondType(bondIndex, nextType);
      restoreCurrentMolecule('setBondType');
    } catch (error) {
      reportEditorError('键型修改失败', 'setBondType');
    }
  }

  const groupMap = {
    methyl: { atomicNo: 6, bondType: 1 },
    hydroxyl: { atomicNo: 8, bondType: 1 },
    amino: { atomicNo: 7, bondType: 1 },
    chloro: { atomicNo: 17, bondType: 1 },
  };

  function addGroupToAtom(atomId, groupKey) {
    if (!state.molecule || !state.molecule.addAtom || !state.molecule.addBond) {
      reportEditorError('当前结构暂不支持添加基团', 'addGroup');
      return;
    }
    const group = groupMap[groupKey];
    if (!group) {
      reportEditorError('不支持的基团类型', 'addGroup');
      return;
    }
    const anchorIndex = state.atomIndexById.get(atomId);
    if (anchorIndex === undefined) {
      reportEditorError('未找到目标原子', 'addGroup');
      return;
    }
    try {
      pushHistory();
      let newAtomIndex = state.molecule.addAtom(group.atomicNo);
      if ((newAtomIndex === undefined || newAtomIndex < 0) && state.molecule.addAtom) {
        newAtomIndex = state.molecule.addAtom(6);
      }
      if (newAtomIndex === undefined || newAtomIndex < 0) {
        reportEditorError('添加基团失败', 'addGroup');
        return;
      }
      if (state.molecule.setAtomicNo) {
        state.molecule.setAtomicNo(newAtomIndex, group.atomicNo);
      }
      state.molecule.addBond(anchorIndex, newAtomIndex, group.bondType);
      restoreCurrentMolecule('addGroup');
    } catch (error) {
      reportEditorError('添加基团失败', 'addGroup');
    }
  }

  function undoEdit() {
    if (!state.history.length || !state.molecule) {
      return;
    }
    const current = snapshotMolecule(state.molecule);
    const previous = state.history.pop();
    const restored = restoreMolecule(previous);
    if (!restored) {
      return;
    }
    if (current) {
      state.future.push(current);
      if (state.future.length > 50) {
        state.future.shift();
      }
    }
    state.molecule = restored;
    restoreCurrentMolecule('undo');
  }

  function redoEdit() {
    if (!state.future.length || !state.molecule) {
      return;
    }
    const current = snapshotMolecule(state.molecule);
    const next = state.future.pop();
    const restored = restoreMolecule(next);
    if (!restored) {
      return;
    }
    if (current) {
      state.history.push(current);
      if (state.history.length > 50) {
        state.history.shift();
      }
    }
    state.molecule = restored;
    restoreCurrentMolecule('redo');
  }

  // Pan and zoom support for the structure viewport.
  (function enablePanZoom() {
    const view = document.getElementById('structure-view');
    if (!view) {
      return;
    }
    let scale = 1;
    let tx = 0;
    let ty = 0;
    let isPanning = false;
    let isPinching = false;
    let activePanPointerId = null;
    let panStart = { x: 0, y: 0, tx: 0, ty: 0 };
    const pointers = new Map();
    let pinchStart = null;
    let transformPending = false;
    let interactionActive = false;

    function setInteractionActive(active) {
      if (interactionActive === active) {
        return;
      }
      interactionActive = active;
      postToHost('onViewportInteraction', { active });
    }

    function applyTransform() {
      if (!structureCanvas) return;
      if (transformPending) {
        return;
      }
      transformPending = true;
      requestAnimationFrame(() => {
        transformPending = false;
        if (!structureCanvas) {
          return;
        }
        structureCanvas.style.transform = `translate3d(${tx}px, ${ty}px, 0) scale(${scale})`;
      });
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

    function getFirstTwoPointers() {
      const values = Array.from(pointers.values());
      return values.length >= 2 ? [values[0], values[1]] : null;
    }

    function beginPan(pointerId, point) {
      isPanning = true;
      isPinching = false;
      activePanPointerId = pointerId;
      panStart = { x: point.x, y: point.y, tx, ty };
      view.classList.add('panning');
      setInteractionActive(true);
    }

    function beginPinch() {
      const pair = getFirstTwoPointers();
      if (!pair) {
        return;
      }
      const [p1, p2] = pair;
      const dx = p2.x - p1.x;
      const dy = p2.y - p1.y;
      const distance = Math.hypot(dx, dy);
      if (!distance) {
        return;
      }
      const midX = (p1.x + p2.x) / 2;
      const midY = (p1.y + p2.y) / 2;
      pinchStart = {
        distance,
        scale,
        contentX: (midX - tx) / scale,
        contentY: (midY - ty) / scale,
      };
      isPinching = true;
      isPanning = false;
      activePanPointerId = null;
      view.classList.remove('panning');
      setInteractionActive(true);
    }

    view.addEventListener('pointerdown', (e) => {
      if (e.pointerType === 'touch') {
        return;
      }
      e.preventDefault();
      // ignore when clicking atoms (they have .atom class)
      const target = e.target;
      if (target && target.classList && target.classList.contains('atom')) {
        return;
      }
      pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
      view.setPointerCapture(e.pointerId);
      if (pointers.size === 1) {
        beginPan(e.pointerId, { x: e.clientX, y: e.clientY });
      } else if (pointers.size === 2) {
        beginPinch();
      }
    });

    view.addEventListener('pointermove', (e) => {
      if (e.pointerType === 'touch') {
        return;
      }
      if (isPanning || isPinching) {
        e.preventDefault();
      }
      if (pointers.has(e.pointerId)) {
        pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
      }

      if (isPinching && pinchStart) {
        const pair = getFirstTwoPointers();
        if (!pair) {
          return;
        }
        const [p1, p2] = pair;
        const dx = p2.x - p1.x;
        const dy = p2.y - p1.y;
        const distance = Math.hypot(dx, dy);
        if (!distance) {
          return;
        }
        const midX = (p1.x + p2.x) / 2;
        const midY = (p1.y + p2.y) / 2;
        const newScale = Math.min(4, Math.max(0.3, pinchStart.scale * (distance / pinchStart.distance)));
        tx = midX - pinchStart.contentX * newScale;
        ty = midY - pinchStart.contentY * newScale;
        scale = newScale;
        applyTransform();
        return;
      }

      if (!isPanning || activePanPointerId !== e.pointerId) {
        return;
      }
      const dx = e.clientX - panStart.x;
      const dy = e.clientY - panStart.y;
      tx = panStart.tx + dx;
      ty = panStart.ty + dy;
      applyTransform();
    });

    function endPan(e) {
      if (e.pointerType === 'touch') {
        return;
      }
      e.preventDefault();
      pointers.delete(e.pointerId);
      try { view.releasePointerCapture(e.pointerId); } catch (_) {}
      if (isPinching && pointers.size >= 2) {
        beginPinch();
        return;
      }
      if (pointers.size === 1) {
        const [remainingId, point] = Array.from(pointers.entries())[0];
        beginPan(remainingId, point);
        return;
      }
      isPanning = false;
      isPinching = false;
      activePanPointerId = null;
      pinchStart = null;
      view.classList.remove('panning');
      setInteractionActive(false);
    }

    view.addEventListener('pointerup', endPan);
    view.addEventListener('pointercancel', endPan);

    function syncTouches(touches) {
      pointers.clear();
      for (let i = 0; i < touches.length; i++) {
        const t = touches[i];
        pointers.set(`t${t.identifier}`, { x: t.clientX, y: t.clientY });
      }
    }

    view.addEventListener('touchstart', (e) => {
      e.preventDefault();
      syncTouches(e.touches);
      if (pointers.size === 1) {
        const point = Array.from(pointers.values())[0];
        beginPan('touch', point);
      } else if (pointers.size >= 2) {
        beginPinch();
      }
    }, { passive: false });

    view.addEventListener('touchmove', (e) => {
      e.preventDefault();
      syncTouches(e.touches);
      if (isPinching && pinchStart) {
        const pair = getFirstTwoPointers();
        if (!pair) return;
        const [p1, p2] = pair;
        const distance = Math.hypot(p2.x - p1.x, p2.y - p1.y);
        if (!distance) return;
        const midX = (p1.x + p2.x) / 2;
        const midY = (p1.y + p2.y) / 2;
        const newScale = Math.min(4, Math.max(0.3, pinchStart.scale * (distance / pinchStart.distance)));
        tx = midX - pinchStart.contentX * newScale;
        ty = midY - pinchStart.contentY * newScale;
        scale = newScale;
        applyTransform();
        return;
      }
      if (isPanning && pointers.size === 1) {
        const point = Array.from(pointers.values())[0];
        tx = panStart.tx + (point.x - panStart.x);
        ty = panStart.ty + (point.y - panStart.y);
        applyTransform();
      }
    }, { passive: false });

    function endTouch(e) {
      e.preventDefault();
      syncTouches(e.touches);
      if (isPinching && pointers.size >= 2) {
        beginPinch();
        return;
      }
      if (pointers.size === 1) {
        const point = Array.from(pointers.values())[0];
        beginPan('touch', point);
        return;
      }
      isPanning = false;
      isPinching = false;
      activePanPointerId = null;
      pinchStart = null;
      view.classList.remove('panning');
      setInteractionActive(false);
    }

    view.addEventListener('touchend', endTouch, { passive: false });
    view.addEventListener('touchcancel', endTouch, { passive: false });
  })();

  window.renderSmiles = renderSmiles;
  window.setCompactMode = setCompactMode;
  window.setReadOnly = setReadOnly;
  window.setNonInteractive = setNonInteractive;
  window.deleteAtom = deleteAtom;
  window.setBondTypeForAtom = setBondTypeForAtom;
  window.addGroupToAtom = addGroupToAtom;
  window.undoEdit = undoEdit;
  window.redoEdit = redoEdit;
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
      case 'deleteAtom':
        deleteAtom(payload.atomId);
        break;
      case 'setBondTypeForAtom':
        setBondTypeForAtom(payload.atomId, payload.bondType);
        break;
      case 'addGroupToAtom':
        addGroupToAtom(payload.atomId, payload.groupKey);
        break;
      case 'undoEdit':
        undoEdit();
        break;
      case 'redoEdit':
        redoEdit();
        break;
      case 'setMoleculeJson':
        window.setMoleculeJson(payload);
        break;
      case 'setReadOnly':
        setReadOnly(payload.readOnly);
        break;
      case 'setNonInteractive':
        setNonInteractive(payload.disabled);
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
    // setNonInteractive is controlled via postMessage from Flutter
    postToHost('onBridgeReady', {});
  });
})();
