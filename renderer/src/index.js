const DEFAULT_OPTIONS = {
  mathMode: 'tex',
  className: 'rte-render-root',
  injectStyles: true,
  autoMathJaxTypeset: true,
};

const STYLE_ID = 'rich-text-editor-renderer-styles';
const MIN_IMAGE_WIDTH = 32;
const MAX_IMAGE_WIDTH = 720;
const MIN_IMAGE_HEIGHT = 28;
const MAX_IMAGE_HEIGHT = 720;
const DEFAULT_IMAGE_WIDTH = 280;

export function renderRichTextDocument({
  element,
  document: inputDocument,
  options = {},
}) {
  if (!element) {
    throw new Error('renderRichTextDocument requires an element');
  }

  const resolvedOptions = { ...DEFAULT_OPTIONS, ...options };
  const documentModel = normalizeDocument(inputDocument);

  if (resolvedOptions.injectStyles) {
    ensureStyles();
  }

  element.innerHTML = '';
  element.classList.add(resolvedOptions.className);

  const flowRoot = document.createElement('div');
  flowRoot.className = 'rte-flow-root';
  const floatingRoot = document.createElement('div');
  floatingRoot.className = 'rte-floating-root';

  element.appendChild(flowRoot);
  element.appendChild(floatingRoot);

  renderStaticNodes(flowRoot, documentModel);
  const performLayout = ({ rerunMath = true } = {}) => {
    rerenderLayout({ host: element, flowRoot, floatingRoot, documentModel });
    if (rerunMath && resolvedOptions.autoMathJaxTypeset) {
      requestMathTypeset(element).then(() => {
        rerenderLayout({ host: element, flowRoot, floatingRoot, documentModel });
        return requestMathTypeset(element);
      });
    }
  };

  performLayout();
  attachDeferredLayoutPasses(element, performLayout);

  return {
    rerender() {
      performLayout();
    },
    destroy() {
      element.innerHTML = '';
      element.classList.remove(resolvedOptions.className);
    },
  };
}

export function autoMountRichTextDocuments({
  selector = '.rte-viewer[data-rich-text-json], rich-text-editor-viewer[data-rich-text-json]',
  options = {},
} = {}) {
  const mounts = [];
  document.querySelectorAll(selector).forEach((element) => {
    if (element.dataset.rteMounted === 'true') {
      return;
    }
    const raw = element.getAttribute('data-rich-text-json');
    if (!raw) {
      return;
    }
    element.dataset.rteMounted = 'true';
    mounts.push(
      renderRichTextDocument({
        element,
        document: JSON.parse(raw),
        options,
      }),
    );
  });
  return mounts;
}

function defineCustomElement() {
  if (typeof window === 'undefined' || !window.customElements) {
    return;
  }
  if (window.customElements.get('rich-text-editor-viewer')) {
    return;
  }

  class RichTextEditorViewerElement extends HTMLElement {
    connectedCallback() {
      if (this.dataset.rteMounted === 'true') {
        return;
      }
      const raw = this.getAttribute('data-rich-text-json');
      if (!raw) {
        return;
      }
      this.dataset.rteMounted = 'true';
      renderRichTextDocument({
        element: this,
        document: JSON.parse(raw),
      });
    }
  }

  window.customElements.define(
    'rich-text-editor-viewer',
    RichTextEditorViewerElement,
  );
}

function normalizeDocument(value) {
  if (typeof value === 'string') {
    return JSON.parse(value);
  }
  return value;
}

