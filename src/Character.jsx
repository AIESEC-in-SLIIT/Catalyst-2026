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
