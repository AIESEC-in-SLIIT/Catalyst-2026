import { gsap } from 'gsap';
import './interactions.js';
import { installShopMotion } from './shop-motion.js';
import wristbands from '../assets/merch/wristbands.svg';
import regular from '../assets/merch/regular.svg';
import oversized from '../assets/merch/oversized.svg';
import stickers from '../assets/merch/sticker-pack.svg';
import hat from '../assets/merch/bucket-hat.svg';

// Replace the local mockups here when the final product photography is available.
const products = [
  { name: 'WRISTBANDS', tab: 'WRISTBANDS', fit: 'SMALL DETAIL. SHARED SPIRIT.', image: wristbands, background: '#c90038', ink: '#f1eadf', description: 'A reminder of the people, the purpose, and the moments you carry with you. The Catalyst wristband, made for your everyday.' },
  { name: 'REGULAR TEE', tab: 'REGULAR TEE', fit: 'YOUR EVERYDAY UNIFORM.', image: regular, background: '#ded5c5', ink: '#201b13', description: 'The Catalyst spirit in a classic silhouette. An everyday T-shirt to take a little of the conference with you, wherever you go.' },
  { name: 'OVERSIZED TEE', tab: 'OVERSIZED TEE', fit: 'MORE ROOM. SAME FEARLESS SPIRIT.', image: oversized, background: '#26231d', ink: '#f1eadf', description: 'A relaxed silhouette with a bold Catalyst identity. The oversized edition brings the same shared spirit to a little more room.' },
  { name: 'STICKER PACK', tab: 'STICKERS', fit: 'LEAVE YOUR MARK.', image: stickers, background: '#d4b99b', ink: '#201b13', description: 'A collection of Catalyst-inspired marks for the things you take everywhere. Give your notebook, laptop, or everyday essentials a little character.' },
  { name: 'BUCKET HAT', tab: 'BUCKET HAT', fit: 'TOP OFF YOUR NEXT CHAPTER.', image: hat, background: '#c90038', ink: '#f1eadf', description: 'A finishing touch for your Catalyst collection. Take the Catalyst spirit beyond the conference and into your next adventure.' },
];
const stage = document.querySelector('.orbit-stage');
const wheel = document.querySelector('.orbit-wheel');
const tabs = document.querySelector('.product-tabs');
const dialog = document.querySelector('.product-dialog');
const pauseButton = document.querySelector('.orbit-pause');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const controller = new AbortController();
const listen = (target, event, handler, options = {}) => target.addEventListener(event, handler, { ...options, signal: controller.signal });
const mod = (value, divisor) => ((value % divisor) + divisor) % divisor;
const pad = number => String(number).padStart(2, '0');
const slots = products.length * 3;
const step = 360 / slots;
const state = { angle: 0 };
let selected = 0;
let paused = reducedMotion.matches;
let hovering = false;
let inView = false;
let dragging = null;
let suppressClickUntil = 0;
let animation = null;
let lastInteraction = 0;
let radius = 500;
let opener = null;
let bodyOverflow = '';
let closingDialog = false;
let motion;
const leafBursts = new Map();
const petalHost = stage.querySelector('.market-petals');
const burstArtwork = petalHost.querySelector('svg');
let previousWheelAngle = null;
let previousWheelTime = 0;
let burstCredit = 0;
let burstSequence = 0;

products.forEach((product, index) => {
  const tab = document.createElement('button');
  tab.className = 'product-tab';
  tab.type = 'button';
  tab.innerHTML = `<span>${pad(index + 1)}</span>${product.tab}`;
  tab.setAttribute('aria-current', String(index === 0));
  listen(tab, 'click', () => selectProduct(index));
  tabs.append(tab);
});

