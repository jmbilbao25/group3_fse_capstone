import React from 'react';
import { cn } from './cn';

/*
 * Money
 *
 * The thesis of this redesign: in a ledger product the figure is the interface.
 * The old build set balances at 14px and section decoration at 30px, which is
 * backwards. Here the amount is the largest, most precise thing on screen and
 * everything else recedes to support it.
 *
 * Three details that make a figure read as financial rather than as text:
 *
 *   1. Tabular figures, so a column of amounts aligns on the decimal and the
 *      eye can compare magnitudes without reading digits.
 *   2. The currency symbol and the centavos are set one step down and muted.
 *      The pesos carry the meaning, the centavos are a legal requirement, and
 *      rendering them at equal weight makes every number look longer than it is.
 *   3. Sign as a leading glyph on debits and credits, never colour alone,
 *      because direction must survive a monochrome print and colour blindness.
 */

const SIZES = {
  xs: { peso: 'text-xs', unit: 'text-2xs', frac: 'text-2xs' },
  sm: { peso: 'text-sm', unit: 'text-2xs', frac: 'text-2xs' },
  md: { peso: 'text-base', unit: 'text-xs', frac: 'text-xs' },
  lg: { peso: 'text-xl', unit: 'text-sm', frac: 'text-sm' },
  xl: { peso: 'text-3xl', unit: 'text-lg', frac: 'text-lg' },
  display: { peso: 'text-4xl', unit: 'text-xl', frac: 'text-xl' },
};

const TONES = {
  default: 'text-fg',
  muted: 'text-fg-muted',
  credit: 'text-settled-600',
  debit: 'text-fg',
  held: 'text-held-600',
};

/** Splits a number into grouped pesos and fixed-width centavos. */
function split(value, decimals) {
  const num = typeof value === 'string' ? parseFloat(value) : value;
  const safe = Number.isFinite(num) ? Math.abs(num) : 0;
  const [pesos, centavos] = safe.toFixed(decimals).split('.');
  return {
    pesos: pesos.replace(/\B(?=(\d{3})+(?!\d))/g, ','),
    centavos,
    negative: Number.isFinite(num) && num < 0,
  };
}

export default function Money({
  value,
  size = 'md',
  tone = 'default',
  decimals = 2,
  /** 'credit' | 'debit' | null. Renders a leading sign glyph, not just colour. */
  direction = null,
  /** Masks the digits for the privacy toggle while keeping the layout stable. */
  hidden = false,
  className,
  ...rest
}) {
  const scale = SIZES[size] || SIZES.md;
  const { pesos, centavos, negative } = split(value, decimals);

  const sign =
    direction === 'credit' ? '+' : direction === 'debit' || negative ? '\u2212' : null;

  if (hidden) {
    return (
      <span
        className={cn('font-mono tabular-nums tracking-tight', scale.peso, TONES.muted, className)}
        // The real value never reaches the DOM while masked.
        aria-label="Amount hidden"
        {...rest}
      >
        {'\u2022'.repeat(7)}
      </span>
    );
  }

  return (
    <span
      className={cn(
        'inline-flex items-baseline gap-[0.15em] whitespace-nowrap font-mono tabular-nums tracking-tight',
        TONES[tone] || TONES.default,
        className
      )}
      {...rest}
    >
      {sign && (
        <span className={cn(scale.unit, 'font-medium')} aria-hidden="true">
          {sign}
        </span>
      )}
      {/* The peso sign is a unit, not a digit, so it sits one step down. */}
      <span className={cn(scale.unit, 'text-fg-subtle')} aria-hidden="true">
        &#8369;
      </span>
      <span className={cn(scale.peso, 'font-medium')}>{pesos}</span>
      <span className={cn(scale.frac, 'text-fg-subtle')}>.{centavos}</span>
      {/* Screen readers get one clean spoken amount instead of the fragments. */}
      <span className="sr-only">
        {sign === '+' ? 'credit ' : sign ? 'debit ' : ''}
        {pesos}.{centavos} pesos
      </span>
    </span>
  );
}
