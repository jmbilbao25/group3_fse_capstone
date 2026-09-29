import React from 'react';
import { cn } from './cn';

/*
 * Empty, loading, and inline-message states.
 *
 * These are designed, not bolted on. The old build's empty state was a big
 * green tick and the sentence "No high-value transactions are currently held in
 * PENDING_APPROVAL", which leaks an enum at the user. An empty queue in this
 * product is good news and should read that way, and it should tell the user
 * what will cause something to appear here.
 */

export function EmptyState({ icon: Icon, title, description, action, className }) {
  return (
    <div className={cn('flex flex-col items-center px-6 py-14 text-center', className)}>
      {Icon && (
        <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-md border border-line bg-sunken text-fg-subtle">
          <Icon className="h-4 w-4" aria-hidden="true" />
        </div>
      )}
      <p className="text-sm font-medium text-fg">{title}</p>
      {description && (
        <p className="mt-1 max-w-sm text-sm text-fg-muted">{description}</p>
      )}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}

/*
 * Callout: an inline message attached to a specific decision or form.
 *
 * `role` defaults to status so it is announced politely. Errors that block an
 * action pass role="alert" to interrupt. Tone is never the only signal: every
 * callout carries a title that states the situation in words.
 */
const CALLOUT_TONES = {
  neutral: 'border-line bg-sunken text-fg-muted',
  accent: 'border-accent-line bg-accent-soft text-accent-text',
  settled: 'border-settled-200 bg-settled-50 text-settled-700',
  held: 'border-held-200 bg-held-50 text-held-700',
  voided: 'border-voided-200 bg-voided-50 text-voided-700',
};

export function Callout({
  tone = 'neutral',
  icon: Icon,
  title,
  role = 'status',
  action,
  className,
  children,
}) {
  return (
    <div
      role={role}
      className={cn(
        'flex items-start gap-2.5 rounded-md border px-3 py-2.5 text-sm',
        CALLOUT_TONES[tone],
        className
      )}
    >
      {Icon && <Icon className="mt-px h-4 w-4 shrink-0" aria-hidden="true" />}
      <div className="min-w-0 flex-1">
        {title && <p className="font-medium">{title}</p>}
        {children && <div className={cn(title && 'mt-0.5', 'opacity-90')}>{children}</div>}
      </div>
      {action && <div className="shrink-0">{action}</div>}
    </div>
  );
}

/*
 * Skeleton. Shaped like the content it replaces so nothing reflows on arrival.
 * Used instead of a centred spinner for anything that occupies layout.
 */
export function Skeleton({ className }) {
  return <div className={cn('skeleton h-4 w-full', className)} aria-hidden="true" />;
}

/** Placeholder rows for a table that is still loading. */
export function SkeletonRows({ rows = 3, cols = 4 }) {
  return (
    <>
      {Array.from({ length: rows }).map((_, r) => (
        <tr key={r}>
          {Array.from({ length: cols }).map((__, c) => (
            <td key={c} className="border-b border-line px-4 py-3">
              <Skeleton className={c === 0 ? 'w-24' : c === cols - 1 ? 'w-16' : 'w-32'} />
            </td>
          ))}
        </tr>
      ))}
    </>
  );
}