function ensureStyles() {
  if (document.getElementById(STYLE_ID)) {
    return;
  }
  const style = document.createElement('style');
  style.id = STYLE_ID;
  style.textContent = `
    .rte-render-root {
      position: relative;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: #1f2937;
      line-height: 1.6;
      word-break: break-word;
    }
    .rte-flow-root {
      position: relative;
      z-index: 1;
    }
    .rte-floating-root {
      position: absolute;
      inset: 0;
      pointer-events: none;
      z-index: 2;
    }
    .rte-node {
      margin-bottom: 12px;
    }
    .rte-paragraph,
    .rte-list-item {
      font-size: 16px;
      line-height: 1.4;
      font-weight: 400;
    }
    .rte-heading1 {
      font-size: 30px;
      line-height: 1.25;
      font-weight: 700;
    }
    .rte-heading2 {
      font-size: 22px;
      line-height: 1.3;
      font-weight: 600;
    }
    .rte-list {
      margin: 0 0 12px 0;
      padding-left: 24px;
    }
    .rte-line {
      display: flex;
      align-items: flex-start;
      min-height: 1em;
    }
    .rte-line-block {
      display: flex;
      align-items: flex-start;
    }
    .rte-token {
      white-space: pre;
    }
    .rte-token.bold {
      font-weight: 700;
    }
    .rte-token.italic {
      font-style: italic;
    }
    .rte-token.underline {
      text-decoration: underline;
    }
    .rte-token.link {
      color: #0a66c2;
      text-decoration: underline;
    }
    .rte-block-image,
    .rte-floating-image {
      overflow: hidden;
      border-radius: 12px;
      background: #e5e7eb;
      box-shadow: 0 8px 24px rgba(15, 23, 42, 0.12);
    }
    .rte-block-image img {
      display: block;
      width: 100%;
      height: 100%;
      object-fit: contain;
    }
    .rte-floating-image img {
      display: block;
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .rte-floating-image {
      position: absolute;
    }
    .rte-wrap-block {
      display: flex;
      gap: 16px;
      align-items: flex-start;
    }
    .rte-wrap-block.right {
      flex-direction: row-reverse;
    }
    .rte-wrap-text {
      flex: 1;
      min-width: 0;
    }
  `;
  document.head.appendChild(style);
}

function renderStaticNodes(flowRoot, documentModel) {
  flowRoot.innerHTML = '';
  for (const node of documentModel.nodes || []) {
    switch (node.type) {
      case 'textBlock':
        renderStaticTextNode(flowRoot, node);
        break;
      case 'list':
        renderStaticListNode(flowRoot, node);
        break;
      case 'math':
        renderStaticMathNode(flowRoot, node);
        break;
      case 'image':
        renderStaticImageNode(flowRoot, node);
        break;
      default:
        break;
    }
  }
}

function renderStaticTextNode(flowRoot, node) {
  const wrapper = document.createElement('div');
  wrapper.className = 'rte-node';
  wrapper.dataset.nodeId = node.id;
  wrapper.dataset.nodeType = node.type;
  flowRoot.appendChild(wrapper);
}

function renderStaticListNode(flowRoot, node) {
  const list = document.createElement(node.style === 'ordered' ? 'ol' : 'ul');
  list.className = 'rte-node rte-list';
  list.dataset.nodeId = node.id;
  list.dataset.nodeType = node.type;
  (node.items || []).forEach((_, index) => {
    const item = document.createElement('li');
    item.className = 'rte-list-item';
    item.dataset.nodeId = `${node.id}::${index}`;
    item.dataset.parentNodeId = node.id;
    item.dataset.nodeType = 'list-item';
    list.appendChild(item);
  });
  flowRoot.appendChild(list);
}

function renderStaticMathNode(flowRoot, node) {
  const wrapper = document.createElement('div');
  wrapper.className = 'rte-node';
  wrapper.dataset.nodeId = node.id;
  wrapper.dataset.nodeType = node.type;
  wrapper.innerHTML = node.displayMode === 'inline'
    ? `<span data-node="math-inline" data-latex="${escapeHtml(node.latex)}">\\(${escapeHtml(node.latex)}\\)</span>`
    : `<div data-node="math-block" data-latex="${escapeHtml(node.latex)}">\\[${escapeHtml(node.latex)}\\]</div>`;
  flowRoot.appendChild(wrapper);
}

