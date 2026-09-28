import React from 'react';
import { AlertCircle } from 'lucide-react';
import { cn } from './cn';

/*
 * Field: label above the control, helper below it, error below that.
 *
 * The error is wired to the input through aria-describedby so it is announced
 * rather than merely displayed. No placeholder-as-label anywhere.
 *
 * The old build labelled inputs with 11px uppercase bold text and hinted them
 * through the placeholder, which fails both legibility and screen readers.
 * Labels here are 13px sentence case, which is what a person actually reads.
 */

let seq = 0;
const nextId = () => `fld-${++seq}`;

export function Field({
  label,
  htmlFor,
  hint,
  error,
  required = false,
  /** Right-aligned affordance in the label row, e.g. a "Use max" shortcut. */
  action,
  className,
  children,
}) {
  const auto = React.useMemo(nextId, []);
  const id = htmlFor || auto;
  const hintId = hint ? `${id}-hint` : undefined;
  const errorId = error ? `${id}-error` : undefined;

  return (
    <div className={cn('space-y-1.5', className)}>
      <div className="flex items-baseline justify-between gap-3">
        <label htmlFor={id} className="text-sm font-medium text-fg">
          {label}
          {required && (
            <span className="ml-0.5 text-voided-600" aria-hidden="true">
              *
            </span>
          )}
        </label>
        {action}
      </div>

      {React.isValidElement(children)
        ? React.cloneElement(children, {
            id,
            'aria-invalid': error ? true : undefined,
            'aria-describedby': cn(errorId, hintId) || undefined,
            'aria-required': required || undefined,
          })
        : children}

      {hint && !error && (
        <p id={hintId} className="text-xs text-fg-subtle">
          {hint}
        </p>
      )}

      {error && (
        <p
          id={errorId}
          role="alert"
          className="flex items-start gap-1.5 text-xs font-medium text-voided-600"
        >
          <AlertCircle className="mt-px h-3.5 w-3.5 shrink-0" aria-hidden="true" />
          <span>{error}</span>
        </p>
      )}
    </div>
  );
}

/*
 * Control surfaces. A field reads as inset (sunken fill, hairline border) and
 * becomes the active surface on focus. aria-invalid drives the error styling,
 * so the visual state cannot drift from the announced state.
 */
const CONTROL = [
  'w-full bg-sunken text-fg border border-line rounded-md',
  'text-sm placeholder:text-fg-subtle',
  'transition-[background-color,border-color] duration-[120ms]',
  'hover:border-line-strong',
  'focus:bg-surface focus:border-accent',
  'disabled:cursor-not-allowed disabled:opacity-55',
  'aria-[invalid=true]:border-voided-400 aria-[invalid=true]:bg-voided-50',
].join(' ');

const SIZES = {
  md: 'h-9 px-2.5',
  lg: 'h-11 px-3 text-base',
};

export const Input = React.forwardRef(function Input(
  { size = 'md', icon: Icon, mono = false, className, ...rest },
  ref
) {
  const input = (
    <input
      ref={ref}
      className={cn(
        CONTROL,
        SIZES[size],
        mono && 'font-mono tabular-nums',
        Icon && 'pl-9',
        className
      )}
      {...rest}
    />
  );

  if (!Icon) return input;

  return (
    <div className="relative">
      <Icon
        className="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-fg-subtle"
        aria-hidden="true"
      />
      {input}
    </div>
  );
});

export const Textarea = React.forwardRef(function Textarea({ className, rows = 3, ...rest }, ref) {
  return (
    <textarea
      ref={ref}
      rows={rows}
      className={cn(CONTROL, 'resize-y px-2.5 py-2 leading-relaxed', className)}
      {...rest}
    />
  );
});

export const Select = React.forwardRef(function Select({ size = 'md', className, ...rest }, ref) {
  return (
    <select
      ref={ref}
      /* Native chevron is suppressed in favour of one that matches the token
         colours; appearance-none plus a background SVG keeps it themeable. */
      className={cn(CONTROL, SIZES[size], 'cursor-pointer appearance-none pr-8', className)}
      style={{
        backgroundImage:
          "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12' fill='none' stroke='%236F7680' stroke-width='1.5' stroke-linecap='round'%3E%3Cpath d='M3 4.5 6 7.5 9 4.5'/%3E%3C/svg%3E\")",
        backgroundRepeat: 'no-repeat',
        backgroundPosition: 'right 0.625rem center',
      }}
      {...rest}
    />
  );
});
