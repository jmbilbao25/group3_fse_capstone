import React from 'react';
import { cn } from './cn';

/*
 * Table
 *
 * Built for scanning a queue of transactions, which means:
 *
 *   - Hairline row rules, no zebra striping. Stripes fight the status colours
 *     that actually carry meaning in these rows.
 *   - Header is sunken and sticky, so the column meaning survives scrolling.
 *   - Row hover is a background shift only. No lift, no scale, no shadow.
 *   - Amount columns are right-aligned so the decimals stack.
 *
 * The horizontal scroll container is marked focusable and labelled, so a
 * keyboard user can actually reach the overflow on a narrow viewport.
 */

export function TableScroll({ label, className, children }) {
  return (
    <div
      role="region"
      aria-label={label}
      tabIndex={0}
      className={cn('-mx-4 overflow-x-auto', className)}
    >
      {children}
    </div>
  );
}

export function Table({ className, children, ...rest }) {
  return (
    <table className={cn('w-full border-collapse text-left', className)} {...rest}>
      {children}
    </table>
  );
}

export function Th({ align = 'left', className, children, ...rest }) {
  return (
    <th
      scope="col"
      className={cn(
        'whitespace-nowrap border-y border-line bg-sunken px-4 py-2',
        'text-2xs font-medium uppercase tracking-wider text-fg-subtle',
        'first:pl-4 last:pr-4',
        align === 'right' && 'text-right',
        align === 'center' && 'text-center',
        className
      )}
      {...rest}
    >
      {children}
    </th>
  );
}

export function Td({ align = 'left', className, children, ...rest }) {
  return (
    <td
      className={cn(
        'border-b border-line px-4 py-3 align-middle text-sm text-fg',
        align === 'right' && 'text-right',
        align === 'center' && 'text-center',
        className
      )}
      {...rest}
    >
      {children}
    </td>
  );
}

export function Tr({ className, children, ...rest }) {
  return (
    <tr
      className={cn('transition-colors duration-[120ms] hover:bg-sunken', className)}
      {...rest}
    >
      {children}
    </tr>
  );
}