for (let slot = 0; slot < slots; slot++) {
  const index = slot % products.length;
  const product = products[index];
  const card = document.createElement('button');
  card.type = 'button';
  card.className = 'orbit-card';
  card.dataset.product = index;
  card.setAttribute('aria-label', `Preview ${product.name.toLowerCase()} — coming soon`);
  // The five stable controls below the wheel provide a predictable keyboard order.
  card.tabIndex = -1;
  card.style.setProperty('--card-bg', product.background);
  card.style.setProperty('--card-ink', product.ink);
  card.innerHTML = `<span class="card-face"><span class="card-meta"><span class="card-brand">CATALYST ’26</span><span>${pad(index + 1)} / 05</span></span><span class="card-decoration" aria-hidden="true">CATALYST</span><img class="card-art" src="${product.image}" alt="${product.name.toLowerCase()} concept illustration" draggable="false" width="400" height="460"><span class="card-bottom"><strong>${product.name.replace(' ', '<br>')}</strong><small>DESIGN<br>PREVIEW ↗</small></span></span>`;
  listen(card, 'click', () => openProduct(index, card));
  wheel.append(card);
}
const cards = [...wheel.children];
const setRotation = gsap.quickSetter(wheel, 'rotation', 'deg');

function layout() {
  const mobile = stage.clientWidth <= 750;
  const width = mobile ? Math.min(200, stage.clientWidth * .47) : Math.min(275, stage.clientWidth * .205);
  const height = width * 1.4;
  radius = mobile ? Math.max(280, stage.clientWidth * .63) : Math.min(650, stage.clientWidth * .445);
  const pivot = radius + height / 2 + 34;
  stage.style.setProperty('--card-width', `${width}px`);
  stage.style.setProperty('--card-height', `${height}px`);
  stage.style.setProperty('--pivot', `${pivot}px`);
  stage.style.setProperty('--hub-top', `${height + (mobile ? 65 : 72)}px`);
  stage.style.setProperty('--orbit-radius', `${radius}px`);
  stage.style.setProperty('--guide-size', `${radius * 1.26}px`);
  stage.style.setProperty('--guide-top', `${pivot - radius * .63}px`);
  stage.style.height = `${height + (mobile ? 265 : 280)}px`;
  cards.forEach((card, slot) => {
    const angle = slot * step;
    const radians = angle * Math.PI / 180;
    gsap.set(card, { xPercent: -50, yPercent: -50, x: Math.sin(radians) * radius, y: -Math.cos(radians) * radius, rotation: 0 });
  });
  render();
}

function updateProduct(index) {
  if (index === selected) return;
  selected = index;
  const product = products[index];
  const title = document.querySelector('#active-product');
  const fit = document.querySelector('.active-fit');
  title.textContent = product.name;
  fit.textContent = product.fit;
  document.querySelector('.product-count').innerHTML = `${pad(index + 1)} <i>/</i> 05`;
  [...tabs.children].forEach((tab, tabIndex) => tab.setAttribute('aria-current', String(tabIndex === index)));
  if (!reducedMotion.matches) {
    motion?.play([title, fit], { y: [7, 0], opacity: [.55, 1] }, { duration: .32 });
  }
}

function render() {
  emitWheelLeaves();
  setRotation(state.angle);
  const topSlot = mod(Math.round(-state.angle / step), slots);
  updateProduct(topSlot % products.length);
  cards.forEach((card, slot) => {
    // Keep each card upright as the carousel turns.
    gsap.set(card, { rotation: -state.angle });
    const degrees = mod(slot * step + state.angle + 180, 360) - 180;
    const visible = Math.abs(degrees) < 95;
    const visibility = visible ? 'visible' : 'hidden';
    if (card.style.visibility !== visibility) {
      card.style.visibility = visibility;
      card.setAttribute('aria-hidden', String(!visible));
    }
    const zIndex = String(100 - Math.round(Math.abs(degrees)));
    if (card.style.zIndex !== zIndex) card.style.zIndex = zIndex;
  });
}

