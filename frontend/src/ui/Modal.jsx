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
