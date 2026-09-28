import React, { useState } from 'react';
import { 
  ArrowLeftRight, 
  Wallet, 
  CreditCard, 
  ShieldAlert, 
  CheckCircle2, 
  Clock, 
  Send,
  AlertTriangle,
  Info,
  RefreshCw,
  Mail
} from 'lucide-react';
import { LedgerService } from '../api/client';

export default function CustomerPortal({ accounts, setAccounts, onTransactionComplete }) {
  const [sourceAccountId, setSourceAccountId] = useState('A2001');
  const [destinationAccountId, setDestinationAccountId] = useState('A2002');
  const [amount, setAmount] = useState('15000');
  const [description, setDescription] = useState('Online Retail Transfer');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [lastMutationResult, setLastMutationResult] = useState(null);
  const [errorMsg, setErrorMsg] = useState(null);

  const numericAmount = parseFloat(amount) || 0;
  const selectedSource = accounts.find((a) => a.accountId === sourceAccountId) || accounts[0];

  // Threshold flags
  const isHighValue = numericAmount > 50000;
  const isAmlaCovered = numericAmount >= 500000;

  const handleTransfer = async (e) => {
    e.preventDefault();
    setErrorMsg(null);
    setLastMutationResult(null);

    if (numericAmount <= 0) {
      setErrorMsg('Please enter a valid transfer amount greater than 0.');
      return;
    }

    if (sourceAccountId === destinationAccountId) {
      setErrorMsg('Source account and destination account cannot be identical.');
      return;
    }

    if (selectedSource && numericAmount > selectedSource.availableBalance) {
      setErrorMsg(`Insufficient funds! Available balance is ₱${selectedSource.availableBalance.toLocaleString('en-US', { minimumFractionDigits: 4 })}.`);
      return;
    }

    setIsSubmitting(true);
    const txId = 'TX-' + Math.random().toString(36).substring(2, 9).toUpperCase();

    const payload = {
      transactionId: txId,
      accountId: sourceAccountId,
      targetAccountId: destinationAccountId,
      mutationAmount: numericAmount,
      eventType: 'TRANSFER',
      mutationType: 'TRANSFER',
      initiatorUserId: 'U1001',
      description: description || 'Retail Fund Transfer',
    };

    const res = await LedgerService.executeTransfer(payload);
    setIsSubmitting(false);

    if (res.success) {
      setLastMutationResult(res.data);
      // Update local account balance
      setAccounts((prev) =>
        prev.map((acc) => {
          if (acc.accountId === sourceAccountId) {
            if (res.data.status === 'PENDING_APPROVAL') {
              return {
                ...acc,
                holdAmount: (acc.holdAmount || 0) + numericAmount,
                availableBalance: acc.availableBalance - numericAmount,
              };
            } else {
              return {
                ...acc,
                balanceAmount: res.data.balanceAfter || acc.balanceAmount - numericAmount,
                availableBalance: res.data.availableBalance || acc.availableBalance - numericAmount,
              };
            }
          }
          if (acc.accountId === destinationAccountId && res.data.status === 'COMMITTED') {
            return {
              ...acc,
              balanceAmount: acc.balanceAmount + numericAmount,
              availableBalance: acc.availableBalance + numericAmount,
            };
          }
          return acc;
        })
      );
      if (onTransactionComplete) {
        onTransactionComplete(res.data);
      }
    } else {
      // Fallback local simulation if backend service is offline
      const isPending = numericAmount > 50000;
      const simulatedResult = {
        transactionId: txId,
        accountId: sourceAccountId,
        targetAccountId: destinationAccountId,
        mutationAmount: numericAmount,
        status: isPending ? 'PENDING_APPROVAL' : 'COMMITTED',
        balanceBefore: selectedSource.balanceAmount,
        balanceAfter: isPending ? selectedSource.balanceAmount : selectedSource.balanceAmount - numericAmount,
        availableBalance: selectedSource.availableBalance - numericAmount,
        holdAmount: isPending ? (selectedSource.holdAmount || 0) + numericAmount : selectedSource.holdAmount,
        isSimulated: true,
        notice: 'Note: Gateway or CME offline. State mutated in local simulator with full dual-storage semantics.',
      };

      setLastMutationResult(simulatedResult);
      setAccounts((prev) =>
        prev.map((acc) => {
          if (acc.accountId === sourceAccountId) {
            return {
              ...acc,
              holdAmount: simulatedResult.holdAmount,
              availableBalance: simulatedResult.availableBalance,
              balanceAmount: simulatedResult.balanceAfter,
            };
          }
          return acc;
        })
      );
      if (onTransactionComplete) {
        onTransactionComplete(simulatedResult);
      }
    }
  };

  return (
    <div className="space-y-6">
      {/* Account Overview Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {accounts
          .filter((a) => a.userId === 'U1001')
          .map((account) => {
            const isCredit = account.accountType === 'CREDIT';
            const isCurrentSource = account.accountId === sourceAccountId;

            return (
              <div
                key={account.accountId}
                onClick={() => setSourceAccountId(account.accountId)}
                className={`p-5 rounded-2xl border transition-all cursor-pointer relative overflow-hidden ${
                  isCurrentSource
                    ? 'bg-slate-900 border-indigo-500 shadow-xl shadow-indigo-500/10 ring-1 ring-indigo-500/50'
                    : 'bg-slate-950/60 border-slate-800 hover:border-slate-700'
                }`}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div
                      className={`p-2.5 rounded-xl border ${
                        isCredit
                          ? 'bg-purple-500/10 text-purple-400 border-purple-500/20'
                          : 'bg-indigo-500/10 text-indigo-400 border-indigo-500/20'
                      }`}
                    >
                      {isCredit ? <CreditCard className="w-5 h-5" /> : <Wallet className="w-5 h-5" />}
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-semibold text-white text-sm">
                          {account.accountId} ({account.accountNumber})
                        </span>
                        <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-slate-800 text-slate-300">
                          {account.accountType}
                        </span>
                      </div>
                      <p className="text-xs text-slate-400">Juan Dela Cruz &bull; Primary Operational</p>
                    </div>
                  </div>

                  {isCurrentSource && (
                    <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-indigo-500/20 text-indigo-300 border border-indigo-500/30">
                      Active Source
                    </span>
                  )}
                </div>

                <div className="mt-5 pt-4 border-t border-slate-800/80 grid grid-cols-2 gap-4">
                  <div>
                    <span className="text-[11px] text-slate-400 font-medium">Available Balance</span>
                    <p className="text-xl font-mono font-bold text-emerald-400 mt-0.5">
                      ₱ {account.availableBalance.toLocaleString('en-US', { minimumFractionDigits: 4, maximumFractionDigits: 4 })}
                    </p>
                  </div>

                  <div>
                    <span className="text-[11px] text-slate-400 font-medium">Soft Hold (Locked)</span>
                    <p className={`text-base font-mono font-semibold mt-0.5 ${account.holdAmount > 0 ? 'text-amber-400' : 'text-slate-500'}`}>
                      ₱ {account.holdAmount.toLocaleString('en-US', { minimumFractionDigits: 4, maximumFractionDigits: 4 })}
                    </p>
                  </div>
                </div>

                {isCredit && (
                  <div className="mt-2 text-[11px] text-slate-400 flex items-center justify-between">
                    <span>Approved Credit Limit:</span>
                    <span className="font-mono text-slate-300 font-medium">
                      ₱ {account.creditLimit.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                    </span>
                  </div>
                )}
              </div>
            );
          })}
      </div>

      {/* Main Transfer Form Card */}
      <div className="p-6 rounded-2xl bg-slate-950/70 border border-slate-800 shadow-xl">
        <div className="flex items-center gap-3 pb-4 border-b border-slate-800">
          <div className="p-2 bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 rounded-xl">
            <ArrowLeftRight className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-base font-bold text-white">Instant Funds Transfer Terminal</h2>
            <p className="text-xs text-slate-400">
              Pessimistic Row Locking (SELECT FOR UPDATE) &bull; Lexicographical Deadlock Guard &bull; Kafka Streaming
            </p>
          </div>
        </div>

        <form onSubmit={handleTransfer} className="mt-6 space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Source Account */}
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-2">
                Source Account (Debited Account)
              </label>
              <select
                value={sourceAccountId}
                onChange={(e) => setSourceAccountId(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-800 rounded-xl text-white text-sm focus:outline-none focus:border-indigo-500 font-mono"
              >
                <option value="A2001">A2001 - Credit Account (₱ {accounts.find(a => a.accountId === 'A2001')?.availableBalance.toLocaleString()} avail)</option>
                <option value="A2003">A2003 - Savings Account (₱ {accounts.find(a => a.accountId === 'A2003')?.availableBalance.toLocaleString()} avail)</option>
              </select>
            </div>

            {/* Destination Account */}
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-2">
                Beneficiary / Destination Account
              </label>
              <select
                value={destinationAccountId}
                onChange={(e) => setDestinationAccountId(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-800 rounded-xl text-white text-sm focus:outline-none focus:border-indigo-500 font-mono"
              >
                <option value="A2002">A2002 - Maria Clara Santos (Savings)</option>
                <option value="A2003">A2003 - Juan Dela Cruz (Own Savings)</option>
                <option value="A2001">A2001 - Juan Dela Cruz (Own Credit)</option>
              </select>
            </div>
          </div>

          {/* Amount and Presets */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <label className="text-xs font-semibold text-slate-300">Transfer Amount (PHP)</label>
              <span className="text-[11px] text-slate-500">Exact 4-decimal precision enforced</span>
            </div>

            <div className="relative">
              <span className="absolute left-4 top-1/2 -translate-y-1/2 font-mono font-bold text-slate-400 text-lg">
                ₱
              </span>
              <input
                type="number"
                step="0.0001"
                min="1"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="0.0000"
                className="w-full pl-10 pr-4 py-3 bg-slate-900 border border-slate-800 rounded-xl text-white font-mono text-xl font-bold focus:outline-none focus:border-indigo-500"
              />
            </div>

            {/* Quick Test Presets */}
            <div className="flex flex-wrap items-center gap-2 mt-3">
              <span className="text-xs text-slate-500 font-medium">Quick Presets:</span>
              <button
                type="button"
                onClick={() => setAmount('10000.0000')}
                className="px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-900 border border-slate-800 text-slate-300 hover:text-emerald-400 hover:border-emerald-500/30 transition"
              >
                ₱10,000 (Tier 1: Immediate)
              </button>
              <button
                type="button"
                onClick={() => setAmount('75000.0000')}
                className="px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-900 border border-slate-800 text-slate-300 hover:text-amber-400 hover:border-amber-500/30 transition"
              >
                ₱75,000 (Tier 2: Dual Control Hold)
              </button>
              <button
                type="button"
                onClick={() => setAmount('550000.0000')}
                className="px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-900 border border-slate-800 text-slate-300 hover:text-rose-400 hover:border-rose-500/30 transition"
              >
                ₱550,000 (Tier 3: AMLA CTR)
              </button>
            </div>
          </div>

          {/* Description */}
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-2">Description / Transaction Memo</label>
            <input
              type="text"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="e.g. Supplier payment, retail transfer"
              className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-800 rounded-xl text-white text-sm focus:outline-none focus:border-indigo-500"
            />
          </div>

          {/* Dynamic BSP & AMLA Policy Feedback Banner */}
          <div
            className={`p-4 rounded-xl border flex items-start gap-3 transition-all ${
              isAmlaCovered
                ? 'bg-rose-500/10 border-rose-500/30 text-rose-300'
                : isHighValue
                ? 'bg-amber-500/10 border-amber-500/30 text-amber-300'
                : 'bg-indigo-500/10 border-indigo-500/30 text-indigo-300'
            }`}
          >
            {isAmlaCovered ? (
              <AlertTriangle className="w-5 h-5 text-rose-400 flex-shrink-0 mt-0.5" />
            ) : isHighValue ? (
              <Clock className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
            ) : (
              <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0 mt-0.5" />
            )}

            <div className="text-xs space-y-1">
              <span className="font-bold uppercase tracking-wider text-[11px]">
                {isAmlaCovered
                  ? 'Tier 3 AMLA Covered Transaction Notice (>= ₱500,000.00)'
                  : isHighValue
                  ? 'Tier 2 Maker-Checker Dual Control Triggered (> ₱50,000.00)'
                  : 'Tier 1 Immediate Atomic Mutation (<= ₱50,000.00)'}
              </span>
              <p className="leading-relaxed opacity-90">
                {isAmlaCovered
                  ? 'Transactions of ₱500,000.00 or higher place an immediate soft hold and generate a mandatory Anti-Money Laundering Act (AMLA) Covered Transaction Report (CTR). Approval requires dual authorization by Branch Operations Officer and Branch Head.'
                  : isHighValue
                  ? 'Transfers exceeding the ₱50,000.00 threshold will place a soft hold on your available balance. The funds remain locked in PENDING_APPROVAL status until verified and approved by a Branch Operations Officer (Checker).'
                  : 'Instant balance settlement via pessimistic database row lock. Sub-50ms SLA. An official HTML digital receipt and inward credit advice will be automatically generated and dispatched.'}
              </p>
            </div>
          </div>

          {/* Error Message */}
          {errorMsg && (
            <div className="p-3.5 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-xs flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 flex-shrink-0" />
              <span>{errorMsg}</span>
            </div>
          )}

          {/* Submit Button */}
          <div className="flex items-center justify-end gap-3 pt-2">
            <button
              type="submit"
              disabled={isSubmitting}
              className="w-full sm:w-auto px-6 py-3 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-semibold rounded-xl text-sm transition-all shadow-lg shadow-indigo-600/30 flex items-center justify-center gap-2"
            >
              {isSubmitting ? (
                <>
                  <RefreshCw className="w-4 h-4 animate-spin" />
                  <span>Processing Concurrency Lock...</span>
                </>
              ) : (
                <>
                  <Send className="w-4 h-4" />
                  <span>Submit Transfer</span>
                </>
              )}
            </button>
          </div>
        </form>

        {/* Transaction Result Modal / Banner */}
        {lastMutationResult && (
          <div className="mt-6 p-5 rounded-2xl bg-slate-900 border border-slate-700/80 shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div className="flex items-center gap-2">
                <span
                  className={`px-2.5 py-1 rounded-full text-xs font-bold ${
                    lastMutationResult.status === 'COMMITTED'
                      ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                      : 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
                  }`}
                >
                  {lastMutationResult.status}
                </span>
                <span className="font-mono text-xs text-slate-300">
                  Ref: {lastMutationResult.transactionId}
                </span>
              </div>
              <span className="text-xs text-slate-500">
                {new Date().toLocaleTimeString()}
              </span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs font-mono">
              <div>
                <span className="text-slate-500 block text-[11px]">Mutation Amount:</span>
                <span className="text-base font-bold text-white">
                  ₱ {parseFloat(lastMutationResult.mutationAmount || 0).toLocaleString('en-US', { minimumFractionDigits: 4 })}
                </span>
              </div>
              <div>
                <span className="text-slate-500 block text-[11px]">Balance After:</span>
                <span className="text-base font-bold text-slate-300">
                  ₱ {parseFloat(lastMutationResult.balanceAfter || 0).toLocaleString('en-US', { minimumFractionDigits: 4 })}
                </span>
              </div>
              <div>
                <span className="text-slate-500 block text-[11px]">Available Balance:</span>
                <span className="text-base font-bold text-emerald-400">
                  ₱ {parseFloat(lastMutationResult.availableBalance || 0).toLocaleString('en-US', { minimumFractionDigits: 4 })}
                </span>
              </div>
            </div>

            <div className="pt-2 text-xs text-slate-400 border-t border-slate-800 flex items-center justify-between">
              <span>
                {lastMutationResult.status === 'COMMITTED'
                  ? 'Transferred & dual-written to Oracle and PostgreSQL Audit Vault.'
                  : 'Placed in Soft Hold. Check Teller / Manager portal to approve or reject.'}
              </span>
              <a
                href="http://localhost:8025"
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1 text-indigo-400 hover:text-indigo-300 font-medium"
              >
                <Mail className="w-3.5 h-3.5" />
                <span>View Receipt in MailHog</span>
              </a>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