function renderStaticImageNode(flowRoot, node) {
  if (node.layoutMode === 'floating') {
    return;
  }

  const wrapper = document.createElement('div');
  wrapper.className = 'rte-node';
  wrapper.dataset.nodeId = node.id;
  wrapper.dataset.nodeType = node.type;

  const dimensions = resolveBlockImageDimensions(node);
  const imageHtml = `<div class="rte-block-image" style="width:${dimensions.width}px;height:${dimensions.height}px"><img src="${escapeHtml(node.url)}" alt="${escapeHtml(node.altText || '')}"></div>`;

  if (node.wrapAlignment && node.wrapAlignment !== 'none' && hasWrapSegments(node.wrapSegments)) {
    wrapper.innerHTML = `<div class="rte-wrap-block ${node.wrapAlignment === 'right' ? 'right' : 'left'}">${imageHtml}<div class="rte-wrap-text rte-paragraph">${segmentsHtml(node.wrapSegments)}</div></div>`;
  } else {
    wrapper.innerHTML = imageHtml;
  }
  flowRoot.appendChild(wrapper);
}

function resolveBlockImageDimensions(node) {
  const width = clamp(node.width || DEFAULT_IMAGE_WIDTH, MIN_IMAGE_WIDTH, MAX_IMAGE_WIDTH);
  const height = clamp(node.height || width * 0.72, MIN_IMAGE_HEIGHT, 320);
  return { width, height };
}

function rerenderLayout({ host, flowRoot, floatingRoot, documentModel }) {
  const nodeRects = readNodeRects(host, flowRoot);
  const floatRects = buildFloatingRects(documentModel, nodeRects);
  renderFloatingImages(host, floatingRoot, floatRects);
  rerenderTextNodes(flowRoot, documentModel, nodeRects, floatRects);
  const nextRects = readNodeRects(host, flowRoot);
  const nextFloatRects = buildFloatingRects(documentModel, nextRects);
  renderFloatingImages(host, floatingRoot, nextFloatRects);
  rerenderTextNodes(flowRoot, documentModel, nextRects, nextFloatRects);
}

function readNodeRects(host, flowRoot) {
  const rects = {};
  const rootRect = host.getBoundingClientRect();
  flowRoot.querySelectorAll('[data-node-id]').forEach((element) => {
    const rect = element.getBoundingClientRect();
    rects[element.dataset.nodeId] = {
      left: rect.left - rootRect.left,
      top: rect.top - rootRect.top,
      width: rect.width,
      height: rect.height,
      right: rect.right - rootRect.left,
      bottom: rect.bottom - rootRect.top,
    };
  });
  return rects;
}

function buildFloatingRects(documentModel, nodeRects) {
  const rects = {};
  const nodes = documentModel.nodes || [];
  for (let index = 0; index < nodes.length; index += 1) {
    const node = nodes[index];
    if (node.type !== 'image' || node.layoutMode !== 'floating') {
      continue;
    }
    const anchor = resolveAnchorRect(nodes, index, nodeRects);
    const baseLeft = anchor ? anchor.left : 0;
    const baseTop = anchor ? anchor.top : 0;
    const width = clamp(node.width || 280, MIN_IMAGE_WIDTH, MAX_IMAGE_WIDTH);
    const height = clamp(node.height || width * 0.72, MIN_IMAGE_HEIGHT, MAX_IMAGE_HEIGHT);
    rects[node.id] = {
      node,
      left: baseLeft + (node.x || 0),
      top: baseTop + (node.y || 0),
      width,
      height,
      right: baseLeft + (node.x || 0) + width,
      bottom: baseTop + (node.y || 0) + height,
    };
  }
  return rects;
}

