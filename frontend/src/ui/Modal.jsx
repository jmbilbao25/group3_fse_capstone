import React from 'react';
import { X } from 'lucide-react';
import { cn } from './cn';
import Button from './Button';

/*
 * Modal
 *
 * The old build's dialogs had a decorative gradient bar across the top, closed
 * only on backdrop click, and trapped nothing. These are the dialogs where a
 * user authorises a six-figure transfer, so they behave properly:
 *
 *   - Escape closes, and focus returns to whatever opened the dialog.
 *   - Focus is trapped inside while open, cycling on Tab and Shift+Tab.
 *   - Background scroll is locked, so the page behind cannot drift.
 *   - role/aria-modal/aria-labelledby are wired to the real heading.
 *
 * Deliberately not a portal: the app has a single stacking root and no
 * transformed ancestors, so a fixed overlay rendered in place is correct and
 * avoids a second React tree.
 */

const WIDTHS = {
  sm: 'max-w-sm',
  md: 'max-w-lg',
  lg: 'max-w-2xl',
  xl: 'max-w-4xl',
};

const FOCUSABLE =
  'a[href],button:not([disabled]),input:not([disabled]),select:not([disabled]),textarea:not([disabled]),[tabindex]:not([tabindex="-1"])';

export default function Modal({
  open,
  onClose,
  title,
  description,
  size = 'md',
  /** Sticky action row pinned to the bottom of the dialog. */
  footer,
  /** Set false for dialogs that must be dismissed via an explicit choice. */
  dismissible = true,
  className,
  children,
}) {
  const panelRef = React.useRef(null);
  const headingId = React.useId();
  const descriptionId = React.useId();
  // Remember what had focus so it can be handed back on close. Losing focus
  // to the top of the document after closing a dialog is a real keyboard bug.
  const restoreRef = React.useRef(null);

  React.useEffect(() => {
    if (!open) return;

    restoreRef.current = document.activeElement;

    // Move focus into the dialog, preferring the first real control over the
    // close button so the primary path is the default.
    const node = panelRef.current;
    const first = node?.querySelector(FOCUSABLE);
    (first || node)?.focus({ preventScroll: true });

    return () => {
      const target = restoreRef.current;
      if (target instanceof HTMLElement && document.contains(target)) {
        target.focus({ preventScroll: true });
      }
    };
  }, [open]);

  // Scroll lock. Compensating for the scrollbar width prevents the layout
  // shift you normally get behind a modal.
  React.useEffect(() => {
    if (!open) return;
    const { body, documentElement } = document;
    const gap = window.innerWidth - documentElement.clientWidth;
    const prevOverflow = body.style.overflow;
    const prevPadding = body.style.paddingRight;

    body.style.overflow = 'hidden';
    if (gap > 0) body.style.paddingRight = `${gap}px`;

    return () => {
      body.style.overflow = prevOverflow;
      body.style.paddingRight = prevPadding;
    };
  }, [open]);

  // Escape to close, Tab to cycle within the dialog.
  React.useEffect(() => {
    if (!open) return;

    const onKeyDown = (event) => {
      if (event.key === 'Escape' && dismissible) {
        event.stopPropagation();
        onClose?.();
        return;
      }

      if (event.key !== 'Tab') return;

      const nodes = Array.from(panelRef.current?.querySelectorAll(FOCUSABLE) || []);
      if (nodes.length === 0) return;

      const first = nodes[0];
      const last = nodes[nodes.length - 1];

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener('keydown', onKeyDown, true);
    return () => document.removeEventListener('keydown', onKeyDown, true);
  }, [open, dismissible, onClose]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto p-4 sm:items-center sm:p-6"
      role="presentation"
    >
      {/* Scrim. Neutral-tinted rather than pure black, and only lightly
          blurred: heavy blur on a dense table behind is nauseating. */}
      <div
        className="fixed inset-0 animate-fade-in bg-ink-950/45 backdrop-blur-[2px]"
        onClick={dismissible ? onClose : undefined}
        aria-hidden="true"
      />

      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={title ? headingId : undefined}
        aria-describedby={description ? descriptionId : undefined}
        tabIndex={-1}
        className={cn(
          'relative z-10 my-auto w-full animate-scale-in',
          'rounded-xl border border-line bg-surface shadow-xl',
          'flex max-h-[calc(100vh-2rem)] flex-col',
          WIDTHS[size],
          className
        )}
      >
        {(title || dismissible) && (
          <header className="flex items-start justify-between gap-4 border-b border-line px-5 py-4">
            <div className="min-w-0">
              {title && (
                <h2 id={headingId} className="text-md font-semibold text-fg">
                  {title}
                </h2>
              )}
              {description && (
                <p id={descriptionId} className="mt-1 text-sm text-fg-muted">
                  {description}
                </p>
              )}
            </div>

            {dismissible && (
              <Button
                variant="ghost"
                size="sm"
                iconOnly
                icon={X}
                onClick={onClose}
                aria-label="Close dialog"
                className="-mr-1 -mt-0.5"
              />
            )}
          </header>
        )}

        <div className="min-h-0 flex-1 overflow-y-auto px-5 py-4">{children}</div>

        {footer && (
          <footer className="flex flex-col-reverse gap-2 border-t border-line bg-sunken px-5 py-3.5 sm:flex-row sm:justify-end">
            {footer}
          </footer>
        )}
      </div>
    </div>
  );
}
