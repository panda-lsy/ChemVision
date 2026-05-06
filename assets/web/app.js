(function () {
  const params = new URLSearchParams(window.location.search);
  const channel = params.get('channel') || 'chemvision';
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
  let svgDrawer = null;

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
    smilesText.textContent = `SMILES: ${state.smiles || '-'}`;
  }

  function getSvgDrawer() {
    if (!structureCanvas || !window.SmilesDrawer || !window.SmilesDrawer.SvgDrawer) {
      return null;
    }
    if (!svgDrawer) {
      svgDrawer = new window.SmilesDrawer.SvgDrawer({
        width: 320,
        height: 180,
        padding: 12,
        bondThickness: 2,
        bondLength: 18,
        atomVisualization: 'default',
        themes: {
          custom: drawerTheme,
        },
      });
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
    if (!drawer || !smiles) {
      clearSvg();
      return;
    }
    window.SmilesDrawer.parse(
      smiles,
      (tree) => {
        clearSvg();
        drawer.draw(tree, structureCanvas, 'custom', false);
      },
      () => {
        clearSvg();
      }
    );
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

  window.renderSmiles = renderSmiles;
  window.getSmiles = function () {
    if (!state.molecule) {
      return state.smiles;
    }
    return state.molecule.toSmiles();
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
      default:
        break;
    }
  });

  document.addEventListener('DOMContentLoaded', function () {
    postToHost('onBridgeReady', {});
  });
})();