function resolveAnchorRect(nodes, imageIndex, nodeRects) {
  const imageNode = nodes[imageIndex];
  const textAnchorRect = resolveTextAnchorRect(imageNode);
  if (textAnchorRect) {
    return textAnchorRect;
  }
  if (imageNode.anchorBlockId && nodeRects[imageNode.anchorBlockId]) {
    return nodeRects[imageNode.anchorBlockId];
  }

  for (let index = imageIndex - 1; index >= 0; index -= 1) {
    const candidate = nodes[index];
    if (candidate.type === 'image' && candidate.layoutMode === 'floating') {
      continue;
    }

    const directRect = nodeRects[candidate.id];
    if (directRect) {
      return directRect;
    }

    if (candidate.type === 'list') {
      for (let itemIndex = candidate.items.length - 1; itemIndex >= 0; itemIndex -= 1) {
        const listItemRect = nodeRects[`${candidate.id}::${itemIndex}`];
        if (listItemRect) {
          return listItemRect;
        }
      }
    }
  }

  return null;
}

function resolveTextAnchorRect(imageNode) {
  if (imageNode.anchorTextOffset == null || imageNode.anchorBlockId == null) {
    return null;
  }

  const targetNodeId = imageNode.anchorListItemIndex != null
    ? `${imageNode.anchorBlockId}::${imageNode.anchorListItemIndex}`
    : imageNode.anchorBlockId;
  const target = queryNode(document, targetNodeId);
  if (!target) {
    return null;
  }

  const host = target.closest('.rte-render-root');
  if (!host) {
    return null;
  }
  const hostRect = host.getBoundingClientRect();
  const tokens = Array.from(target.querySelectorAll('[data-start-offset][data-end-offset]'));
  if (tokens.length === 0) {
    return null;
  }

  const offset = imageNode.anchorTextOffset;
  let previousToken = null;
  let nextToken = null;

  for (const token of tokens) {
    const start = Number(token.dataset.startOffset);
    const end = Number(token.dataset.endOffset);
    if (offset >= start && offset <= end) {
      return buildCaretRectForToken(token, offset, hostRect);
    }
    if (end <= offset) {
      previousToken = token;
      continue;
    }
    nextToken = token;
    break;
  }

  if (previousToken) {
    const rect = previousToken.getBoundingClientRect();
    return {
      left: rect.right - hostRect.left,
      top: rect.top - hostRect.top,
      width: 0,
      height: rect.height,
      right: rect.right - hostRect.left,
      bottom: rect.bottom - hostRect.top,
    };
  }

  if (nextToken) {
    const rect = nextToken.getBoundingClientRect();
    return {
      left: rect.left - hostRect.left,
      top: rect.top - hostRect.top,
      width: 0,
      height: rect.height,
      right: rect.left - hostRect.left,
      bottom: rect.bottom - hostRect.top,
    };
  }

  return null;
}

function buildCaretRectForToken(token, offset, hostRect) {
  const start = Number(token.dataset.startOffset);
  const end = Number(token.dataset.endOffset);
  if (token.dataset.isMath === 'true' || !token.firstChild || token.firstChild.nodeType !== Node.TEXT_NODE) {
    const rect = token.getBoundingClientRect();
    const pointX = offset <= start ? rect.left : rect.right;
    return {
      left: pointX - hostRect.left,
      top: rect.top - hostRect.top,
      width: 0,
      height: rect.height,
      right: pointX - hostRect.left,
      bottom: rect.bottom - hostRect.top,
    };
  }

  const textNode = token.firstChild;
  const localOffset = clamp(offset - start, 0, end - start);
  const range = document.createRange();
  range.setStart(textNode, localOffset);
  range.setEnd(textNode, localOffset);
  const rect = range.getBoundingClientRect();
  const fallbackRect = token.getBoundingClientRect();
  const left = rect.width === 0 && rect.height === 0 ? fallbackRect.left : rect.left;
  const top = rect.width === 0 && rect.height === 0 ? fallbackRect.top : rect.top;
  const bottom = rect.width === 0 && rect.height === 0 ? fallbackRect.bottom : rect.bottom;
  return {
    left: left - hostRect.left,
    top: top - hostRect.top,
    width: 0,
    height: bottom - top,
    right: left - hostRect.left,
    bottom: bottom - hostRect.top,
  };
}

