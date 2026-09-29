import React from 'react';
import { cn } from '../ui';

/*
 * Brand mark and wordmark.
 *
 * The old build drew the logo as a three-stop gradient tile (cyan to slate)
 * with a ring and a coloured shadow, next to a wordmark containing a coloured
 * full stop, next to a "PREMIER VAULT" pill. Four competing devices for one
 * piece of identity.
 *
 * This is one flat square holding three ledger rules of decreasing length: the
 * debit, credit, and balance of a statement row. It is drawn inline rather than
 * loaded from the SVG file so it inherits currentColor and stays crisp at any
 * density, and it matches /public/mark.svg used as the favicon.
 */

export function Mark({ className }) {
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center justify-center bg-accent text-fg-inverse',
        className
      )}
      aria-hidden="true"
    >
      <svg viewBox="0 0 32 32" className="h-[62%] w-[62%]" fill="currentColor">
        <rect x="7" y="9" width="18" height="3" />
        <rect x="7" y="15" width="13" height="3" opacity="0.72" />
        <rect x="7" y="21" width="8" height="3" opacity="0.48" />
      </svg>
    </span>
  );
}

/*
 * Wordmark. One weight, one colour, real letterspacing. No coloured full stop,
 * no gradient text, no pill beside it.
 */
export function Wordmark({ size = 'md', className }) {
  return (
    <span
      className={cn(
        'font-semibold tracking-tight text-fg',
        size === 'lg' ? 'text-xl' : 'text-base',
        className
      )}
    >
      AuraBank
    </span>
  );
}

/** Mark plus wordmark, the default lockup used in the header and on login. */
export default function Brand({ size = 'md', className }) {
  const box = size === 'lg' ? 'h-9 w-9' : 'h-7 w-7';

  return (
    <span className={cn('inline-flex items-center gap-2.5', className)}>
      <Mark className={box} />
      <Wordmark size={size} />
    </span>
  );
}
