/*
 * Ledger vocabulary.
 *
 * The old build repeated the same status-to-colour ternary in six files, which
 * is why SETTLED was emerald in one place and green-400 in another, and why
 * "Tier 2" was amber on one screen and indigo on the next. One mapping, one
 * label per state, used everywhere.
 *
 * Labels here are customer-readable. The raw enum stays available for staff
 * surfaces that genuinely need the wire value.
 */

/** Settlement state of a transaction. */
export const STATUS = {
  SETTLED: { tone: 'settled', label: 'Settled' },
  COMMITTED: { tone: 'settled', label: 'Settled' },
  PENDING_APPROVAL: { tone: 'held', label: 'Awaiting approval' },
  REJECTED: { tone: 'voided', label: 'Declined' },
  FAILED: { tone: 'voided', label: 'Failed' },
};

export function statusOf(raw) {
  return STATUS[raw] || { tone: 'neutral', label: raw || 'Unknown' };
}

/*
 * Regulatory tier, derived from the amount rather than trusted from a field, so
 * a stale `regulatory_tier` on a persisted record cannot disagree with the
 * money on screen. Thresholds mirror THRESHOLDS in services/api.js.
 */
export function tierOf(amount) {
  const value = Number(amount) || 0;

  if (value >= 500000) {
    return {
      key: 'TIER_3',
      tone: 'voided',
      label: 'Tier 3',
      name: 'AMLA Covered Transaction',
      note: 'Requires customer email verification OTP + automated AMLA CTR compliance report.',
      approvals: 0,
    };
  }

  if (value > 50000) {
    return {
      key: 'TIER_2',
      tone: 'held',
      label: 'Tier 2',
      name: 'Customer Email Verification Required',
      note: 'Soft hold placed. 6-digit verification code dispatched to registered email via MailHog.',
      approvals: 0,
    };
  }

  return {
    key: 'TIER_1',
    tone: 'settled',
    label: 'Tier 1',
    name: 'Straight-Through Processing',
    note: 'Instant settlement via row lock with zero secondary approval.',
    approvals: 0,
  };
}