function renderFloatingImages(host, floatingRoot, floatRects) {
  floatingRoot.innerHTML = '';
  let maxBottom = 0;
  Object.values(floatRects)
    .sort((a, b) => (a.node.zIndex || 0) - (b.node.zIndex || 0))
    .forEach((entry) => {
      const element = document.createElement('div');
      element.className = 'rte-floating-image';
      element.style.left = `${entry.left}px`;
      element.style.top = `${entry.top}px`;
      element.style.width = `${entry.width}px`;
      element.style.height = `${entry.height}px`;
      element.style.zIndex = String(entry.node.zIndex || 0);
      if (entry.node.rotationDegrees) {
        element.style.transform = `rotate(${entry.node.rotationDegrees}deg)`;
      }
      element.innerHTML = `<img src="${escapeHtml(entry.node.url)}" alt="${escapeHtml(entry.node.altText || '')}">`;
      floatingRoot.appendChild(element);
      maxBottom = Math.max(maxBottom, entry.bottom);
    });
  host.style.minHeight = `${Math.max(flowRootHeight(host), maxBottom)}px`;
}

function flowRootHeight(host) {
  const flowRoot = host.querySelector('.rte-flow-root');
  return flowRoot ? flowRoot.scrollHeight : 0;
}

function rerenderTextNodes(flowRoot, documentModel, nodeRects, floatRects) {
  for (const node of documentModel.nodes || []) {
    if (node.type === 'textBlock') {
      const element = queryNode(flowRoot, node.id);
      const rect = nodeRects[node.id];
      if (!element || !rect) {
        continue;
      }
      const style = styleForTextBlock(node.style);
      const bands = buildBands(rect, floatRects);
      element.innerHTML = '';
      if (bands.length === 0) {
        const block = document.createElement(style.tag);
        block.className = style.className;
        block.innerHTML = segmentsHtml(node.segments);
        element.appendChild(block);
      } else {
        element.appendChild(buildWrappedLayout(node.segments, style, bands, rect.width));
      }
      continue;
    }

    if (node.type === 'list') {
      (node.items || []).forEach((item, index) => {
        const itemId = `${node.id}::${index}`;
        const element = queryNode(flowRoot, itemId);
        const rect = nodeRects[itemId];
        if (!element || !rect) {
          return;
        }
        const style = {
          ...styleForTextBlock('paragraph'),
          className: 'rte-list-item',
        };
        const bands = buildBands(rect, floatRects);
        element.innerHTML = '';
        if (bands.length === 0) {
          element.innerHTML = segmentsHtml(item);
        } else {
          element.appendChild(buildWrappedLayout(item, style, bands, rect.width));
        }
      });
    }
  }
}

function queryNode(root, id) {
  for (const element of root.querySelectorAll('[data-node-id]')) {
    if (element.dataset.nodeId === id) {
      return element;
    }
  }
  return null;
}

function buildBands(targetRect, floatRects) {
  const bands = [];
  Object.values(floatRects).forEach((entry) => {
    const overlapTop = Math.max(entry.top, targetRect.top);
    const overlapBottom = Math.min(entry.bottom, targetRect.bottom);
    if (overlapBottom <= overlapTop) {
      return;
    }
    bands.push({
      top: overlapTop - targetRect.top,
      bottom: overlapBottom - targetRect.top,
      blockedStart: clamp(entry.left - targetRect.left, 0, targetRect.width),
      blockedEnd: clamp(entry.right - targetRect.left, 0, targetRect.width),
    });
  });
  return bands.sort((a, b) => a.top - b.top);
}

