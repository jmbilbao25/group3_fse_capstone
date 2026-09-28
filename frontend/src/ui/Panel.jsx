import React from 'react';
import { cn } from './cn';

/*
 * Panel: the single container in the system. Flat, hairline-bounded, no
 * gradient, no pillow radius.
 *
 * Panels do not nest. If content inside a panel needs separation it gets a
 * divide rule or a PanelSection, never a second bordered box. Card-in-card is
 * the fastest way to make a dense console unreadable.
 */
export function Panel({ as: Tag = 'section', flush = false, className, children, ...rest }) {
  return (
    <Tag
      className={cn('bg-surface border border-line rounded-lg', !flush && 'p-4', className)}
      {...rest}
    >
      {children}
    </Tag>
  );
}

/*
 * PanelHeader: title, optional supporting line, optional trailing controls.
 *
 * There is no eyebrow slot, on purpose. A panel's position in the page already
 * says what it is, and a small uppercase label above every single heading is
 * the most recognisable tell in generated interfaces.
 */
export function PanelHeader({ title, description, actions, className, children }) {
  return (
    <div
      className={cn(
        'flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between',
        className
      )}
    >
      <div className="min-w-0">
        {title && <h2 className="text-md font-semibold text-fg">{title}</h2>}
        {description && (
          <p className="mt-0.5 text-sm text-fg-muted max-w-prose">{description}</p>
        )}
        {children}
      </div>
      {actions && <div className="flex shrink-0 items-center gap-2">{actions}</div>}
    </div>
  );
}

/*
 * A horizontal rule that spans the panel's full width, cancelling the panel's
 * own padding. Used to separate a header from its body without the visual
 * weight of a nested container.
 */
export function PanelRule({ className }) {
  return <hr className={cn('-mx-4 my-4 border-t border-line', className)} />;
}

/*
 * A full-bleed footer strip. Sunken rather than bordered, so it reads as the
 * base of the panel instead of a separate object stacked underneath it.
 */
export function PanelFooter({ className, children }) {
  return (
    <div
      className={cn(
        '-mx-4 -mb-4 mt-4 rounded-b-lg border-t border-line bg-sunken px-4 py-3',
        className
      )}
    >
      {children}
    </div>
  );
}
