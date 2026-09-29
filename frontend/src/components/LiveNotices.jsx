import React from 'react';
import { ArrowDownLeft, Bell, CheckCircle2, X } from 'lucide-react';
import Money from '../ui/Money';
import Button from '../ui/Button';
import { cn } from '../ui';

/*
 * Live settlement notices from the server-sent event stream.
 *
 * Kept separate from Toast because the two are genuinely different things and
 * the old build stacked them in the same corner with different shapes. A toast
 * is feedback for an action the user just took. A notice is unsolicited news
 * arriving from the ledger, which is why it is timestamped and shows the amount.
 *
 * Stacked bottom-left so the two channels never overlap: toasts own the right.
 */

const TONES = {
  success: { icon: CheckCircle2, rule: 'bg-settled-600', color: 'text-settled-600' },
  info: { icon: Bell, rule: 'bg-accent', color: 'text-accent-text' },
  credit: { icon: ArrowDownLeft, rule: 'bg-settled-600', color: 'text-settled-600' },
};

export default function LiveNotices({ notices, onDismiss }) {
  if (!notices?.length) return null;

  return (
    <div
      className="pointer-events-none fixed bottom-4 left-4 z-40 hidden w-80 flex-col gap-2 sm:flex sm:bottom-6 sm:left-6"
      aria-live="polite"
      aria-label="Account notices"
    >
      {notices.map((notice) => {
        const tone = TONES[notice.type] || TONES.info;
        const Icon = tone.icon;

        return (
          <article
            key={notice.id}
            className="pointer-events-auto relative flex animate-slide-in-right items-start gap-2.5 border border-line bg-surface py-2.5 pl-3.5 pr-1.5 shadow-md"
          >
            <span className={cn('absolute inset-y-0 left-0 w-[2px]', tone.rule)} aria-hidden="true" />
            <Icon className={cn('mt-0.5 h-3.5 w-3.5 shrink-0', tone.color)} aria-hidden="true" />

            <div className="min-w-0 flex-1">
              <div className="flex items-baseline justify-between gap-2">
                <p className="truncate text-sm font-medium text-fg">{notice.title}</p>
                <time
                  className="shrink-0 font-mono text-2xs text-fg-subtle"
                  dateTime={notice.at?.toISOString?.()}
                >
                  {notice.at?.toLocaleTimeString?.([], { hour: '2-digit', minute: '2-digit' })}
                </time>
              </div>
              <p className="mt-0.5 text-xs leading-snug text-fg-muted">{notice.message}</p>
              {notice.amount != null && (
                <Money value={notice.amount} size="sm" tone="credit" direction="credit" className="mt-1" />
              )}
            </div>

            <Button
              variant="ghost"
              size="sm"
              iconOnly
              icon={X}
              onClick={() => onDismiss(notice.id)}
              aria-label={`Dismiss notice: ${notice.title}`}
            />
          </article>
        );
      })}
    </div>
  );
}
