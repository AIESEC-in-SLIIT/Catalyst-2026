import React from 'react';
import source from '../assets/warrior.svg?raw';
const definitions = source.match(/<defs>([\s\S]*?)<\/defs>/)[1];

// All shapes share the same face anchors: eyes (496/604, 366), nose (550, 420).
function Shape({ name, from, to, at, duration = .35, ...props }) {
  return <path data-part={name} data-morph={to} data-at={at} data-duration={duration} d={from} {...props} />;
}
export default function Character() {
  return <svg className="samurai-svg" viewBox="0 0 1100 850" fill="none" role="img" aria-labelledby="samurai-description">
    <title id="samurai-description">A historical Japanese character gradually forms a crescent helmet, fierce face mask, and layered samurai armor.</title>
    <defs dangerouslySetInnerHTML={{ __html: definitions }} />
    <defs>
      <linearGradient id="evolving-face" x1="550" y1="260" x2="550" y2="565" gradientUnits="userSpaceOnUse"><stop offset=".33" stopColor="#c90038"/><stop offset=".7" stopColor="#e97b98"/><stop offset="1" stopColor="#f1eadf"/></linearGradient>
      <linearGradient id="neck-shadow" x1="0" y1="540" x2="0" y2="635" gradientUnits="userSpaceOnUse"><stop stopColor="#c90038"/><stop offset="1" stopColor="#c90038"/></linearGradient>
      <pattern id="armor-weave" width="55" height="135" patternUnits="userSpaceOnUse"><path d="M0 0C0 68 55 68 55 135M55 0C55 68 0 68 0 135" stroke="#f1eadf" strokeWidth="1"/></pattern>
      <clipPath id="horn-growth"><path data-horn-clip d="M550 330Q550 330 550 330L550 330Z"/></clipPath>
      <clipPath id="neck-growth"><ellipse data-neck-clip cx="550" cy="540" rx="3" ry="3"/></clipPath>
      <clipPath id="teeth-growth"><rect data-teeth-clip x="475" y="430" width="150" height="0"/></clipPath>
    </defs>
    <g data-character-root>
    <g data-layer="clothing">
      <Shape name="robe" from="M398 484 255 565 5 760V850H1095V760L845 565 702 484Z" to="M398 510Q155 510 55 680L35 850H1065L1045 680Q945 510 702 510Z" at=".32" duration=".42" fill="#f1eadf"/>
      <g data-robe-flowers clipPath="url(#robe)"><use href="#flower" transform="translate(235 611) scale(1.4)"/><use href="#flower" transform="translate(106 729) scale(1.6)"/><use href="#flower" transform="translate(326 758) scale(1.4)"/><use href="#flower" transform="translate(865 611) scale(1.4)"/><use href="#flower" transform="translate(994 729) scale(1.6)"/><use href="#flower" transform="translate(774 758) scale(1.4)"/></g>
      <Shape name="left-cloth" from="M398 484 284 554 477 850H550L550 686Z" to="M215 541Q101 555 55 680 31 747 35 850H240Z" at=".34" duration=".43" fill="#201b13"/>
      <Shape name="left-weave" from="M398 484 284 554 477 850H550L550 686Z" to="M215 541Q101 555 55 680 31 747 35 850H240Z" at=".34" duration=".43" fill="url(#armor-weave)"/>
