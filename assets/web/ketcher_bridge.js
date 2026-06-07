/**
 * Ketcher Bridge v5
 * - SMILES: 等待 Redux store 就绪后安全传入
 * - 暗色主题: 全覆盖 CSS
 * - 中文翻译
 */
(function () {
  'use strict';

  var ch = null, lastSmiles = '', poll = null, editorReady = false;

  function post(type, data) {
    if (!ch) return;
    window.parent.postMessage({ channel: ch, type: type, payload: data || {} }, '*');
  }

  // ── 检测编辑器是否真正就绪（Redux store + 渲染） ──
  function checkEditorReady() {
    try {
      var k = window.ketcher;
      if (!k) return false;
      // 检查 editor 对象存在且有 render 方法
      if (k.editor && k.editor.render) return true;
      // 回退：尝试 getSmiles 看是否报错
      if (typeof k.getSmiles === 'function') return true;
    } catch (e) {}
    return false;
  }

  function waitForEditor() {
    return new Promise(function (res) {
      if (editorReady) { res(window.ketcher); return; }
      var t = setInterval(function () {
        if (checkEditorReady()) {
          editorReady = true;
          clearInterval(t);
          res(window.ketcher);
        }
      }, 500);
      setTimeout(function () { clearInterval(t); res(null); }, 30000);
    });
  }

  function pollSmiles() {
    if (poll) return;
    poll = setInterval(async function () {
      try {
        var k = window.ketcher;
        if (!k || !editorReady) return;
        var s = await k.getSmiles();
        if (s != null && s !== lastSmiles) { lastSmiles = s; post('onSmilesUpdated', { smiles: s }); }
      } catch (e) {}
    }, 800);
  }

  // ── 安全设置分子（等待渲染就绪） ──
  async function safeSetMolecule(smiles) {
    var k = await waitForEditor();
    if (!k) { post('onError', { message: '编辑器未就绪' }); return; }

    // 方法1: 使用 editor.clear() + editor.setMolecule 确保干净状态
    try {
      if (k.editor && typeof k.editor.clear === 'function') {
        k.editor.clear();
      }
    } catch (e) {}

    // 等待清空完成
    await new Promise(function (r) { setTimeout(r, 300); });

    // 方法2: 通过 Ketcher API 设置分子
    for (var i = 0; i < 3; i++) {
      try {
        await k.setMolecule(smiles);
        // 等待渲染
        await new Promise(function (r) { setTimeout(r, 500); });
        // 验证
        var check = await k.getSmiles();
        if (check && check.length > 0) {
          lastSmiles = '';
          pollSmiles();
          post('onSetMoleculeSuccess', { smiles: check });
          return;
        }
      } catch (e) {
        post('onError', { message: 'setMolecule 尝试 ' + (i + 1) + ': ' + e.message });
      }
      await new Promise(function (r) { setTimeout(r, 800); });
    }

    // 方法3: 如果 API 失败，尝试通过 Open 对话框粘贴 SMILES
    try {
      if (k.editor && k.editor.setMoleculeFromPaste) {
        await k.editor.setMoleculeFromPaste(smiles);
        await new Promise(function (r) { setTimeout(r, 500); });
        var s = await k.getSmiles();
        if (s && s.length > 0) {
          lastSmiles = '';
          pollSmiles();
          post('onSetMoleculeSuccess', { smiles: s });
          return;
        }
      }
    } catch (e) {}

    post('onError', { message: 'SMILES 传入失败（已重试 3 次）' });
  }

  // ── 暗色主题 ──
  function applyDark() {
    var old = document.getElementById('cv-theme');
    if (old) old.remove();
    document.documentElement.setAttribute('data-theme', 'dark');
    var s = document.createElement('style');
    s.id = 'cv-theme';
    s.textContent = [
      // 全局背景
      'html,body,#root,.App{background:#0d1627!important}',
      'html{color-scheme:dark}',

      // ── 所有容器 ──
      '[class*="module"]{background:#0d1627!important}',
      '[class*="Module"]{background:#0d1627!important}',

      // ── 工具栏容器 ──
      '[class*="toolbar"],[class*="Toolbar"]{',
      '  background:#0f172a!important;color:#e9eef5!important;',
      '  border-color:rgba(255,255,255,.06)!important}',

      // ── 工具栏按钮 ──
      '[class*="toolbar"] button,[class*="Toolbar"] button{',
      '  background:transparent!important;color:#b9c7de!important;',
      '  border-color:transparent!important}',
      '[class*="toolbar"] button:hover,[class*="Toolbar"] button:hover{',
      '  background:rgba(255,255,255,.08)!important;color:#e9eef5!important}',
      'button[aria-pressed="true"],button.active{',
      '  background:rgba(56,213,193,.2)!important;color:#38d5c1!important}',

      // ── 翻页箭头 ──
      '[class*="ArrowScroll"]{background:#0f172a!important;color:#b9c7de!important}',
      '[class*="ArrowScroll"]:hover{background:rgba(56,213,193,.12)!important}',

      // ── 画布区域 ──
      '[class*="StructEditor"],.cliparea,[class*="canvas"]{',
      '  background:#0f172a!important}',

      // ── 菜单/弹窗/对话框 ──
      '[class*="Menu"],[class*="menu"],[class*="Dropdown"],',
      '[class*="Modal"],[class*="modal"],[class*="Dialog"],',
      '[class*="Popup"],[class*="Popover"],[class*="Overlay"]{',
      '  background:#0f172a!important;color:#e9eef5!important;',
      '  border:1px solid rgba(255,255,255,.1)!important}',
      '[class*="MenuItem"],[class*="menu"] li{color:#b9c7de!important}',
      '[class*="MenuItem"]:hover,[class*="menu"] li:hover{',
      '  background:rgba(56,213,193,.12)!important;color:#e9eef5!important}',

      // ── 输入框 ──
      'input,select,textarea{',
      '  background:rgba(255,255,255,.05)!important;color:#e9eef5!important;',
      '  border-color:rgba(255,255,255,.12)!important}',
      'input:focus,select:focus,textarea:focus{border-color:#38d5c1!important}',

      // ── 普通按钮 ──
      'button:not([aria-pressed="true"]):not(.active){',
      '  background:rgba(255,255,255,.06)!important;color:#e9eef5!important;',
      '  border-color:rgba(255,255,255,.1)!important}',
      'button:hover:not([aria-pressed="true"]):not(.active){',
      '  background:rgba(255,255,255,.1)!important}',

      // ── 文本 ──
      'label,span,p,h1,h2,h3,h4,h5,h6,a,',
      '[class*="label"],[class*="Label"],[class*="text"],[class*="Text"],',
      '[class*="title"],[class*="Title"]{color:#e9eef5!important}',
      'a:hover{color:#38d5c1!important}',

      // ── Tab ──
      '[class*="tab"],[role="tab"]{color:#a9b6cb!important}',
      '[class*="tab"][aria-selected="true"],[role="tab"][aria-selected="true"]{',
      '  color:#38d5c1!important;border-bottom-color:#38d5c1!important}',

      // ── 面板/卡片 ──
      '[class*="Panel"],[class*="Card"],[class*="Paper"]{',
      '  background:#0f172a!important;border-color:rgba(255,255,255,.08)!important}',

      // ── 分隔线 ──
      'hr,[class*="divider"],[class*="Divider"]{',
      '  border-color:rgba(255,255,255,.06)!important}',

      // ── 滚动条 ──
      '::-webkit-scrollbar{width:8px;height:8px}',
      '::-webkit-scrollbar-track{background:#0d1627}',
      '::-webkit-scrollbar-thumb{background:rgba(255,255,255,.15);border-radius:4px}',

      // ── 选择高亮 ──
      '::selection{background:rgba(56,213,193,.3)!important}',
    ].join('\n');
    document.head.appendChild(s);
  }

  function applyLight() {
    var old = document.getElementById('cv-theme');
    if (old) old.remove();
    document.documentElement.removeAttribute('data-theme');
  }

  // ── 中文翻译 ──
  var zh = {
    'Save':'保存','Open':'打开','Close':'关闭','Undo':'撤销','Redo':'重做',
    'Clear Canvas':'清空画布','Copy':'复制','Paste':'粘贴','Cut':'剪切',
    'Erase':'擦除','Select All':'全选','Deselect All':'取消全选',
    'Settings':'设置','About':'关于','Help':'帮助',
    'Hand tool':'手形工具','Rectangle Selection':'矩形选择',
    'Lasso Selection':'套索选择','Fragment Selection':'片段选择',
    'Structure Selection':'结构选择',
    'Chain':'链','Bond Properties':'键属性','Atom Properties':'原子属性',
    'Charge Plus':'正电荷','Charge Minus':'负电荷',
    'S-Group':'S-组','R-Group Label Tool':'R-基团标签',
    'R-Group Fragment Tool':'R-基团片段',
    'Rotate Tool':'旋转','Horizontal Flip':'水平翻转','Vertical Flip':'垂直翻转',
    'Attachment Point Tool':'连接点',
    'Reaction Mapping Tool':'反应映射','Reaction Auto-Mapping Tool':'自动映射',
    'Reaction Plus Tool':'反应加号','Reaction Unmapping Tool':'取消映射',
    'Single Bond':'单键','Double Bond':'双键','Triple Bond':'三键',
    'Chain tool':'链工具','Bond tool':'键工具','Selection tool':'选择工具',
    'Open…':'打开...','Save As…':'另存为...',
    'Aromatize':'芳香化','Dearomatize':'去芳香化',
    'Layout':'自动布局','Clean Up':'整理结构',
    'Calculate CIP':'计算CIP','Calculated Values':'计算数值',
    'Check Structure':'检查结构','Add text':'添加文本',
    'Add Image':'添加图片','Extended Table':'扩展元素表',
    'Periodic Table':'元素周期表','Functional Groups':'官能团',
    'Stereochemistry':'立体化学','Fullscreen mode':'全屏',
    'Recognize Molecule':'识别分子','Create a monomer':'创建单体',
    'Add/Remove explicit hydrogens':'添加/移除显式氢',
    'Any atom':'任意原子','Select descriptors':'选择描述符',
    '3D Viewer':'3D查看器','Copy as KET':'复制为KET','Copy as MOL':'复制为MOL',
    'Copy Image':'复制图片',
    'Arrow Open Angle Tool':'开放箭头','Arrow Filled Triangle Tool':'实心三角箭头',
    'Arrow Filled Bow Tool':'实心弓形箭头','Arrow Dashed Open Angle Tool':'虚线箭头',
    'Arrow Equilibrium Open Angle Tool':'平衡箭头',
    'Retrosynthetic Arrow Tool':'逆合成箭头','Failed Arrow Tool':'失败箭头',
    'Multi-Tailed Arrow Tool':'多尾箭头',
    'Shape Rectangle':'矩形','Shape Ellipse':'椭圆','Shape Line':'直线',
    'Save Structure':'保存结构','Save to File':'保存到文件',
    'Open structure':'打开结构','Open from File':'从文件打开',
    'Add to Canvas':'添加到画布','Copy to clipboard':'复制到剪贴板',
    'Text Editor':'文本编辑器','Structure Check':'结构检查',
    'Apply':'应用','Cancel':'取消','OK':'确定','Reset':'重置',
    'General':'通用','Server':'服务器','Mode':'模式',
    'Atoms':'原子','Bonds':'键','Attachment Points':'连接点',
    'Single':'单个','List':'列表','Not List':'非列表',
    'Warning':'警告','Error':'错误','Information':'信息',
    'Error message':'错误信息',
    'Import Structure from Image':'从图片导入结构',
    'Open as New Project':'作为新项目打开',
  };

  function translate() {
    var w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
    while (w.nextNode()) {
      var n = w.currentNode, t = n.textContent.trim();
      if (zh[t]) n.textContent = n.textContent.replace(t, zh[t]);
    }
    document.querySelectorAll('[title]').forEach(function (e) { var v = e.getAttribute('title'); if (zh[v]) e.setAttribute('title', zh[v]); });
    document.querySelectorAll('[placeholder]').forEach(function (e) { var v = e.getAttribute('placeholder'); if (zh[v]) e.setAttribute('placeholder', zh[v]); });
    document.querySelectorAll('[aria-label]').forEach(function (e) { var v = e.getAttribute('aria-label'); if (zh[v]) e.setAttribute('aria-label', zh[v]); });
  }

  function watchTranslate() {
    translate();
    new MutationObserver(function (m) {
      for (var i = 0; i < m.length; i++) { if (m[i].addedNodes.length) { translate(); return; } }
    }).observe(document.body, { childList: true, subtree: true });
  }

  // ── 消息监听 ──
  window.addEventListener('message', async function (e) {
    var d = e.data;
    if (!d) return;

    // Ketcher init 事件
    if (d.eventType === 'init') {
      // 不立即标记就绪，等待 Redux store 完全初始化
      var sp = new URLSearchParams(window.location.search);
      if (sp.get('theme') === 'dark') applyDark(); else applyLight();
      watchTranslate();
      // 等待编辑器真正就绪后再通知 Flutter
      waitForEditor().then(function (k) {
        if (k) {
          editorReady = true;
          post('onBridgeReady', {});
          pollSmiles();
        }
      });
      return;
    }

    // Flutter 指令
    if (!d.type || !d.channel) return;
    ch = d.channel;
    var type = d.type, p = d.payload || {};

    try {
      switch (type) {
        case 'setMolecule':
          await safeSetMolecule(p.data || '');
          break;
        case 'getSmiles':
          try { var k = await waitForEditor(); post('getSmilesResult', { requestId: p.requestId, smiles: k ? await k.getSmiles() || '' : '' }); }
          catch (e) { post('getSmilesResult', { requestId: p.requestId, smiles: '' }); }
          break;
        case 'getRxn':
          try { var k2 = await waitForEditor(); post('getRxnResult', { requestId: p.requestId, rxn: k2 ? await k2.getRxn() || '' : '' }); }
          catch (e) { post('getRxnResult', { requestId: p.requestId, rxn: '' }); }
          break;
        case 'exportSvg':
          try {
            var k3 = await waitForEditor();
            if (k3 && k3.generateImage) {
              post('exportSvgResult', { svgString: await k3.generateImage(p.data || await k3.getSmiles() || '', { outputFormat: 'svg' }) });
            } else {
              var el = document.querySelector('#root svg');
              post('exportSvgResult', { svgString: el ? new XMLSerializer().serializeToString(el) : '' });
            }
          } catch (e) { post('onError', { message: 'SVG: ' + e }); }
          break;
        case 'exportPng':
          try {
            var k4 = await waitForEditor();
            if (k4 && k4.generateImage) {
              post('exportPngResult', { dataUrl: await k4.generateImage(p.data || await k4.getSmiles() || '', { outputFormat: 'png' }) });
            } else { post('onError', { message: 'PNG 不可用' }); }
          } catch (e) { post('onError', { message: 'PNG: ' + e }); }
          break;
        case 'setTheme':
          if ((p.mode || 'dark') === 'dark') applyDark(); else applyLight();
          break;
        case 'setReadOnly':
          var r = document.querySelector('#root');
          if (r) r.style.pointerEvents = p.readOnly ? 'none' : '';
          break;
      }
    } catch (e) { post('onError', { message: String(e) }); }
  });

  // ── 超时保底：如果 init 事件未触发，3s 后主动检查 ──
  setTimeout(function () {
    if (!editorReady && checkEditorReady()) {
      editorReady = true;
      var sp = new URLSearchParams(window.location.search);
      if (sp.get('theme') === 'dark') applyDark(); else applyLight();
      watchTranslate();
      post('onBridgeReady', {});
      pollSmiles();
    }
  }, 3000);
})();
