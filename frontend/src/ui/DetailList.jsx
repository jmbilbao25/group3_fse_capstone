import React from 'react';
import { cn } from './cn';

/*
 * DetailList
 *
 * Label/value pairs for receipts, transfer dossiers, and KYC records. A real
 * <dl>, so the relationship between a label and its value is in the markup
 * rather than implied by position.
 *
 * Rows are separated by hairlines and the value is right-aligned, which is what
 * lets the eye run down a receipt and compare figures. The old build rendered
 * each pair as its own bordered box with a tinted fill, which turned a 10-line
 * receipt into 10 competing objects.
 */
export function DetailList({ className, children }) {
  return <dl className={cn('divide-y divide-line', className)}>{children}</dl>;
}

export function Detail({
  label,
  /** Renders the value in mono for IDs, account numbers, and hashes. */
  mono = false,
  /** Emphasises the row, e.g. the total on a receipt. */
  strong = false,
  hint,
  className,
  children,
}) {
  return (
    <div className={cn('flex items-baseline justify-between gap-6 py-2.5', className)}>
      <dt className="shrink-0 text-sm text-fg-muted">
        {label}
        {hint && <span className="mt-0.5 block text-xs text-fg-subtle">{hint}</span>}
      </dt>
      <dd
        className={cn(
          'min-w-0 text-right text-sm',
          mono && 'font-mono tabular-nums',
          strong ? 'font-semibold text-fg' : 'text-fg'
        )}
      >
        {children}
      </dd>
    </div>
  );
}