function rotateTo(angle, velocity = 0) {
  animation?.kill();
  lastInteraction = performance.now();
  if (reducedMotion.matches) {
    state.angle = angle;
    render();
    animation = null;
    return;
  }
  animation = gsap.to(state, { angle, duration: Math.min(1.3, .8 + Math.abs(velocity) * .002), ease: 'power3.out', onUpdate: render, onComplete: () => { animation = null; } });
}
function selectProduct(index) {
  const currentSlot = -state.angle / step;
  const closest = index + Math.round((currentSlot - index) / products.length) * products.length;
  rotateTo(-closest * step);
}
function nudge(direction) {
  const target = -Math.round(-state.angle / step) * step - direction * step;
  rotateTo(target);
}

listen(document.querySelector('.orbit-prev'), 'click', () => nudge(-1));
listen(document.querySelector('.orbit-next'), 'click', () => nudge(1));
listen(document.querySelector('.preview-active'), 'click', event => openProduct(selected, event.currentTarget));
stage.tabIndex = 0;
listen(stage, 'keydown', event => {
  if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
    event.preventDefault();
    nudge(event.key === 'ArrowRight' ? 1 : -1);
  }
});

function syncPause() {
  leafBursts.forEach(timeline => paused ? timeline.pause() : timeline.resume());
  document.body.classList.toggle('market-motion-paused', paused);
  pauseButton.setAttribute('aria-pressed', String(paused));
  pauseButton.setAttribute('aria-label', paused ? 'Resume marketplace motion' : 'Pause marketplace motion');
  pauseButton.querySelector('span').textContent = paused ? '▷' : 'Ⅱ';
  pauseButton.querySelector('.pause-label').textContent = paused ? 'RESUME MOTION' : 'PAUSE MOTION';
}
listen(pauseButton, 'click', () => { paused = !paused; syncPause(); });
listen(reducedMotion, 'change', () => {
  paused = reducedMotion.matches;
  animation?.kill();
  animation = null;
  rotateTo(-Math.round(-state.angle / step) * step);
  syncPause();
});
listen(stage, 'pointerenter', event => { if (event.pointerType === 'mouse') hovering = true; });
listen(stage, 'pointerleave', () => { hovering = false; });
listen(stage, 'pointerdown', event => {
  if (event.button !== 0 || event.target.closest('.orbit-hub')) return;
  animation?.kill();
  animation = null;
  dragging = { id: event.pointerId, startX: event.clientX, startY: event.clientY, angle: state.angle, lastX: event.clientX, lastTime: performance.now(), velocity: 0, moved: false };
  lastInteraction = performance.now();
});
listen(stage, 'pointermove', event => {
  if (!dragging || dragging.id !== event.pointerId) return;
  const dx = event.clientX - dragging.startX;
  const dy = event.clientY - dragging.startY;
  if (!dragging.moved && Math.abs(dy) > Math.abs(dx) && Math.abs(dy) > 9) { dragging = null; return; }
  if (!dragging.moved && Math.abs(dx) < 7) return;
  if (!dragging.moved) { dragging.moved = true; stage.setPointerCapture(event.pointerId); stage.classList.add('is-dragging'); }
  const now = performance.now();
  dragging.velocity = (event.clientX - dragging.lastX) / Math.max(1, now - dragging.lastTime);
  dragging.lastX = event.clientX;
  dragging.lastTime = now;
  state.angle = dragging.angle + dx / radius * 180 / Math.PI;
  render();
});
function finishDrag(event) {
  if (!dragging || dragging.id !== event.pointerId) return;
  const gesture = dragging;
  dragging = null;
  stage.classList.remove('is-dragging');
  if (stage.hasPointerCapture(event.pointerId)) stage.releasePointerCapture(event.pointerId);
  if (gesture.moved) {
    suppressClickUntil = performance.now() + 400;
    const velocity = event.type === 'pointercancel' || performance.now() - gesture.lastTime > 100 ? 0 : gesture.velocity;
    const projected = state.angle + Math.max(-step * 1.5, Math.min(step * 1.5, velocity * 20));
    rotateTo(Math.round(projected / step) * step, velocity);
  }
}
listen(stage, 'pointerup', finishDrag);
listen(stage, 'pointercancel', finishDrag);
listen(stage, 'lostpointercapture', finishDrag);
listen(stage, 'click', event => {
  if (performance.now() < suppressClickUntil) { event.preventDefault(); event.stopImmediatePropagation(); }
}, { capture: true });
listen(stage, 'dragstart', event => event.preventDefault());
// Wheel and trackpad movement turn the carousel while the pointer is over it.
listen(stage, 'wheel', event => {
  const distance = Math.abs(event.deltaX) > Math.abs(event.deltaY) ? event.deltaX : event.deltaY;
  if (Math.abs(distance) < 1) return;
  event.preventDefault();
  animation?.kill(); animation = null;
  lastInteraction = performance.now();
  const pixels = distance * (event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? stage.clientHeight : 1);
  state.angle -= Math.max(-120, Math.min(120, pixels)) * .18;
  render();
}, { passive: false });

