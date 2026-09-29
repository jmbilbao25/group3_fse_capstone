import React from 'react';
import { AlertCircle, CheckCircle2, Info, X } from 'lucide-react';
import Button from '../ui/Button';
import { cn } from '../ui';

/*
 * Toast: the response to something the user just did.
 *
 * The previous version rendered a near-black panel with neon text on a light
 * page, which is the theme break that made the whole app look assembled from
 * parts. This uses the same surface tokens as everything else and marks tone
 * with a 2px left rule plus an icon, so the state survives greyscale.
 *
 * aria-live="polite" with role="status" means the message is announced without
 * interrupting, and the tone never carries meaning on its own: every toast has
 * a title that says what happened in words.
 */

const TONES = {
  success: { icon: CheckCircle2, rule: 'bg-settled-600', iconColor: 'text-settled-600' },
  error: { icon: AlertCircle, rule: 'bg-voided-600', iconColor: 'text-voided-600' },
  warning: { icon: Info, rule: 'bg-held-600', iconColor: 'text-held-600' },
  info: { icon: Info, rule: 'bg-accent', iconColor: 'text-accent-text' },
};

export default function Toast({ toast, onClose }) {
  if (!toast) return null;

  const tone = TONES[toast.type] || TONES.info;
  const Icon = tone.icon;

  return (
    <div
      className="pointer-events-none fixed inset-x-4 bottom-4 z-50 flex justify-end sm:inset-x-auto sm:right-6 sm:bottom-6"
      role="status"
      aria-live="polite"
    >
      <div
        className={cn(
          'pointer-events-auto relative flex w-full max-w-sm animate-fade-up items-start gap-2.5',
          'border border-line bg-surface py-3 pl-4 pr-2.5 shadow-lg'
        )}
      >
        {/* Tone rule. Redundant with the icon on purpose: colour is never the
            only carrier of state. */}
        <span className={cn('absolute inset-y-0 left-0 w-[2px]', tone.rule)} aria-hidden="true" />

        <Icon className={cn('mt-px h-4 w-4 shrink-0', tone.iconColor)} aria-hidden="true" />

        <div className="min-w-0 flex-1">
          <p className="text-sm font-medium text-fg">{toast.title}</p>
          {toast.detail && (
            <p className="mt-0.5 text-sm leading-snug text-fg-muted">{toast.detail}</p>
          )}
          {/* The API surfaces an RFC 7807 problem instance on failures. Kept,
              because it is the only handle support has on a failed mutation,
              but demoted so it does not compete with the message. */}
          {toast.rfcInstance && (
            <p className="mt-1.5 truncate font-mono text-2xs text-fg-subtle" title={toast.rfcInstance}>
              {toast.rfcInstance}
            </p>
          )}
        </div>

        <Button
          variant="ghost"
          size="sm"
          iconOnly
          icon={X}
          onClick={onClose}
          aria-label="Dismiss notification"
        />
      </div>
    </div>
  );
}
