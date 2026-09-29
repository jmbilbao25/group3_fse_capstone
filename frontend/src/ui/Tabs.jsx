import React from 'react';
import { cn } from './cn';

/*
 * Tabs
 *
 * Underline rather than filled pills. The old build used a solid cobalt pill for
 * the active tab, which gave a navigation control the same visual weight as the
 * primary submit button on the same screen, so nothing read as the main action.
 * An underline marks position without competing.
 *
 * Full ARIA tab semantics with arrow-key navigation, because this is the
 * primary navigation for the customer portal.
 */
export function Tabs({ tabs, value, onChange, label, className }) {
  const refs = React.useRef([]);

  const onKeyDown = (event) => {
    const current = tabs.findIndex((t) => t.id === value);
    let next = null;

    if (event.key === 'ArrowRight') next = (current + 1) % tabs.length;
    if (event.key === 'ArrowLeft') next = (current - 1 + tabs.length) % tabs.length;
    if (event.key === 'Home') next = 0;
    if (event.key === 'End') next = tabs.length - 1;

    if (next === null) return;
    event.preventDefault();
    onChange(tabs[next].id);
    refs.current[next]?.focus();
  };

  return (
    <div
      role="tablist"
      aria-label={label}
      onKeyDown={onKeyDown}
      className={cn('-mb-px flex items-center gap-1 overflow-x-auto', className)}
    >
      {tabs.map((tab, i) => {
        const active = tab.id === value;
        const Icon = tab.icon;

        return (
          <button
            key={tab.id}
            ref={(node) => (refs.current[i] = node)}
            role="tab"
            type="button"
            id={`tab-${tab.id}`}
            aria-selected={active}
            aria-controls={`panel-${tab.id}`}
            /* Only the active tab is in the tab order; arrows move between
               them. This is the expected pattern for a tablist. */
            tabIndex={active ? 0 : -1}
            onClick={() => onChange(tab.id)}
            className={cn(
              'relative flex shrink-0 items-center gap-1.5 whitespace-nowrap px-3 py-2.5',
              'text-sm font-medium transition-colors duration-[120ms]',
              'border-b-2 -mb-px',
              active
                ? 'border-accent text-fg'
                : 'border-transparent text-fg-muted hover:border-line-strong hover:text-fg'
            )}
          >
            {Icon && <Icon className="h-3.5 w-3.5" aria-hidden="true" />}
            {tab.label}
            {tab.count > 0 && (
              <span
                className={cn(
                  'ml-0.5 rounded-full px-1.5 py-px text-2xs font-medium tabular-nums',
                  active ? 'bg-accent-soft text-accent-text' : 'bg-sunken text-fg-subtle'
                )}
              >
                {tab.count}
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}

export function TabPanel({ id, active, className, children }) {
  if (!active) return null;

  return (
    <div
      role="tabpanel"
      id={`panel-${id}`}
      aria-labelledby={`tab-${id}`}
      tabIndex={0}
      className={cn('animate-fade-in focus-visible:outline-none', className)}
    >
      {children}
    </div>
  );
}