function buildWrappedLayout(segments, style, bands, width) {
  const container = document.createElement('div');
  container.className = style.className;
  const tokens = tokenizeSegments(segments);
  const canvas = document.createElement('canvas');
  const context = canvas.getContext('2d');
  const lineHeight = style.fontSize * style.lineHeight;
  let tokenIndex = 0;
  let currentTop = 0;

  while (tokenIndex < tokens.length) {
    const band = bands.find((entry) => currentTop + lineHeight > entry.top && currentTop < entry.bottom);
    if (!band) {
      const built = takeTokens(tokens, tokenIndex, width, style, context);
      tokenIndex += built.consumed;
      const line = document.createElement('div');
      line.className = 'rte-line';
      built.accepted.forEach((token) => line.appendChild(buildTokenElement(token)));
      container.appendChild(line);
      currentTop += lineHeight;
      continue;
    }

    const leftWidth = clamp(band.blockedStart, 0, width);
    const blockedWidth = clamp(band.blockedEnd - band.blockedStart, 0, width - leftWidth);
    const rightWidth = clamp(width - leftWidth - blockedWidth, 0, width);
    const leftBuilt = leftWidth > 48 ? takeTokens(tokens, tokenIndex, leftWidth, style, context) : { accepted: [], consumed: 0 };
    tokenIndex += leftBuilt.consumed;
    const rightBuilt = rightWidth > 48 ? takeTokens(tokens, tokenIndex, rightWidth, style, context) : { accepted: [], consumed: 0 };
    tokenIndex += rightBuilt.consumed;

    const row = document.createElement('div');
    row.className = `rte-line-block ${style.className}`;

    const left = document.createElement('div');
    left.className = 'rte-line';
    left.style.width = `${leftWidth}px`;
    left.style.minWidth = `${leftWidth}px`;
    leftBuilt.accepted.forEach((token) => left.appendChild(buildTokenElement(token)));

    const blocked = document.createElement('div');
    blocked.style.width = `${blockedWidth}px`;
    blocked.style.minWidth = `${blockedWidth}px`;

    const right = document.createElement('div');
    right.className = 'rte-line';
    right.style.width = `${rightWidth}px`;
    right.style.minWidth = `${rightWidth}px`;
    rightBuilt.accepted.forEach((token) => right.appendChild(buildTokenElement(token)));

    row.appendChild(left);
    row.appendChild(blocked);
    row.appendChild(right);
    container.appendChild(row);
    currentTop += lineHeight;
  }

  if (tokens.length === 0) {
    const empty = document.createElement('div');
    empty.className = 'rte-line';
    empty.innerHTML = '&nbsp;';
    container.appendChild(empty);
  }

  return container;
}

function tokenizeSegments(segments = []) {
  const tokens = [];
  let offset = 0;
  segments.forEach((segment, index) => {
    if (segment.inlineMathLatex) {
      tokens.push({
        value: `\\(${segment.inlineMathLatex}\\)`,
        bold: false,
        italic: false,
        underline: false,
        link: null,
        isMath: true,
        startOffset: offset,
        endOffset: offset + 1,
      });
      offset += 1;
      if (index !== segments.length - 1) {
        tokens.push({
          value: ' ',
          bold: false,
          italic: false,
          underline: false,
          link: null,
          isMath: false,
          startOffset: offset,
          endOffset: offset + 1,
        });
        offset += 1;
      }
      return;
    }

    const text = segment.text || '';
    const matches = text.match(/\S+\s*/g);
    if (!matches || matches.length === 0) {
      if (text.length > 0) {
        tokens.push(toTextToken(segment, text, offset));
        offset += text.length;
      }
      return;
    }
    matches.forEach((part) => {
      tokens.push(toTextToken(segment, part, offset));
      offset += part.length;
    });
  });
  return tokens;
}

function toTextToken(segment, value, startOffset) {
  return {
    value,
    bold: !!segment.bold,
    italic: !!segment.italic,
    underline: !!segment.underline,
    link: segment.link || null,
    isMath: false,
    startOffset,
    endOffset: startOffset + value.length,
  };
}

function takeTokens(tokens, startIndex, width, style, context) {
  if (startIndex >= tokens.length || width <= 0) {
    return { accepted: [], consumed: 0 };
  }
  const accepted = [];
  let consumed = 0;
  let totalWidth = 0;

  for (let index = startIndex; index < tokens.length; index += 1) {
    const token = tokens[index];
    const tokenWidth = measureToken(token, style, context);
    if (accepted.length > 0 && totalWidth + tokenWidth > width) {
      break;
    }
    accepted.push(token);
    consumed += 1;
    totalWidth += tokenWidth;
  }

  if (consumed === 0) {
    return { accepted: [tokens[startIndex]], consumed: 1 };
  }
  return { accepted, consumed };
}

