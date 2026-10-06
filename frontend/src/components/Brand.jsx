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
        'inline-flex shrink-0 items-center justify-center rounded-xl bg-[#311075] text-white shadow-xs',
        className
      )}
      aria-hidden="true"
    >
      <span className="font-bold text-sm tracking-tight flex flex-col items-center leading-none select-none">
        <span className="leading-none">A</span>
        <span className="w-2.5 h-[1.5px] bg-white mt-[1px] rounded-full" />
      </span>
    </span>
  );
}

/*
 * Wordmark: "Aura Bank" matching mobile/web client branding
 */
export function Wordmark({ size = 'md', className }) {
  return (
    <span
      className={cn(
        'font-bold tracking-tight text-fg font-sans',
        size === 'lg' ? 'text-xl' : 'text-base',
        className
      )}
    >
      Aura Bank
    </span>
  );
}

/** Mark plus wordmark, the default lockup used in the header and on login. */
export default function Brand({ size = 'md', className }) {
  const box = size === 'lg' ? 'h-9 w-9' : 'h-8 w-8';

  return (
    <span className={cn('inline-flex items-center gap-2.5', className)}>
      <Mark className={box} />
      <Wordmark size={size} />
    </span>
  );
}
