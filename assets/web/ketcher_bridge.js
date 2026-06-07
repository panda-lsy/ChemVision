/**
 * Ketcher Bridge v4
 * SMILES 通信 + 暗色主题 + 中文翻译
 */
(function () {
  'use strict';

  var ch = null, lastSmiles = '', poll = null, ready = false;

  function post(type, data) {
    if (!ch) return;
    window.parent.postMessage({ channel: ch, type: type, payload: data || {} }, '*');
  }

  function getKetcher() {
    return new Promise(function (res) {
      if (ready && window.ketcher) { res(window.ketcher); return; }
      var t = setInterval(function () {
        if (window.ketcher) { ready = true; clearInterval(t); res(window.ketcher); }
      }, 300);
      setTimeout(function () { clearInterval(t); res(null); }, 25000);
    });
  }

  function pollSmiles() {
    if (poll) return;
    poll = setInterval(async function () {
      try {
        var k = window.ketcher;
        if (!k || typeof k.getSmiles !== 'function') return;
        var s = await k.getSmiles();
        if (s != null && s !== lastSmiles) { lastSmiles = s; post('onSmilesUpdated', { smiles: s }); }
      } catch (e) {}
    }, 600);
  }

  // ── 暗色主题 ──
  function dark(on) {
    var old = document.getElementById('cv-dark');
    if (old) old.remove();
    if (!on) {
      document.documentElement.removeAttribute('data-theme');
      document.body.style.background = '';
      return;
    }
    document.documentElement.setAttribute('data-theme', 'dark');
    document.body.style.background = '#0d1627';
    var s = document.createElement('style');
    s.id = 'cv-dark';
    s.textContent = [
      // 全局
      '*,*::before,*::after{box-sizing:border-box}',
      'html,body,#root{background:#0d1627!important;margin:0}',

      // ── 顶部工具栏 ──
      '[class*="TopToolbar"],[class*="top-toolbar"],',
      '[class*="topToolbar"],header[class*="module"],',
      '[class*="Header"],[class*="header-bar"]{',
      '  background:#0f172a!important;border-bottom:1px solid rgba(255,255,255,.08)!important;color:#e9eef5!important}',

      // ── 左侧工具栏 ──
      '[class*="LeftToolbar"],[class*="left-toolbar"],',
      '[class*="leftToolbar"],[class*="SideToolbar"],',
      'nav[class*="module"],aside[class*="module"]{',
      '  background:#0f172a!important;border-right:1px solid rgba(255,255,255,.08)!important}',

      // ── 底部工具栏 ──
      '[class*="BottomToolbar"],[class*="bottom-toolbar"],',
      '[class*="bottomToolbar"],[class*="StatusBar"],',
      'footer[class*="module"]{',
      '  background:#0f172a!important;border-top:1px solid rgba(255,255,255,.08)!important}',

      // ── 工具翻页箭头 ──
      '[class*="ArrowScroll"],[class*="arrow-scroll"],',
      '[class*="scroll-arrow"],[class*="ScrollArrow"],',
      '[class*="ScrollButton"],[class*="scroll-button"]{',
      '  background:#0f172a!important;color:#b9c7de!important}',
      '[class*="ArrowScroll"]:hover,[class*="scroll-arrow"]:hover{',
      '  background:rgba(56,213,193,.15)!important;color:#38d5c1!important}',

      // ── 工具栏按钮 ──
      '[class*="toolbar"] button,[class*="Toolbar"] button,',
      '[class*="module"] button[class*="tool"],',
      'button[class*="ToolButton"],button[class*="tool-button"]{',
      '  background:transparent!important;color:#b9c7de!important;border:1px solid transparent!important;',
      '  border-radius:4px!important}',
      '[class*="toolbar"] button:hover,[class*="Toolbar"] button:hover{',
      '  background:rgba(255,255,255,.08)!important;color:#e9eef5!important}',
      'button[aria-pressed="true"],button.active,',
      '[class*="toolbar"] button[class*="selected"],',
      '[class*="Toolbar"] button[class*="selected"]{',
      '  background:rgba(56,213,193,.25)!important;color:#38d5c1!important;',
      '  border-color:rgba(56,213,193,.3)!important}',

      // ── 工具栏分隔符 ──
      '[class*="divider"],[class*="Divider"],hr,',
      '[class*="separator"],[class*="Separator"]{',
      '  border-color:rgba(255,255,255,.06)!important;background:rgba(255,255,255,.06)!important}',

      // ── 编辑器画布 ──
      '[class*="StructEditor"],[class*="struct-editor"],',
      '[class*="editor-container"],.cliparea,',
      '[class*="canvas-container"],[class*="Canvas"]{',
      '  background:#0f172a!important}',

      // ── 菜单/下拉/弹窗 ──
      '[class*="Menu"],[class*="menu"],',
      '[class*="Dropdown"],[class*="dropdown"],',
      '[class*="Popover"],[class*="popover"],',
      '[class*="Popup"],[class*="popup"],',
      '[class*="Modal"],[class*="modal"],',
      '[class*="Dialog"],[class*="dialog"],',
      '[class*="Overlay"],[class*="overlay"]{',
      '  background:#0f172a!important;color:#e9eef5!important;',
      '  border:1px solid rgba(255,255,255,.1)!important;',
      '  box-shadow:0 4px 24px rgba(0,0,0,.5)!important}',

      // ── 菜单项 ──
      '[class*="MenuItem"],[class*="menu-item"],',
      '[class*="menu"] li,[class*="Menu"] li,',
      '[class*="Option"],[class*="option"]{',
      '  color:#b9c7de!important}',
      '[class*="MenuItem"]:hover,[class*="menu-item"]:hover,',
      '[class*="menu"] li:hover,[class*="Menu"] li:hover{',
      '  background:rgba(56,213,193,.15)!important;color:#e9eef5!important}',

      // ── 输入框 ──
      'input,select,textarea{',
      '  background:rgba(255,255,255,.05)!important;color:#e9eef5!important;',
      '  border:1px solid rgba(255,255,255,.12)!important}',
      'input:focus,select:focus,textarea:focus{',
      '  border-color:#38d5c1!important;box-shadow:0 0 0 1px rgba(56,213,193,.3)!important}',

      // ── 按钮 ──
      'button:not([aria-pressed="true"]):not(.active){',
      '  background:rgba(255,255,255,.06)!important;color:#e9eef5!important;',
      '  border:1px solid rgba(255,255,255,.1)!important}',
      'button:hover:not([aria-pressed="true"]):not(.active){',
      '  background:rgba(255,255,255,.1)!important;border-color:rgba(255,255,255,.2)!important}',

      // ── 标签/文本 ──
      'label,[class*="label"],[class*="Label"],',
      '[class*="text"],[class*="Text"],',
      '[class*="title"],[class*="Title"],',
      'span,p,h1,h2,h3,h4,h5,h6{color:#e9eef5!important}',
      'a{color:#5ce0d0!important}a:hover{color:#38d5c1!important}',

      // ── Tab 页 ──
      '[class*="tab"],[role="tab"]{color:#a9b6cb!important;border-bottom-color:transparent!important}',
      '[class*="tab"]:hover,[role="tab"]:hover{color:#e9eef5!important;background:rgba(255,255,255,.04)!important}',
      '[class*="tab"][aria-selected="true"],[role="tab"][aria-selected="true"]{color:#38d5c1!important;border-bottom-color:#38d5c1!important}',

      // ── 选项卡/面板容器 ──
      '[class*="Panel"],[class*="panel"],',
      '[class*="Card"],[class*="card"],',
      '[class*="Paper"],[class*="paper"],',
      '[class*="Container"]{',
      '  background:#0f172a!important;border-color:rgba(255,255,255,.08)!important}',

      // ── 工具提示 ──
      '[class*="Tooltip"],[class*="tooltip"]{',
      '  background:#1a2540!important;color:#e9eef5!important;border:1px solid rgba(255,255,255,.12)!important}',

      // ── 滚动条 ──
      '::-webkit-scrollbar{width:8px;height:8px}',
      '::-webkit-scrollbar-track{background:#0d1627}',
      '::-webkit-scrollbar-thumb{background:rgba(255,255,255,.15);border-radius:4px}',
      '::-webkit-scrollbar-thumb:hover{background:rgba(255,255,255,.25)}',

      // ── 选择高亮 ──
      '::selection{background:rgba(56,213,193,.3)!important;color:#e9eef5!important}',

      // ── SVG 结构渲染区域（保持透明） ──
      '[class*="struct"] svg,[class*="Struct"] svg,.struct-svg{background:transparent!important}',

      // ── 警告/信息 ──
      '[class*="Alert"],[class*="alert"],[class*="Warning"],[class*="Info"]{',
      '  background:rgba(255,255,255,.05)!important;border-color:rgba(255,255,255,.1)!important;color:#e9eef5!important}',
    ].join('\n');
    document.head.appendChild(s);
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
    'Attachment Point Tool':'连接点工具',
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
    'Save':'保存','Save Structure':'保存结构','Save to File':'保存到文件',
    'Open structure':'打开结构','Open from File':'从文件打开',
    'Add to Canvas':'添加到画布','Copy to clipboard':'复制到剪贴板',
    'Text Editor':'文本编辑器','Structure Check':'结构检查',
    'Apply':'应用','Cancel':'取消','OK':'确定','Reset':'重置',
    'General':'通用','Server':'服务器','Mode':'模式',
    'Atoms':'原子','Bonds':'键','Attachment Points':'连接点',
    'Single':'单个','List':'列表','Not List':'非列表',
    'Warning':'警告','Error':'错误','Information':'信息',
    'Error message':'错误信息',
  };

  function translate() {
    var w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
    while (w.nextNode()) {
      var n = w.currentNode, t = n.textContent.trim();
      if (zh[t]) n.textContent = n.textContent.replace(t, zh[t]);
    }
    document.querySelectorAll('[title]').forEach(function (e) {
      var v = e.getAttribute('title'); if (zh[v]) e.setAttribute('title', zh[v]);
    });
    document.querySelectorAll('[placeholder]').forEach(function (e) {
      var v = e.getAttribute('placeholder'); if (zh[v]) e.setAttribute('placeholder', zh[v]);
    });
    document.querySelectorAll('[aria-label]').forEach(function (e) {
      var v = e.getAttribute('aria-label'); if (zh[v]) e.setAttribute('aria-label', zh[v]);
    });
  }

  function watchTranslate() {
    translate();
    new MutationObserver(function (m) {
      for (var i = 0; i < m.length; i++) { if (m[i].addedNodes.length) { translate(); return; } }
    }).observe(document.body, { childList: true, subtree: true });
  }

  // ── SMILES 传入（带重试） ──
  async function setMoleculeWithRetry(smiles, retries) {
    var k = await getKetcher();
    if (!k) return;
    for (var i = 0; i < retries; i++) {
      try {
        await k.setMolecule(smiles);
        lastSmiles = '';
        pollSmiles();
        // 等待渲染完成后再检查
        await new Promise(function (r) { setTimeout(r, 300); });
        var check = await k.getSmiles();
        if (check && check.length > 0) {
          post('onSetMoleculeSuccess', { smiles: check });
          return;
        }
      } catch (e) {}
      await new Promise(function (r) { setTimeout(r, 500); });
    }
    post('onError', { message: 'setMolecule 失败（重试 ' + retries + ' 次）' });
  }

  // ── 消息监听 ──
  window.addEventListener('message', async function (e) {
    var d = e.data;
    if (!d) return;

    // Ketcher init 事件
    if (d.eventType === 'init') {
      ready = true;
      pollSmiles();
      watchTranslate();
      // 自动应用暗色主题（如果 URL 参数指定）
      var sp = new URLSearchParams(window.location.search);
      if (sp.get('theme') === 'dark') dark(true);
      return;
    }

    // Flutter 指令
    if (!d.type || !d.channel) return;
    ch = d.channel;
    var type = d.type, p = d.payload || {};

    try {
      var k = await getKetcher();
      if (!k) { post('onError', { message: 'Ketcher 未加载' }); return; }

      switch (type) {
        case 'setMolecule':
          await setMoleculeWithRetry(p.data || '', 3);
          break;
        case 'getSmiles':
          try { post('getSmilesResult', { requestId: p.requestId, smiles: await k.getSmiles() || '' }); }
          catch (e) { post('getSmilesResult', { requestId: p.requestId, smiles: '' }); }
          break;
        case 'getRxn':
          try { post('getRxnResult', { requestId: p.requestId, rxn: await k.getRxn() || '' }); }
          catch (e) { post('getRxnResult', { requestId: p.requestId, rxn: '' }); }
          break;
        case 'exportSvg':
          try {
            if (k.generateImage) {
              post('exportSvgResult', { svgString: await k.generateImage(p.data || await k.getSmiles() || '', { outputFormat: 'svg' }) });
            } else {
              var el = document.querySelector('#root svg');
              post('exportSvgResult', { svgString: el ? new XMLSerializer().serializeToString(el) : '' });
            }
          } catch (e) { post('onError', { message: 'SVG: ' + e }); }
          break;
        case 'exportPng':
          try {
            if (k.generateImage) {
              post('exportPngResult', { dataUrl: await k.generateImage(p.data || await k.getSmiles() || '', { outputFormat: 'png' }) });
            } else { post('onError', { message: 'PNG 不可用' }); }
          } catch (e) { post('onError', { message: 'PNG: ' + e }); }
          break;
        case 'setTheme':
          dark((p.mode || 'dark') === 'dark');
          break;
        case 'setReadOnly':
          var r = document.querySelector('#root');
          if (r) r.style.pointerEvents = p.readOnly ? 'none' : '';
          break;
      }
    } catch (e) { post('onError', { message: String(e) }); }
  });

  // 启动
  getKetcher().then(function (k) {
    if (k) {
      ready = true;
      post('onBridgeReady', {});
      pollSmiles();
      watchTranslate();
      var sp = new URLSearchParams(window.location.search);
      if (sp.get('theme') === 'dark') dark(true);
    }
  });
})();