function measureToken(token, style, context) {
  if (!context) {
    return token.value.length * style.fontSize * 0.58;
  }
  context.font = `${token.bold ? 700 : style.fontWeight} ${token.italic ? 'italic ' : ''}${style.fontSize}px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`;
  return context.measureText(token.value).width;
}

function buildTokenElement(token) {
  const element = token.link ? document.createElement('a') : document.createElement('span');
  const classes = ['rte-token'];
  if (token.bold) classes.push('bold');
  if (token.italic) classes.push('italic');
  if (token.underline) classes.push('underline');
  if (token.link) classes.push('link');
  element.className = classes.join(' ');
  if (token.link) {
    element.href = token.link;
  }
  element.dataset.startOffset = String(token.startOffset);
  element.dataset.endOffset = String(token.endOffset);
  element.dataset.isMath = token.isMath ? 'true' : 'false';
  element.innerHTML = token.isMath ? token.value : escapeHtml(token.value);
  return element;
}

function styleForTextBlock(style) {
  if (style === 'heading1') {
    return { tag: 'h1', className: 'rte-heading1', fontSize: 30, lineHeight: 1.25, fontWeight: 700 };
  }
  if (style === 'heading2') {
    return { tag: 'h2', className: 'rte-heading2', fontSize: 22, lineHeight: 1.3, fontWeight: 600 };
  }
  return { tag: 'p', className: 'rte-paragraph', fontSize: 16, lineHeight: 1.4, fontWeight: 400 };
}

function segmentsHtml(segments = []) {
  return segments.map((segment) => {
    if (segment.inlineMathLatex) {
      return `<span data-node="math-inline" data-latex="${escapeHtml(segment.inlineMathLatex)}">\\(${escapeHtml(segment.inlineMathLatex)}\\)</span>`;
    }
    let content = escapeHtml(segment.text || '');
    if (segment.bold) content = `<strong>${content}</strong>`;
    if (segment.italic) content = `<em>${content}</em>`;
    if (segment.underline) content = `<u>${content}</u>`;
    if (segment.link) content = `<a href="${escapeHtml(segment.link)}">${content}</a>`;
    return content;
  }).join('');
}

function hasWrapSegments(segments = []) {
  return segments.some((segment) => (segment.text || '').trim().length > 0 || segment.inlineMathLatex);
}

function requestMathTypeset(element) {
  if (window.MathJax && typeof window.MathJax.typesetPromise === 'function') {
    return window.MathJax.typesetPromise([element]).catch(() => {});
  }
  return Promise.resolve();
}

function attachDeferredLayoutPasses(element, performLayout) {
  const scheduleLayout = createLayoutScheduler(() => performLayout());

  element.querySelectorAll('img').forEach((image) => {
    if (!image.complete) {
      image.addEventListener('load', scheduleLayout, { once: true });
      image.addEventListener('error', scheduleLayout, { once: true });
    }
  });

  if (typeof document !== 'undefined' && document.fonts && document.fonts.ready) {
    document.fonts.ready.then(scheduleLayout).catch(() => {});
  }

  if (typeof window !== 'undefined') {
    window.addEventListener('load', scheduleLayout, { once: true });
  }
}

function createLayoutScheduler(callback) {
  let scheduled = false;
  return () => {
    if (scheduled) {
      return;
    }
    scheduled = true;
    const run = () => {
      scheduled = false;
      callback();
    };
    if (typeof window !== 'undefined' && typeof window.requestAnimationFrame === 'function') {
      window.requestAnimationFrame(run);
      return;
    }
    setTimeout(run, 0);
  };
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

if (typeof window !== 'undefined' && typeof document !== 'undefined') {
  defineCustomElement();

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      autoMountRichTextDocuments();
    });
  } else {
    autoMountRichTextDocuments();
  }
}
