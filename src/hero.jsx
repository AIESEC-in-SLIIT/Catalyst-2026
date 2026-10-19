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
        .to(select('[data-neck-clip]'), { attr: { rx: 230, ry: 245 }, duration: .36 }, .43)
        .fromTo(select('[data-neck-line]'), { opacity: 0 }, { opacity: 1, duration: .18, stagger: .06 }, .53)
        .to(select('#neck-shadow stop:first-child'), { attr: { 'stop-color': '#201b13' }, duration: .32 }, .4)
        .to(select('[data-character-root]'), { scale: 1.04, svgOrigin: '550 420', duration: .28 }, .66)
        .to(select('.hero-progress'), { scaleX: 1, duration: 1, ease: 'none' }, 0);

      if (!reduced) {
        timeline.to(select('.hero-heading'), {
          y: () => -select('.hero-pinned')[0].offsetHeight * .24,
          duration: 1, ease: 'none',
        }, 0);
        gsap.set(select('[data-blink="left"]'), { svgOrigin: '496 366' });
        gsap.set(select('[data-blink="right"]'), { svgOrigin: '604 366' });
        const blink = gsap.timeline({ repeat: -1, repeatDelay: 4.2, delay: 2.6 });
        blink.to(select('[data-blink]'), { scaleY: .06, duration: .09, ease: 'power2.in' })
          .to(select('[data-blink]'), { scaleY: 1, duration: .15, ease: 'power2.out' });
      }
      if (reduced) {
        timeline.progress(1);
      } else {
        ScrollTrigger.create({
          id: 'catalyst-transformation',
          trigger: scene.current,
          pin: select('.hero-pinned')[0],
          animation: timeline,
          start: () => `top ${document.querySelector('.navigation').offsetHeight}px`,
          end: () => `+=${Math.round(innerHeight * (innerWidth < 651 ? 1.3 : 1.65))}`,
          scrub: true,
          anticipatePin: 1,
          invalidateOnRefresh: true,
        });
      }
      document.fonts.ready.then(() => { if (active) ScrollTrigger.refresh(); });
    }, scene);
    return () => { active = false; ctx.revert(); };
  }, [reduced]);

  return <>
    <section ref={scene} className={`hero-scroll-scene gsap-scene${reduced ? ' reduced-scene motion-paused' : ''}`} aria-labelledby="hero-title">
      <div className="hero hero-pinned">
        <div className="rail rail-left" aria-hidden="true"><span>01 / 02</span><span>AIESEC IN SLIIT</span><span>LEADERS ARE FORGED</span></div>
        <div className="rail rail-right" aria-hidden="true"><span>2026 EDITION</span><span>IGNITE THE LEADER WITHIN</span><span>CATALYST · SRI LANKA</span></div>
        <div className="hero-stage">
          <div className="hero-heading">
            <div><p className="hero-japanese" lang="ja">覚醒の時</p><p className="eyebrow hero-caption">THE TIME TO AWAKEN</p></div>
            <h1 id="hero-title" className="motion-title"><span className="title-top">IGNITE</span><span className="title-bottom">CATALYST</span></h1>
          </div>
          <div className="warrior-motion"><Character /></div>
          <div className="drifting-leaves" aria-hidden="true">
            {[0, 1, 2, 3, 4, 5].map(index => <div key={index} className={`leaf-flight leaf-flight-${index}`}><svg viewBox="0 0 80 110"><path d="M5 103C-6 63 10 25 64 5L67 31 78 24C85 68 64 94 31 98L12 107 22 86Z" fill="currentColor"/></svg></div>)}
          </div>
          <div className="hero-footnote"><span>LEADERSHIP DEVELOPMENT SEMINAR<br/>AIESEC IN SLIIT</span><a href="#about" className="scroll-link">{reduced ? 'THE GATHERING' : 'SCROLL TO AWAKEN'} <span>↓</span></a><span className="hero-edition">A NEW CHAPTER.<br/>THE SAME FEARLESS SPIRIT.</span></div>
        </div>
        <div className="hero-progress" aria-hidden="true"/>
      </div>
    </section>
    {!systemReduced && <button className="motion-toggle" type="button" aria-label={manualReduced ? 'Enable scroll animation' : 'Show static samurai'} aria-pressed={manualReduced} onClick={() => setManualReduced(value => !value)}><span aria-hidden="true">{manualReduced ? '▷' : 'Ⅱ'}</span></button>}
  </>;
}
createRoot(document.getElementById('hero-root')).render(<Hero />);
