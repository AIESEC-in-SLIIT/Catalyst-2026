import React, { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { MorphSVGPlugin } from 'gsap/MorphSVGPlugin';
import Character from './Character';
import './interactions';

gsap.registerPlugin(ScrollTrigger, MorphSVGPlugin);

function Hero() {
  const scene = useRef(null);
  const [systemReduced, setSystemReduced] = useState(() => matchMedia('(prefers-reduced-motion: reduce)').matches);
  const [manualReduced, setManualReduced] = useState(false);
  const reduced = systemReduced || manualReduced;
  useEffect(() => {
    const media = matchMedia('(prefers-reduced-motion: reduce)');
    const update = () => setSystemReduced(media.matches);
    media.addEventListener('change', update);
    return () => media.removeEventListener('change', update);
  }, []);

  useLayoutEffect(() => {
    let active = true;
    const ctx = gsap.context(() => {
      const select = gsap.utils.selector(scene.current);
      const timeline = gsap.timeline({ paused: true, defaults: { ease: 'sine.inOut' } });
      // A normalized, centralized timeline: all overlapping stages reverse exactly.
      timeline.to({}, { duration: 1 }, 0);
      select('[data-morph]').forEach(path => {
        timeline.to(path, {
          morphSVG: { shape: path.dataset.morph, shapeIndex: 'auto' },
