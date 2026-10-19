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
