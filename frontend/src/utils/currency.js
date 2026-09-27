// Financial 4-decimal precision helper utilities for Philippine Peso (PHP)

export function formatPHP(value) {
  if (value === undefined || value === null || isNaN(value)) {
    return '₱ 0.0000';
  }
  const num = typeof value === 'string' ? parseFloat(value) : value;
  const parts = num.toFixed(4).split('.');
  // Add comma separators to integer part
  parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return `₱ ${parts.join('.')}`;
}

export function parseMaskedInput(input) {
  // Allow digits and at most one decimal point
  let clean = input.replace(/[^0-9.]/g, '');
  const parts = clean.split('.');
  if (parts.length > 2) {
    clean = parts[0] + '.' + parts.slice(1).join('');
  }
  if (parts[1] && parts[1].length > 4) {
    clean = parts[0] + '.' + parts[1].slice(0, 4);
  }
  return clean;
}

export function generateUUID() {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}
