import { gsap } from 'gsap';

// Visual copies live outside the control so its semantics and click handler stay intact.
function visualCopy(source) {
  const copy = source.cloneNode(true);
  const originals = [source, ...source.querySelectorAll('*')];
  const copies = [copy, ...copy.querySelectorAll('*')];
  copies.forEach((node, index) => {
    const computed = getComputedStyle(originals[index]);
    for (const property of computed) node.style.setProperty(property, computed.getPropertyValue(property));
    node.removeAttribute('id');
    node.removeAttribute('href');
    node.removeAttribute('autofocus');
    node.setAttribute('tabindex', '-1');
  });
  Object.assign(copy.style, { position: 'absolute', inset: '0', margin: '0', width: '100%', height: '100%', transform: 'none', transition: 'none', animation: 'none', opacity: '1' });
  return copy;
}

function installSlices() {
  const active = new Map();
  let navigating = false;
  const handleClick = event => {
    const target = event.target.closest?.('a, button, summary');
    if (!target || target.closest('.slice-effect') || target.classList.contains('skip-link') || target.disabled || event.defaultPrevented || event.button > 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    if (matchMedia('(prefers-reduced-motion: reduce)').matches || document.querySelector('.motion-paused')) return;
    const anchor = target.closest('a[href]');
    const url = anchor ? new URL(anchor.href, location.href) : null;
    const delayedNavigation = url && url.origin === location.origin && !anchor.hasAttribute('download') && (!anchor.target || anchor.target === '_self');
    if (delayedNavigation) {
      event.preventDefault();
      if (navigating) return;
      navigating = true;
    }
    active.get(target)?.();
    const bounds = target.getBoundingClientRect();
    const overlay = document.createElement('div');
    overlay.className = 'slice-effect';
    overlay.setAttribute('aria-hidden', 'true');
    overlay.inert = true;
    Object.assign(overlay.style, { left: `${bounds.left}px`, top: `${bounds.top}px`, width: `${bounds.width}px`, height: `${bounds.height}px` });
    const halves = [visualCopy(target), visualCopy(target)];
    halves[0].style.clipPath = 'polygon(0 0,100% 0,100% 11%,0 89%)';
    halves[1].style.clipPath = 'polygon(0 89%,100% 11%,100% 100%,0 100%)';
    overlay.append(...halves);
    const slash = document.createElement('i');
    slash.className = 'slice-stroke';
    overlay.append(slash);
    const sword = document.createElement('div');
    sword.className = 'sword-strike';
    sword.setAttribute('aria-hidden', 'true');
    sword.innerHTML = `<svg viewBox="0 0 240 76" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="katana-steel" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#fffef7"/><stop offset=".42" stop-color="#e7dfcf"/><stop offset=".5" stop-color="#fff"/><stop offset="1" stop-color="#999183"/></linearGradient></defs><path d="M205 25 23 51Q13 53 4 68L207 39Q218 36 220 31L211 25Z" fill="url(#katana-steel)" stroke="#201b13" stroke-width="2"/><path d="m204 31-180 31" stroke="#fff" stroke-opacity=".9" stroke-width="2"/><path d="m207 21 14 14-7 8-17-17Z" fill="#c90038" stroke="#201b13" stroke-width="2"/><path d="m215 29 11 8-5 6-12-7Z" fill="#f1eadf" stroke="#201b13" stroke-width="2"/><path d="m220 36 17 3-4 12-21-6-5-7Z" fill="#201b13"/><path d="m218 39 12 4m-14-1 12 4m-15-1 12 4" stroke="#f1eadf" stroke-width="2"/><path d="m229 43 9 8-5 6-11-8Z" fill="#c90038" stroke="#201b13" stroke-width="2"/><path d="M7 66 4 68l4-7" fill="#fff"/><path d="m195 42 26 10" stroke="#fff" stroke-width="2" stroke-linecap="round"/></svg>`;
    const swordWidth = Math.max(104, Math.min(260, bounds.width * 1.6));
    Object.assign(sword.style, { width: `${swordWidth}px`, height: `${swordWidth * .32}px`, left: `${(bounds.width - swordWidth) / 2}px`, top: `${(bounds.height - swordWidth * .32) / 2}px` });
    overlay.append(sword);
    const impact = document.createElement('i');
    impact.className = 'slice-impact';
    overlay.append(impact);
    document.body.append(overlay);
    const opacity = target.style.opacity;
    target.style.opacity = '0';
    let timeline;
    const cleanup = () => {
      timeline?.kill();
      overlay.remove();
      target.style.opacity = opacity;
      active.delete(target);
    };
    active.set(target, cleanup);
    timeline = gsap.timeline({ onComplete: () => {
      cleanup();
      if (!delayedNavigation) return;
      navigating = false;
      if (url.pathname === location.pathname && url.search === location.search && url.hash) {
        let destination;
        try { destination = document.getElementById(decodeURIComponent(url.hash.slice(1))); } catch { /* Native navigation handles malformed fragments. */ }
        if (destination) {
          history.pushState(null, '', url.hash);
