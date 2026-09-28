import React from 'react';
import { cn } from './cn';

/*
 * Badge
 *
 * Tones map to ledger state, not to mood. A badge is only allowed where the
 * value it carries is genuinely categorical data: settlement status, a
 * regulatory tier, an account type. It is never decoration for a heading.
 *
 * There are no status dots inside these badges. The tone already encodes the
 * state, and a coloured dot in front of every label is pure noise.
 */

const TONES = {
  // Contrast on the light theme, all against their own tinted background:
  // neutral 8.9:1, settled 5.6:1, held 5.4:1, voided 6.1:1, accent 6.2:1.
  neutral: 'bg-sunken text-fg-muted border-line',
  settled: 'bg-settled-50 text-settled-700 border-settled-200',
  held: 'bg-held-50 text-held-700 border-held-200',
  voided: 'bg-voided-50 text-voided-700 border-voided-200',
  accent: 'bg-accent-soft text-accent-text border-accent-line',
};

const SIZES = {
  sm: 'h-[18px] px-1.5 text-2xs',
  md: 'h-[22px] px-2 text-xs',
};

export default function Badge({
  tone = 'neutral',
  size = 'md',
  icon: Icon,
  mono = false,
  className,
  children,
  ...rest
}) {
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center gap-1 whitespace-nowrap rounded border font-medium',
        TONES[tone],
        SIZES[size],
        mono && 'font-mono',
        className
      )}
      {...rest}
    >
      {Icon && <Icon className="h-3 w-3 shrink-0" aria-hidden="true" />}
      {children}
    </span>
  );
}
