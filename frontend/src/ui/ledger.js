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
      name: 'AMLA covered transaction',
      note: 'Reported under AMLA and released by two managers.',
      approvals: 2,
    };
  }

  if (value > 50000) {
    return {
      key: 'TIER_2',
      tone: 'held',
      label: 'Tier 2',
      name: 'Manager approval required',
      note: 'Held for one manager to approve before the funds move.',
      approvals: 1,
    };
  }

  return {
    key: 'TIER_1',
    tone: 'settled',
    label: 'Tier 1',
    name: 'Settles immediately',
    note: 'Sends straight through with no approval step.',
    approvals: 0,
  };
}
