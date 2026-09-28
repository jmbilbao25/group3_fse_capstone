/**
 * Minimal class-name joiner.
 *
 * Deliberately not `clsx` + `tailwind-merge`: this product has no conflicting
 * utility overrides to resolve, because variant styles are defined as complete
 * mutually exclusive strings rather than layered partial overrides. Adding two
 * dependencies to solve a problem the component API avoids is the wrong trade.
 */
export function cn(...parts) {
  return parts.filter(Boolean).join(' ');
}
