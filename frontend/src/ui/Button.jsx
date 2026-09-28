import React from 'react';
import { cn } from './cn';

/*
 * Button
 *
 * Every variant is contrast-checked against the surface it is allowed to sit
 * on, so there is no path to the white-label-on-white-fill failure. `danger`
 * and `approve` exist because authorising and voiding a balance mutation are
 * irreversible and must not look like ordinary buttons.
 */

const VARIANTS = {
  // Filled cobalt. White on accent-600 is 6.4:1.
  primary:
    'bg-accent text-fg-inverse border border-transparent hover:bg-accent-hover shadow-xs',

  // The default for most actions. Reads as a control, not as a call to action.
  secondary:
    'bg-surface text-fg border border-line-strong hover:bg-sunken shadow-xs',

  // No container until interacted with. For tertiary and icon actions.
  ghost:
    'bg-transparent text-fg-muted border border-transparent hover:bg-sunken hover:text-fg',

  // Authorising a transfer settles real money. It gets its own weight.
  approve:
    'bg-settled-600 text-white border border-transparent hover:bg-settled-700 shadow-xs',

  // Voiding a transfer. Outlined rather than filled, so it cannot be hit
  // reflexively the way a solid red button invites.
  danger:
    'bg-surface text-voided-600 border border-voided-200 hover:bg-voided-50 hover:border-voided-400',
};

const SIZES = {
  sm: 'h-7 px-2.5 text-xs gap-1.5 rounded',
  md: 'h-8 px-3 text-sm gap-1.5 rounded-md',
  lg: 'h-10 px-4 text-base gap-2 rounded-md',
};

const ICON_SIZES = {
  sm: 'h-7 w-7 rounded',
  md: 'h-8 w-8 rounded-md',
  lg: 'h-10 w-10 rounded-md',
};

const Button = React.forwardRef(function Button(
  {
    as: Tag = 'button',
    variant = 'secondary',
    size = 'md',
    icon: Icon,
    iconOnly = false,
    loading = false,
    disabled = false,
    fullWidth = false,
    className,
    children,
    ...rest
  },
  ref
) {
  const isDisabled = disabled || loading;

  return (
    <Tag
      ref={ref}
      disabled={Tag === 'button' ? isDisabled : undefined}
      aria-busy={loading || undefined}
      aria-disabled={Tag !== 'button' && isDisabled ? true : undefined}
      className={cn(
        'inline-flex shrink-0 items-center justify-center font-medium',
        // 120ms is fast enough to feel mechanical rather than animated.
        'transition-colors duration-[120ms]',
        // Tactile press. Translate rather than scale, so text stays crisp.
        'active:translate-y-px',
        'disabled:pointer-events-none disabled:opacity-45',
        'aria-disabled:pointer-events-none aria-disabled:opacity-45',
        VARIANTS[variant],
        iconOnly ? ICON_SIZES[size] : SIZES[size],
        fullWidth && 'w-full',
        className
      )}
      {...rest}
    >
      {loading ? (
        <Spinner size={size} />
      ) : (
        Icon && <Icon className={size === 'lg' ? 'h-4 w-4' : 'h-3.5 w-3.5'} aria-hidden="true" />
      )}
      {!iconOnly && children}
    </Tag>
  );
});

/*
 * The one exception to the no-spinners rule. A button that has already been
 * pressed needs to say "still working" in place, and a skeleton cannot do that
 * inside a 32px control. It inherits currentColor so it reads on every variant.
 */
function Spinner({ size }) {
  return (
    <svg
      className={cn('animate-spin', size === 'lg' ? 'h-4 w-4' : 'h-3.5 w-3.5')}
      viewBox="0 0 16 16"
      fill="none"
      aria-hidden="true"
    >
      <circle cx="8" cy="8" r="6.5" stroke="currentColor" strokeOpacity="0.25" strokeWidth="2" />
      <path
        d="M14.5 8A6.5 6.5 0 0 0 8 1.5"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  );
}

export default Button;
