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
