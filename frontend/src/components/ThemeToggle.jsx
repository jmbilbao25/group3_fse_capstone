import React from 'react';
import { Monitor, Moon, Sun } from 'lucide-react';
import { useTheme } from '../context/ThemeContext';
import { cn } from '../ui';

/*
 * Theme control. Three explicit states rather than a two-state switch, because
 * "follow my system" is a real preference and a binary toggle silently discards
 * it the first time the user touches the control.
 *
 * Built as a radiogroup: the options are mutually exclusive and all three are
 * visible, so there is no guessing what a single icon button will do next.
 */

const OPTIONS = [
  { value: 'light', label: 'Light', icon: Sun },
  { value: 'dark', label: 'Dark', icon: Moon },
  { value: 'system', label: 'System', icon: Monitor },
];

export default function ThemeToggle({ className }) {
  const { preference, setTheme } = useTheme();

  return (
    <div
      role="radiogroup"
      aria-label="Colour theme"
      className={cn('inline-flex border border-line bg-sunken p-0.5', className)}
    >
      {OPTIONS.map(({ value, label, icon: Icon }) => {
        const active = preference === value;

        return (
          <button
            key={value}
            type="button"
            role="radio"
            aria-checked={active}
            aria-label={label}
            title={label}
            onClick={() => setTheme(value)}
            className={cn(
              'flex h-6 w-6 items-center justify-center transition-colors duration-[120ms]',
              active
                ? 'bg-surface text-fg shadow-xs'
                : 'text-fg-subtle hover:text-fg'
            )}
          >
            <Icon className="h-3.5 w-3.5" aria-hidden="true" />
          </button>
        );
      })}
    </div>
  );
}