function openProduct(index, source) {
  const product = products[index];
  opener = source;
  document.querySelector('.detail-art').style.setProperty('--detail-bg', product.background);
  document.querySelector('.detail-art').innerHTML = `<img src="${product.image}" alt="${product.name.toLowerCase()} placeholder design" width="400" height="460">`;
  document.querySelector('#detail-title').textContent = product.name;
  document.querySelector('.detail-index').textContent = `OBJECT ${pad(index + 1)} / 05`;
  document.querySelector('.detail-description').textContent = product.description;
  bodyOverflow = document.body.style.overflow;
  document.body.style.overflow = 'hidden';
  dialog.showModal();
  closingDialog = false;
  motion.play(dialog, { opacity: [0, 1], y: [16, 0], scale: [.98, 1] }, { duration: .35 });
}
function closeProduct() {
  if (!dialog.open || closingDialog) return;
  closingDialog = true;
  if (reducedMotion.matches || paused) { dialog.close(); return; }
  motion.play(dialog, { opacity: 0, y: 10, scale: .99 }, { duration: .18, ease: 'easeIn' }).then(() => {
    if (dialog.open) dialog.close();
  });
}
listen(document.querySelector('.dialog-close'), 'click', closeProduct);
listen(document.querySelector('.detail-back'), 'click', closeProduct);
listen(dialog, 'cancel', event => { event.preventDefault(); closeProduct(); });
listen(dialog, 'click', event => {
  const box = dialog.getBoundingClientRect();
  if (event.target === dialog && (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom)) closeProduct();
});
listen(dialog, 'close', () => { closingDialog = false; document.body.style.overflow = bodyOverflow; opener?.focus({ preventScroll: true }); lastInteraction = performance.now(); });
const observer = new IntersectionObserver(([entry]) => {
  inView = entry.isIntersecting;
  if (inView) stage.querySelector('.market-petals').classList.add('petals-started');
}, { threshold: .1 });
observer.observe(stage);
let layoutWidth = 0;
const resizeObserver = new ResizeObserver(() => {
  if (stage.clientWidth === layoutWidth) return;
  layoutWidth = stage.clientWidth;
  layout();
});
resizeObserver.observe(stage);
// The wrapper adds scroll movement without replacing the CSS drift or tumble.
const petalScrollLayers = [...document.querySelectorAll('.petal-scroll')];
const petalSetters = petalScrollLayers.map((layer, index) => ({
  x: gsap.quickSetter(layer, 'x', 'px'),
  y: gsap.quickSetter(layer, 'y', 'px'),
  rotation: gsap.quickSetter(layer, 'rotation', 'deg'),
  depth: [1, .65, 1.3, .45, .7, 1.1][index],
  direction: index % 2 ? -1 : 1,
}));
let petalScroll = window.scrollY;
let lastPetalScroll = null;
function updatePetalScroll(delta) {
  if (document.hidden || paused || reducedMotion.matches || dialog.open) return;
  const target = window.scrollY;
  // Frame-rate independent easing gives a brief sense of weight when scrolling reverses.
  petalScroll += (target - petalScroll) * (1 - Math.exp(-Math.min(delta, 64) / 150));
  const wind = Math.max(-70, Math.min(70, (target - petalScroll) * .35));
  if (lastPetalScroll !== null && Math.abs(lastPetalScroll - petalScroll) < .01 && Math.abs(target - petalScroll) < .05) return;
  lastPetalScroll = petalScroll;
  petalSetters.forEach(({ x, y, rotation, depth, direction }) => {
    x((petalScroll * .018 + wind * .3) * depth * direction);
    y((petalScroll * .12 + wind) * depth);
    rotation((petalScroll * .025 + wind * .4) * direction);
  });
}
function emitScrollLeaf(speed, scrollDirection) {
  // Bound the live particle count so rapid trackpad gestures stay inexpensive.
  if (leafBursts.size >= 20) return;
  const leaf = document.createElement('div');
  leaf.className = 'market-scroll-leaf';
  leaf.append(burstArtwork.cloneNode(true));
  petalHost.append(leaf);
  const side = burstSequence++ % 2 ? 1 : -1;
  const energy = Math.min(speed / 1800, 1);
  const duration = 5.8 - energy * 2;
  const travelX = side * stage.clientWidth * (.4 + Math.random() * .2);
  const travelY = -stage.clientHeight * (.16 + Math.random() * .26) + scrollDirection * energy * 65;
  gsap.set(leaf, { xPercent: -50, scale: .45, opacity: 0, rotation: side * 15, width: 15 + Math.random() * 22 });
  const timeline = gsap.timeline({ onComplete: () => { leafBursts.delete(leaf); leaf.remove(); } });
  leafBursts.set(leaf, timeline);
  timeline.to(leaf, { x: travelX, y: travelY, rotation: side * (100 + energy * 100), scale: 1, duration, ease: 'sine.out' }, 0)
    .to(leaf, { opacity: .8, duration: .3 }, 0)
    .to(leaf, { opacity: 0, duration: 1.1 }, duration - 1.1);
}
function emitWheelLeaves() {
  const now = performance.now();
  if (previousWheelAngle === null) {
    previousWheelAngle = state.angle;
    previousWheelTime = now;
    return;
  }
  const angleDelta = state.angle - previousWheelAngle;
  const elapsed = Math.max(16, now - previousWheelTime);
  previousWheelAngle = state.angle;
  previousWheelTime = now;
  if (!inView || document.hidden || paused || reducedMotion.matches || dialog.open || Math.abs(angleDelta) < .12) {
    if (!inView || document.hidden || paused || reducedMotion.matches || dialog.open) burstCredit = 0;
    return;
  }
  const speed = Math.abs(angleDelta) / elapsed * 1000;
  // A turn releases petals; a faster turn releases more.
  burstCredit = Math.min(5, burstCredit + Math.abs(angleDelta) * (.055 + Math.min(speed, 500) * .00016));
  while (burstCredit >= 1) {
    emitScrollLeaf(speed, Math.sign(angleDelta));
    burstCredit -= 1;
  }
}
function tick(_time, delta) {
  updatePetalScroll(delta);
  if (!inView || document.hidden || paused || hovering || dragging || animation || dialog.open || stage.contains(document.activeElement) || performance.now() - lastInteraction < 3000) return;
  state.angle -= Math.min(delta, 50) * .0025;
  render();
}
layout();
syncPause();
gsap.ticker.add(tick);
motion = installShopMotion();
if (import.meta.hot) import.meta.hot.dispose(() => {
  controller.abort(); observer.disconnect(); resizeObserver.disconnect(); gsap.ticker.remove(tick); animation?.kill();
  motion.dispose();
  leafBursts.forEach((timeline, leaf) => { timeline.kill(); leaf.remove(); });
  leafBursts.clear();
  if (dialog.open) { dialog.close(); document.body.style.overflow = bodyOverflow; }
  gsap.set(petalScrollLayers, { clearProps: 'transform' });
  stage.querySelector('.market-petals').classList.remove('petals-started');
  document.body.classList.remove('market-motion-paused');
  wheel.replaceChildren(); tabs.replaceChildren();
});
