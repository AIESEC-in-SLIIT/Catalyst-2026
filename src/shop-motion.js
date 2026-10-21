import { animate, inView, hover } from 'framer-motion/dom';

// Motion owns presentation; GSAP owns the carousel and scroll-reactive petals.
export function installShopMotion() {
  const preference = matchMedia('(prefers-reduced-motion: reduce)');
  const controls = new Set();
  const owners = new WeakMap();
  const cleanups = [];
  const ease = [.22, 1, .36, 1];
  const disabled = () => preference.matches || document.body.classList.contains('market-motion-paused');

  function play(target, keyframes, options = {}) {
    const elements = typeof target === 'string' ? [...document.querySelectorAll(target)] : target instanceof Element ? [target] : [...target];
    elements.forEach(element => owners.get(element)?.stop());
    const control = animate(elements, keyframes, { duration: .55, ease, ...options, ...(disabled() ? { duration: 0, delay: 0 } : {}) });
    controls.add(control);
    elements.forEach(element => owners.set(element, control));
    control.then(() => controls.delete(control));
    return control;
  }

  function reveal(selector, distance = 18) {
    cleanups.push(inView(selector, element => {
      if (disabled()) return;
      play(element, { opacity: [0, 1], y: [distance, 0] });
    }, { amount: .15 }));
  }

  reveal('.market-kicker', 8);
  reveal('#market-title', 14);
  reveal('.market-subline', 10);
  reveal('.collection-topline', 10);
  reveal('.drop-note > div', 22);
  reveal('.drop-note > img', 12);
  reveal('.footer-identity, .footer-community, .footer-logo-panel', 18);
  cleanups.push(inView('.orbit-stage', () => {
    if (!disabled()) {
      // One group keeps the fan cohesive as it enters the viewport.
      play('.card-face', { opacity: [0, 1], y: [28, 0] }, { duration: .8 });
    }
  }, { amount: .12 }));

  cleanups.push(hover('.preview-active, .detail-back, .footer-socials a, .market-navigation a', element => {
    if (disabled()) return;
    const arrow = element.querySelector('.nav-arrow, span:last-child');
    if (!arrow || !arrow.textContent.includes('↗') && !arrow.textContent.includes('↙')) return;
    play(arrow, { x: 3, y: -3 }, { type: 'spring', stiffness: 300, damping: 24 });
    return () => play(arrow, { x: 0, y: 0 }, { duration: .25 });
  }));

  // Finishing instead of stopping leaves every reveal visible and usable.
  const settle = () => { if (disabled()) controls.forEach(control => control.complete()); };
  preference.addEventListener('change', settle);
  const pauseObserver = new MutationObserver(settle);
  pauseObserver.observe(document.body, { attributes: true, attributeFilter: ['class'] });
  return {
    play,
    dispose() {
      cleanups.forEach(cleanup => cleanup());
      preference.removeEventListener('change', settle);
      pauseObserver.disconnect();
      controls.forEach(control => control.complete());
      controls.clear();
    },
  };
}
