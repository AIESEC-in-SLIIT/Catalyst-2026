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
      <Shape name="right-cloth" from="M702 484 816 554 623 850H550L550 686Z" to="M885 541Q999 555 1045 680 1069 747 1065 850H860Z" at=".34" duration=".43" fill="#201b13"/>
      <Shape name="right-weave" from="M702 484 816 554 623 850H550L550 686Z" to="M885 541Q999 555 1045 680 1069 747 1065 850H860Z" at=".34" duration=".43" fill="url(#armor-weave)"/>
      <Shape name="collar" from="M418 512 550 691 682 512 641 521 550 623 459 521Z" to="M325 540H775Q766 609 715 635H385Q334 609 325 540Z" at=".38" duration=".32" fill="url(#neck-shadow)"/>
      <g clipPath="url(#neck-growth)">
        <path d="M442 540H658Q683 595 725 609Q697 749 550 754 403 749 375 609 417 595 442 540Z" fill="#f1eadf"/>
        <g stroke="#201b13" strokeWidth="1.2"><path data-neck-line d="M478 540Q491 589 550 588 609 589 622 540"/><path data-neck-line d="M435 552Q453 648 550 646 647 648 665 552"/><path data-neck-line d="M406 584Q432 704 550 703 668 704 694 584"/></g>
      </g>
    </g>
    <g data-layer="head">
      <Shape name="hair" from="M418 366C390 280 420 223 487 198L550 188 613 198C680 223 710 280 682 366L669 371 669 313Q640 301 636 242L550 221 464 242Q460 301 431 313L431 371Z" to="M425 327Q353 366 324 514L420 540 467 495 550 340 633 495 680 540 776 514Q747 366 675 327L550 270Z" at=".12" duration=".36" fill="#201b13"/>
      <Shape name="face" from="M425 271Q550 214 675 271L684 401 657 484 597 565H503L443 484 416 401Z" to="M443 330Q550 330 657 330L671 414Q676 449 641 462L594 475H506L459 462Q424 449 429 414Z" at=".24" duration=".4" fill="url(#evolving-face)"/>
      <path data-face-detail d="M485 262Q550 299 615 262M487 282Q550 315 613 282M440 386Q459 440 514 391M660 386Q641 440 586 391" stroke="#201b13" strokeWidth="1.8"/>
      <Shape name="left-brow" from="M436 320 524 340V358L490 345 436 339Z" to="M447 343Q479 332 522 352L530 376Q528 391 510 390H499Q487 407 467 400 448 397 449 379Z" at=".25" duration=".35" fill="#201b13"/>
