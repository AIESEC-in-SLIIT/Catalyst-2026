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
          duration: Number(path.dataset.duration),
        }, Number(path.dataset.at));
      });
      timeline
        .to(select('[data-part="helmet-base"]'), { fill: '#201b13', duration: .24 }, .17)
        .to(select('[data-face-detail]'), { opacity: 0, duration: .22 }, .2)
        .to(select('[data-horn-clip]'), {
          morphSVG: 'M550 340Q90 355 270 -20L830 -20Q1010 355 550 340Z', duration: .43,
        }, .27)
        .fromTo(select('[data-crest]'), { scale: .65, svgOrigin: '550 200' }, { scale: 1, opacity: 1, duration: .24 }, .43)
        .to(select('#evolving-face'), { attr: { y1: 320, y2: 475 }, duration: .4 }, .24)
        .to(select('[data-part="jaw"]'), { fill: '#c90038', duration: .3 }, .34)
        .to(select('[data-nostrils], [data-chin-line]'), { opacity: 1, duration: .2 }, .46)
        .to(select('[data-teeth-clip]'), { attr: { height: 40 }, duration: .26 }, .44)
        .to(select('[data-robe-flowers]'), { opacity: 0, duration: .22 }, .34)
        .to(select('[data-part="robe"]'), { fill: '#c90038', duration: .38 }, .34)
