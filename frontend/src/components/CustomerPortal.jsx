import React, { useState, useEffect } from 'react';
import { 
  ArrowUpRight, 
  Wallet, 
  Lock, 
  Clock, 
  Send, 
  CreditCard, 
  CheckCircle2, 
  AlertCircle, 
  ShieldCheck, 
  UserCheck, 
  Copy, 
  Check, 
  Building2, 
  Printer, 
  X, 
  FileText, 
  Eye, 
  EyeOff, 
  Search, 
  Receipt, 
  ChevronRight, 
  User,
  Download,
  Calendar,
  Filter,
  FileSpreadsheet,
  RotateCcw
} from 'lucide-react';
import { formatPHP, parseMaskedInput, generateUUID } from '../utils/currency';
import apiClient, { mockState, THRESHOLDS } from '../services/api';
import { useAuth } from '../context/AuthContext';
import CustomerProfile from './CustomerProfile';

export default function CustomerPortal({ balance, onTransactionComplete, onSwitchAccount, showToast }) {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState('history'); // 'history' | 'transfer' | 'profile'
  const [copied, setCopied] = useState(false);

  // Active Account State (SAVINGS vs CREDIT)
  const isCredit = balance?.account_type === 'CREDIT' || balance?.account_id === '1000-2000-3003';
  const activeAccountId = balance?.account_id || '1000-2000-3001';

  // Eye Toggle State (Show / Hide Balance & Account Number)
  const [isBalanceVisible, setIsBalanceVisible] = useState(true);
  const [isAccountVisible, setIsAccountVisible] = useState(true);

  useEffect(() => {
    onTransactionComplete?.();
  }, []);

  // Search & Filter State for Activity
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL'); // 'ALL' | 'SETTLED' | 'PENDING_APPROVAL'
  const [dateFilter, setDateFilter] = useState('ALL');     // 'ALL' | 'TODAY' | 'MONTH'
  const [accountFilter, setAccountFilter] = useState('ALL'); // 'ALL' | '1000-2000-3001' | '1000-2000-3003'

  const handleSelectAccount = (targetAccountId) => {
    if (balance?.account_id === targetAccountId) return;
    if (onSwitchAccount) {
      onSwitchAccount(targetAccountId);
      const isTargetCredit = targetAccountId.includes('3003');
      showToast({
        type: 'info',
        title: isTargetCredit ? 'Switched to Credit Facility' : 'Switched to Savings Account',
        detail: `Now managing ${isTargetCredit ? 'Revolving Credit Line (1000-2000-3003)' : 'Primary Savings (1000-2000-3001)'}.`,
      });
    }
  };

  const formatVisiblePHP = (val) => {
    if (!isBalanceVisible) return '₱ ••••••••';
    return formatPHP(val);
  };

  const formatVisibleAccount = (acctId) => {
    const raw = acctId || '1000-2000-3001';
    if (isAccountVisible) return raw;
    const parts = String(raw).split('-');
    if (parts.length === 3) {
      return `••••-••••-${parts[2]}`;
    }
    return raw.length > 4 ? `••••••••${raw.slice(-4)}` : '••••••••';
  };

  const handlePayCreditBalance = () => {
    setActiveTab('transfer');
    handleSelectAccount('1000-2000-3001');
    setToAccount('1000-2000-3003');
    setRecipientName('Juan Dela Cruz (Revolving Credit)');
    const outstanding = (mockState.creditAccount?.current_balance || balance?.current_balance || 2000).toFixed(2);
    setAmountInput(outstanding);
    setMemo('Credit Card Statement Balance Settlement');
    showToast({
      type: 'info',
      title: 'Credit Settlement Form Ready',
      detail: `Pre-filled payment of ${formatPHP(parseFloat(outstanding))} from Savings to settle Credit Line.`,
    });
  };

  const handleViewReceipt = (tx) => {
    const isIncoming = tx.direction === 'INCOMING' || (tx.from_account_id || '').includes('9999') || (tx.recipient_name || '').includes('Payroll');
    setReceiptData({
      refNumber: tx.id,
      fromAccount: tx.from_account_id || balance?.account_id || '1000-2000-3001',
      senderName: isIncoming ? 'Executive Corporate Payroll ACH' : (user?.name || 'Juan Dela Cruz'),
      toAccount: tx.to_account_id,
      recipientName: tx.recipient_name,
      amount: tx.amount,
      fee: 0,
      memo: tx.memo || (isIncoming ? 'Payroll Credit' : 'Fund Transfer'),
      isHighValue: tx.status === 'PENDING_APPROVAL',
      isIncoming,
      timestamp: new Date(tx.created_at || Date.now()),
    });
  };

  const handleCopyAccount = () => {
    const acct = balance?.account_id || '1000-2000-3001';
    if (navigator.clipboard) {
      navigator.clipboard.writeText(acct);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  // 1-Click Download Official Digital Slip (.txt)
  const handleDownloadReceipt = () => {
    if (!receiptData) return;
    const dateFormatted = receiptData.timestamp.toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' });
    const timeFormatted = receiptData.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    const content = `=====================================================
         CAPSTONE CORE RETAIL BANKING
          OFFICIAL TRANSACTION RECEIPT
=====================================================
Reference No.  : ${receiptData.refNumber}
Date & Time    : ${dateFormatted} ${timeFormatted}
Status         : ${receiptData.isHighValue ? 'PENDING VERIFICATION (UNDER REVIEW)' : 'COMPLETED (SETTLED)'}

TRANSACTION DETAILS
-----------------------------------------------------
Amount Sent    : PHP ${receiptData.amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
Service Fee    : PHP 0.00 (FREE)
Total Deducted : PHP ${receiptData.amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}

BENEFICIARY & SENDER
-----------------------------------------------------
Sent To        : ${receiptData.recipientName}
Account Number : ${receiptData.toAccount}

Sent From      : ${receiptData.senderName}
Source Account : ${receiptData.fromAccount}

Purpose / Note : ${receiptData.memo || 'Fund Transfer'}
=====================================================
This is a computer-generated electronic receipt.
Certified compliant with BSP Circular 1033 standards.
=====================================================`;

    const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `Receipt-${receiptData.refNumber}.txt`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    showToast({
      type: 'success',
      title: 'Receipt Downloaded',
      detail: `Saved official receipt slip for ${receiptData.refNumber}.`,
    });
  };

  // Export Filtered Activity to CSV
  const handleExportCSV = (transactionsToExport) => {
    if (!transactionsToExport || transactionsToExport.length === 0) {
      showToast({
        type: 'warning',
        title: 'No Data to Export',
        detail: 'There are no transactions matching your current filters.',
      });
      return;
    }

    const headers = ['Reference_No', 'Type', 'Party_Name', 'Account_No', 'Amount_PHP', 'Status', 'Date', 'Time', 'Purpose_Note'];
    const rows = transactionsToExport.map((tx) => {
      const isIncoming = tx.direction === 'INCOMING' || (tx.from_account_id || '').includes('9999') || (tx.recipient_name || '').includes('Payroll');
      const txDate = new Date(tx.created_at);
      return [
        `"${tx.id}"`,
        `"${isIncoming ? 'CREDIT (Incoming)' : 'DEBIT (Outgoing)'}"`,
        `"${(tx.recipient_name || '').replace(/"/g, '""')}"`,
        `"${isIncoming ? (tx.from_account_id || '') : (tx.to_account_id || '')}"`,
        `"${isIncoming ? '+' : '-'}${tx.amount.toFixed(2)}"`,
        `"${tx.status === 'SETTLED' ? 'Completed' : tx.status === 'PENDING_APPROVAL' ? 'Pending Review' : tx.status}"`,
        `"${txDate.toLocaleDateString()}"`,
        `"${txDate.toLocaleTimeString()}"`,
        `"${(tx.memo || '').replace(/"/g, '""')}"`,
      ];
    });

    const csvContent = [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `Account_Statement_${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    showToast({
      type: 'success',
      title: 'Statement Downloaded',
      detail: `Exported ${transactionsToExport.length} transaction records as CSV.`,
    });
  };

  // Transfer Form State (Empty by default for real customer entry)
  const [toAccount, setToAccount] = useState('');
  const [recipientName, setRecipientName] = useState('');
  const [amountInput, setAmountInput] = useState('');
  const [memo, setMemo] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [currentIdempotencyKey, setCurrentIdempotencyKey] = useState(generateUUID());

  // Modal States
  const [isConfirmModalOpen, setIsConfirmModalOpen] = useState(false);
  const [receiptData, setReceiptData] = useState(null);
  const [receiptCopied, setReceiptCopied] = useState(false);

  const numericAmount = parseFloat(amountInput) || 0;

  const handleAmountChange = (e) => {
    const masked = parseMaskedInput(e.target.value, 2);
    setAmountInput(masked);
  };

  // Quick Amount Handlers
  const handleAddAmount = (addVal) => {
    const current = parseFloat(amountInput) || 0;
    const nextVal = (current + addVal).toFixed(2);
    setAmountInput(nextVal);
  };

  const handleSetMaxAmount = () => {
    const maxVal = (balance?.available_balance || 0).toFixed(2);
    setAmountInput(maxVal);
  };

  // Step 1: Validate and open the Transfer Confirmation Modal
  const handleInitiateTransfer = (e) => {
    e.preventDefault();
    if (!toAccount.trim() || !recipientName.trim()) {
      showToast({
        type: 'error',
        title: 'Missing Details',
        detail: 'Please provide both the recipient account number and full name.',
      });
      return;
    }

    // Prevent transferring to own account
    const myAccountClean = (balance?.account_id || '1000-2000-3001').replace(/[\s-]/g, '').toUpperCase();
    const enteredAccountClean = toAccount.trim().replace(/[\s-]/g, '').toUpperCase();
    if (myAccountClean === enteredAccountClean) {
      showToast({
        type: 'error',
        title: 'Invalid Destination Account',
        detail: 'You cannot transfer funds to your own account.',
      });
      return;
    }

    // Verify recipient existence against bank ledger
    const registeredList = mockState?.registeredAccounts || [];
    if (registeredList.length > 0) {
      const match = registeredList.find((acc) => {
        const accNumClean = (acc.account_number || '').replace(/[\s-]/g, '').toUpperCase();
        const accIdClean = (acc.account_id || '').replace(/[\s-]/g, '').toUpperCase();
        return accNumClean === enteredAccountClean || accIdClean === enteredAccountClean;
      });
      if (!match) {
        showToast({
          type: 'error',
          title: 'Account Does Not Exist',
          detail: `Destination account "${toAccount}" does not exist in the bank directory. Please enter a valid account number (e.g. 1000-2000-3002).`,
        });
        return;
      }
    }

    if (numericAmount < 1.00) {
      showToast({
        type: 'error',
        title: 'Invalid Amount',
        detail: 'Minimum transfer amount is ₱ 1.00.',
      });
      return;
    }

    if (numericAmount > (balance?.available_balance || 0)) {
      showToast({
        type: 'error',
        title: 'Insufficient Balance',
        detail: `You only have ${formatPHP(balance?.available_balance)} available to transfer.`,
      });
      return;
    }

    setIsConfirmModalOpen(true);
  };

  // Step 2: User confirmed in Modal -> Execute API call & generate Receipt
  const handleExecuteTransfer = async () => {
    setIsSubmitting(true);
    try {
      const generatedRef = 'TRX-' + Math.floor(100000 + Math.random() * 900000);
      const res = await apiClient.post(
        '/transfers',
        {
          from_account_id: balance?.account_id || '1000-2000-3001',
          to_account_id: toAccount.trim(),
          recipient_name: recipientName.trim(),
          amount: numericAmount,
          currency: 'PHP',
          memo: memo.trim() || 'Fund Transfer',
          maker_user_id: user?.user_id || 'U1001',
        },
        {
          headers: {
            'X-Idempotency-Key': currentIdempotencyKey,
          },
        }
      );

      const isHighValue = numericAmount > THRESHOLDS.STP_MAX;

      if (isHighValue) {
        showToast({
          type: 'warning',
          title: 'Transfer Submitted for Verification',
          detail: `Your transfer of ${formatPHP(numericAmount)} to ${recipientName} has been submitted for bank manager approval.`,
        });
      } else {
        showToast({
          type: 'success',
          title: 'Transfer Successful',
          detail: `Successfully sent ${formatPHP(numericAmount)} to ${recipientName}.`,
        });
      }

      // Populate Digital Receipt Slip
      setReceiptData({
        refNumber: res?.data?.transfer_id || generatedRef,
        fromAccount: balance?.account_id || '1000-2000-3001',
        senderName: user?.name || 'Juan Dela Cruz',
        toAccount: toAccount.trim(),
        recipientName: recipientName.trim(),
        amount: numericAmount,
        fee: 0,
        memo: memo.trim() || 'Fund Transfer',
        isHighValue,
        timestamp: new Date(),
      });

      // Close confirmation modal
      setIsConfirmModalOpen(false);

      // Reset form to empty for the next transfer
      setToAccount('');
      setRecipientName('');
      setAmountInput('');
      setMemo('');

      // Generate a fresh idempotency key for the next transfer
      setCurrentIdempotencyKey(generateUUID());
      onTransactionComplete();
    } catch (err) {
      const problem = err.response?.data;
      showToast({
        type: 'error',
        title: problem?.title || 'Transfer Failed',
        detail: problem?.detail || 'Unable to complete transfer. Please verify recipient account and try again.',
      });
      // Close confirmation modal so user can fix their input
      setIsConfirmModalOpen(false);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Prominent Customer Account Summary Banner */}
      <div className="relative overflow-hidden bg-gradient-to-r from-slate-900 via-slate-900/90 to-indigo-950/40 border border-slate-800/80 rounded-2xl p-5 shadow-xl flex flex-col md:flex-row md:items-center justify-between gap-4 group hover:border-slate-700/80 transition-all duration-300">
        <div className="absolute -right-10 -bottom-10 w-44 h-44 bg-indigo-600/10 rounded-full blur-3xl pointer-events-none" />
        <div className="flex items-center gap-4 relative z-10">
          <div className={`w-12 h-12 rounded-2xl ${
            isCredit ? 'bg-purple-500/10 border-purple-500/30 text-purple-400' : 'bg-indigo-500/10 border-indigo-500/30 text-indigo-400'
          } border flex items-center justify-center shadow-inner group-hover:scale-105 transition-transform duration-300`}>
            {isCredit ? <CreditCard className="w-6 h-6" /> : <Building2 className="w-6 h-6" />}
          </div>
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h3 className="text-lg font-bold text-white tracking-tight">
                Welcome back, {user?.first_name || 'Juan'}
              </h3>
              <span className="text-[10px] font-semibold uppercase tracking-wider bg-emerald-500/10 text-emerald-400 px-2.5 py-0.5 rounded-full border border-emerald-500/20 flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" /> Active Account
              </span>
              <span className={`text-[10px] font-semibold uppercase tracking-wider px-2.5 py-0.5 rounded-full border ${
                isCredit
                  ? 'bg-purple-500/10 text-purple-300 border-purple-500/25'
                  : 'bg-indigo-500/10 text-indigo-300 border-indigo-500/25'
              }`}>
                {isCredit ? 'CREDIT ACCOUNT' : 'SAVINGS ACCOUNT'}
              </span>
            </div>
            <p className="text-xs text-slate-400 mt-1">
              {isCredit ? 'Revolving Credit Line Facility' : 'Primary Deposit Account'} &bull; Philippine Peso (PHP)
            </p>
          </div>
        </div>

        {/* Account Switcher Bar & Account Number */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 relative z-10">
          {/* Dual Account Switcher Controls */}
          <div className="flex items-center p-1 rounded-xl bg-slate-950/90 border border-slate-800 shadow-inner">
            <button
              type="button"
              onClick={() => handleSelectAccount('1000-2000-3001')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                !isCredit
                  ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/30'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
              }`}
            >
              <Wallet className={`w-3.5 h-3.5 ${!isCredit ? 'text-white' : 'text-emerald-400'}`} />
              <span>Savings</span>
              <span className="text-[10px] font-mono opacity-80">(...3001)</span>
            </button>
            <button
              type="button"
              onClick={() => handleSelectAccount('1000-2000-3003')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                isCredit
                  ? 'bg-purple-600 text-white shadow-md shadow-purple-600/30'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
              }`}
            >
              <CreditCard className={`w-3.5 h-3.5 ${isCredit ? 'text-white' : 'text-purple-300'}`} />
              <span>Credit Line</span>
              <span className="text-[10px] font-mono opacity-80">(...3003)</span>
            </button>
          </div>

          {/* Account Number Box */}
          <div className="flex items-center justify-between gap-2 bg-slate-950/80 border border-slate-800 px-3 py-2 rounded-xl shadow-inner">
            <div className="mr-1">
              <div className="flex items-center gap-1.5">
                <span className="text-[10px] font-semibold uppercase tracking-wider text-slate-400">
                  {isCredit ? 'Credit Account' : 'Savings Account'}
                </span>
                <button
                  type="button"
                  onClick={() => setIsAccountVisible(!isAccountVisible)}
                  title={isAccountVisible ? "Hide Account Number" : "Show Account Number"}
                  className="text-slate-400 hover:text-white transition-colors p-0.5 rounded hover:bg-slate-800"
                >
                  {isAccountVisible ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5 text-indigo-400" />}
                </button>
              </div>
              <span className={`text-sm font-mono font-bold tracking-wider ${isCredit ? 'text-purple-300' : 'text-indigo-300'}`}>
                {formatVisibleAccount(balance?.account_id)}
              </span>
            </div>
            <button
              type="button"
              onClick={handleCopyAccount}
              title="Copy account number"
              className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-all text-xs font-medium border border-slate-700/60 active:scale-95"
            >
              {copied ? (
                <>
                  <Check className="w-3.5 h-3.5 text-emerald-400" />
                  <span className="text-emerald-400 font-semibold text-[11px]">Copied!</span>
                </>
              ) : (
                <>
                  <Copy className="w-3.5 h-3.5" />
                  <span className="text-[11px]">Copy</span>
                </>
              )}
            </button>
          </div>
        </div>
      </div>

      {/* 3 Dynamic Customer Balance Cards (Shown on Activity and Send Money) */}
      {activeTab !== 'profile' && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-5 animate-fadeIn">
          {/* Card 1: Available Funds (Available Balance vs Available Credit) */}
          <div className={`relative p-6 rounded-2xl bg-gradient-to-br ${
            isCredit 
              ? 'from-slate-900 via-slate-900 to-purple-950/50 border-purple-500/40 hover:shadow-purple-500/15 hover:border-purple-500/60' 
              : 'from-slate-900 via-slate-900 to-indigo-950/50 border-indigo-500/40 hover:shadow-indigo-500/15 hover:border-indigo-500/60'
          } border shadow-xl overflow-hidden group hover:-translate-y-1 hover:shadow-2xl transition-all duration-300`}>
            <div className={`absolute -right-8 -top-8 w-36 h-36 ${isCredit ? 'bg-purple-500/20 group-hover:bg-purple-500/30' : 'bg-indigo-500/20 group-hover:bg-indigo-500/30'} rounded-full blur-2xl pointer-events-none transition-all duration-500`} />
            <div className="flex items-center justify-between mb-3 relative z-10">
              <span className={`text-xs font-semibold uppercase tracking-wider ${isCredit ? 'text-purple-400' : 'text-indigo-400'} flex items-center gap-1.5`}>
                {isCredit ? <CreditCard className="w-4 h-4" /> : <Wallet className="w-4 h-4" />}
                {isCredit ? 'Available Credit' : 'Available Balance'}
                <button
                  type="button"
                  onClick={() => setIsBalanceVisible(!isBalanceVisible)}
                  title={isBalanceVisible ? "Hide Balance" : "Show Balance"}
                  className="text-slate-400 hover:text-white transition-colors ml-1 p-0.5 rounded hover:bg-slate-800"
                >
                  {isBalanceVisible ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className={`w-3.5 h-3.5 ${isCredit ? 'text-purple-400' : 'text-indigo-400'}`} />}
                </button>
              </span>
              <span className={`text-[10px] font-semibold px-2.5 py-0.5 rounded-full border ${
                isCredit 
                  ? 'bg-purple-500/15 text-purple-300 border-purple-500/30' 
                  : 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30'
              }`}>
                {isCredit ? 'Ready to Draw' : 'Ready to Spend'}
              </span>
            </div>
            <div className="text-3xl font-mono font-bold text-white tracking-tight relative z-10">
              {formatVisiblePHP(balance?.available_balance)}
            </div>
            <p className="text-xs text-slate-400 mt-2 relative z-10">
              {isCredit 
                ? 'Remaining revolving credit line available for withdrawal or purchase.' 
                : 'Funds ready for immediate withdrawal or transfer.'}
            </p>
          </div>

          {/* Card 2: Total Balance vs Approved Credit Limit */}
          <div className="relative p-6 rounded-2xl bg-slate-900/80 border border-slate-800/80 shadow-lg overflow-hidden group hover:-translate-y-1 hover:border-slate-700 hover:shadow-xl transition-all duration-300">
            <div className="absolute -right-8 -top-8 w-36 h-36 bg-blue-500/10 rounded-full blur-2xl pointer-events-none group-hover:bg-blue-500/20 transition-all duration-500" />
            <div className="flex items-center justify-between mb-3 relative z-10">
              <span className="text-xs font-semibold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
                {isCredit ? <Building2 className="w-4 h-4 text-slate-400" /> : <CreditCard className="w-4 h-4 text-slate-400" />}
                {isCredit ? 'Approved Credit Limit' : 'Total Balance'}
              </span>
              <span className="text-[10px] font-medium bg-slate-800 text-slate-300 px-2 py-0.5 rounded">
                {isCredit ? 'Approved Facility' : 'Gross Ledger'}
              </span>
            </div>
            <div className="text-2xl font-mono font-bold text-slate-200 relative z-10">
              {formatVisiblePHP(isCredit ? (balance?.credit_limit || 300000) : balance?.current_balance)}
            </div>
            <p className="text-xs text-slate-400 mt-2 relative z-10">
              {isCredit 
                ? 'Total revolving line approved under Oracle credit assessment.' 
                : 'Principal funds including active holds.'}
            </p>
          </div>

          {/* Card 3: On Hold vs Current Drawn Balance */}
          <div className="relative p-6 rounded-2xl bg-slate-900/80 border border-slate-800/80 shadow-lg overflow-hidden group hover:-translate-y-1 hover:border-amber-500/30 hover:shadow-xl transition-all duration-300">
            <div className="absolute -right-8 -top-8 w-36 h-36 bg-amber-500/10 rounded-full blur-2xl pointer-events-none group-hover:bg-amber-500/20 transition-all duration-500" />
            <div className="flex items-center justify-between mb-3 relative z-10">
              <span className="text-xs font-semibold uppercase tracking-wider text-amber-400 flex items-center gap-1.5">
                {isCredit ? <Clock className="w-4 h-4 text-amber-400" /> : <Lock className="w-4 h-4 text-amber-400" />}
                {isCredit ? 'Current Drawn / Due' : 'On Hold'}
              </span>
              {isCredit ? (
                <span className={`text-[10px] font-medium px-2 py-0.5 rounded border ${
                  (balance?.current_balance || 0) > 0
                    ? 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                    : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                }`}>
                  {(balance?.current_balance || 0) > 0 ? 'Outstanding' : 'Fully Paid'}
                </span>
              ) : (
                balance?.held_balance > 0 && (
                  <span className="text-[10px] font-medium bg-amber-500/10 text-amber-400 px-2 py-0.5 rounded border border-amber-500/20 animate-pulse">
                    Processing
                  </span>
                )
              )}
            </div>
            <div className="text-2xl font-mono font-bold text-amber-400 relative z-10">
              {formatVisiblePHP(isCredit ? (balance?.current_balance || 0) : balance?.held_balance)}
            </div>
            <p className="text-xs text-slate-400 mt-2 relative z-10">
              {isCredit 
                ? 'Current balance drawn against your credit line awaiting billing cycle.' 
                : 'Pending transfers currently undergoing bank verification.'}
            </p>

            {/* 1-Click Pay Credit Balance Button */}
            {isCredit && (
              <div className="mt-3 pt-3 border-t border-slate-800/80 relative z-10">
                {(balance?.current_balance || 0) > 0 ? (
                  <button
                    type="button"
                    onClick={handlePayCreditBalance}
                    className="w-full py-2 px-3 rounded-xl bg-purple-600/20 hover:bg-purple-600/30 text-purple-300 hover:text-white border border-purple-500/40 hover:border-purple-500/70 text-xs font-semibold flex items-center justify-center gap-1.5 transition-all shadow-sm active:scale-95 cursor-pointer"
                  >
                    <CreditCard className="w-3.5 h-3.5 text-purple-400" />
                    <span>Pay Full Balance • {formatVisiblePHP(balance?.current_balance || 0)}</span>
                  </button>
                ) : (
                  <div className="flex items-center justify-center gap-1.5 py-1.5 px-2 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-[11px] font-medium">
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    <span>No outstanding dues &bull; Facility in good standing</span>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Tabs */}
      <div className="flex items-center gap-3 border-b border-slate-800/80 pb-3">
        <button
          onClick={() => setActiveTab('history')}
          className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all flex items-center gap-2 cursor-pointer ${
            activeTab === 'history'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900'
          }`}
        >
          <Clock className="w-3.5 h-3.5" /> Recent Activity
        </button>
        <button
          onClick={() => setActiveTab('transfer')}
          className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all flex items-center gap-2 cursor-pointer ${
            activeTab === 'transfer'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900'
          }`}
        >
          <Send className="w-3.5 h-3.5" /> Send Money
        </button>
        <button
          onClick={() => setActiveTab('profile')}
          className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all flex items-center gap-2 cursor-pointer ${
            activeTab === 'profile'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900'
          }`}
        >
          <User className="w-3.5 h-3.5" /> Profile &amp; Security
        </button>
      </div>

      {/* TAB 1: Clean Customer Fund Transfer Form */}
      {activeTab === 'transfer' && (
        <div className="max-w-2xl mx-auto p-6 md:p-8 rounded-3xl bg-slate-900/80 backdrop-blur-xl border border-slate-800 shadow-2xl space-y-6 relative overflow-hidden group">
          <div className="absolute -top-24 -left-24 w-64 h-64 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none group-hover:bg-indigo-500/15 transition-all duration-500" />
          <div className="border-b border-slate-800/80 pb-4 relative z-10">
            <h3 className="text-lg font-bold text-white flex items-center gap-2">
              <Send className="w-5 h-5 text-indigo-400" />
              Send Money
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Transfer funds instantly to any registered bank account.
            </p>
          </div>

          <form onSubmit={handleInitiateTransfer} className="space-y-5 relative z-10">
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                From Account (Source Account)
              </label>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {/* Savings Choice */}
                <button
                  type="button"
                  onClick={() => handleSelectAccount('1000-2000-3001')}
                  className={`p-3.5 rounded-2xl border text-left transition-all cursor-pointer relative overflow-hidden ${
                    !isCredit
                      ? 'bg-slate-950/90 border-indigo-500/60 shadow-lg shadow-indigo-500/10 ring-1 ring-indigo-500/30'
                      : 'bg-slate-950/50 border-slate-800/80 hover:border-slate-700 opacity-60 hover:opacity-100'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <div className="w-7 h-7 rounded-lg bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400">
                        <Wallet className="w-3.5 h-3.5" />
                      </div>
                      <span className="text-xs font-bold text-white">Savings Account</span>
                    </div>
                    <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-semibold">
                      SAVINGS
                    </span>
                  </div>
                  <div className="mt-2.5 flex items-center justify-between text-[11px] pt-1.5 border-t border-slate-800/60">
                    <span className="font-mono text-slate-400">{formatVisibleAccount('1000-2000-3001')}</span>
                    <span className="font-mono font-bold text-emerald-400">
                      {!isCredit ? formatVisiblePHP(balance?.available_balance) : '₱ ••••••••'}
                    </span>
                  </div>
                </button>

                {/* Credit Choice */}
                <button
                  type="button"
                  onClick={() => handleSelectAccount('1000-2000-3003')}
                  className={`p-3.5 rounded-2xl border text-left transition-all cursor-pointer relative overflow-hidden ${
                    isCredit
                      ? 'bg-slate-950/90 border-purple-500/60 shadow-lg shadow-purple-500/10 ring-1 ring-purple-500/30'
                      : 'bg-slate-950/50 border-slate-800/80 hover:border-slate-700 opacity-60 hover:opacity-100'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <div className="w-7 h-7 rounded-lg bg-purple-500/10 border border-purple-500/20 flex items-center justify-center text-purple-400">
                        <CreditCard className="w-3.5 h-3.5" />
                      </div>
                      <span className="text-xs font-bold text-white">Credit Facility</span>
                    </div>
                    <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-purple-500/10 text-purple-300 border border-purple-500/20 font-semibold">
                      CREDIT
                    </span>
                  </div>
                  <div className="mt-2.5 flex items-center justify-between text-[11px] pt-1.5 border-t border-slate-800/60">
                    <span className="font-mono text-slate-400">{formatVisibleAccount('1000-2000-3003')}</span>
                    <span className="font-mono font-bold text-purple-300">
                      {isCredit ? formatVisiblePHP(balance?.available_balance) : '₱ ••••••••'}
                    </span>
                  </div>
                </button>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Recipient Account Number
                </label>
                <input
                  type="text"
                  required
                  value={toAccount}
                  onChange={(e) => {
                    const val = e.target.value;
                    setToAccount(val);
                    const clean = val.replace(/[\s-]/g, '').toUpperCase();
                    if (clean === '100020003002' || clean === 'A2002') {
                      if (!recipientName) setRecipientName('Maria Clara Santos');
                    } else if (clean === '100020003003' || clean === 'A2003') {
                      if (!recipientName) setRecipientName('Juan Dela Cruz (Revolving Credit)');
                    } else if (clean === '100020003001' || clean === 'A2001') {
                      if (!recipientName) setRecipientName('Juan Dela Cruz (Primary Savings)');
                    }
                  }}
                  placeholder="Enter account number (e.g. 1000-2000-3002)"
                  className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-3.5 py-2.5 text-xs font-mono text-white placeholder:text-slate-600 focus:outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-500/40 focus:shadow-lg focus:shadow-indigo-500/10 transition-all duration-200"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Recipient Full Name
                </label>
                <input
                  type="text"
                  required
                  value={recipientName}
                  onChange={(e) => setRecipientName(e.target.value)}
                  placeholder="Enter full name (e.g. Maria Santos)"
                  className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder:text-slate-600 focus:outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-500/40 focus:shadow-lg focus:shadow-indigo-500/10 transition-all duration-200"
                />
              </div>
            </div>

            {/* Quick Beneficiary Shortcuts */}
            <div className="flex flex-wrap items-center gap-2 -mt-2">
              <span className="text-[11px] text-slate-400">Quick Select:</span>
              <button
                type="button"
                onClick={() => {
                  setToAccount('1000-2000-3002');
                  setRecipientName('Maria Clara Santos');
                }}
                className="px-2.5 py-1 rounded-lg bg-slate-800/80 hover:bg-indigo-600/20 border border-slate-700/80 hover:border-indigo-500/40 text-[11px] text-indigo-300 hover:text-white transition-all flex items-center gap-1.5 cursor-pointer"
              >
                <UserCheck className="w-3 h-3 text-indigo-400" />
                Maria Santos (1000-2000-3002)
              </button>
              {!isCredit ? (
                <button
                  type="button"
                  onClick={() => {
                    setToAccount('1000-2000-3003');
                    setRecipientName('Juan Dela Cruz (Revolving Credit)');
                  }}
                  className="px-2.5 py-1 rounded-lg bg-slate-800/80 hover:bg-purple-600/20 border border-slate-700/80 hover:border-purple-500/40 text-[11px] text-purple-300 hover:text-white transition-all flex items-center gap-1.5 cursor-pointer"
                >
                  <CreditCard className="w-3 h-3 text-purple-400" />
                  My Credit Line (1000-2000-3003)
                </button>
              ) : (
                <button
                  type="button"
                  onClick={() => {
                    setToAccount('1000-2000-3001');
                    setRecipientName('Juan Dela Cruz (Primary Savings)');
                  }}
                  className="px-2.5 py-1 rounded-lg bg-slate-800/80 hover:bg-indigo-600/20 border border-slate-700/80 hover:border-indigo-500/40 text-[11px] text-indigo-300 hover:text-white transition-all flex items-center gap-1.5 cursor-pointer"
                >
                  <Wallet className="w-3 h-3 text-indigo-400" />
                  My Savings (1000-2000-3001)
                </button>
              )}
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5 flex items-center justify-between">
                <span>Amount (PHP)</span>
                <span className="text-[11px] text-slate-400">
                  Available: <strong className="text-white font-mono">{formatPHP(balance?.available_balance)}</strong>
                </span>
              </label>
              <div className="relative">
                <span className="absolute left-3.5 top-2.5 text-sm font-mono text-slate-400 font-bold">₱</span>
                <input
                  type="text"
                  required
                  value={amountInput}
                  onChange={handleAmountChange}
                  placeholder="0.00"
                  className="w-full bg-slate-950 border border-slate-700/80 rounded-xl pl-8 pr-3.5 py-2.5 text-sm font-mono text-white font-bold placeholder:text-slate-600 focus:outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-500/40 focus:shadow-lg focus:shadow-indigo-500/10 transition-all duration-200"
                />
              </div>

              {/* Quick Amount Chips */}
              <div className="flex flex-wrap items-center gap-2 mt-2.5">
                <span className="text-[11px] font-medium text-slate-400 mr-1">Quick Add:</span>
                {[500, 1000, 5000].map((quickVal) => (
                  <button
                    key={quickVal}
                    type="button"
                    onClick={() => handleAddAmount(quickVal)}
                    className="px-3 py-1.5 rounded-xl bg-slate-800/90 hover:bg-indigo-600/30 border border-slate-700/70 hover:border-indigo-500/60 text-xs font-mono text-slate-300 hover:text-white transition-all duration-150 active:scale-95 hover:shadow-md hover:shadow-indigo-500/10"
                  >
                    +₱{quickVal.toLocaleString()}
                  </button>
                ))}
                <button
                  type="button"
                  onClick={handleSetMaxAmount}
                  className="px-3 py-1.5 rounded-xl bg-indigo-500/10 hover:bg-indigo-500/20 border border-indigo-500/30 text-xs font-mono font-semibold text-indigo-300 hover:text-indigo-200 transition-all duration-150 ml-auto active:scale-95 hover:shadow-md hover:shadow-indigo-500/10"
                >
                  Transfer MAX
                </button>
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Note / Purpose <span className="text-slate-500 font-normal">(Optional)</span>
              </label>
              <input
                type="text"
                value={memo}
                onChange={(e) => setMemo(e.target.value)}
                placeholder="What is this transfer for? (e.g. Allowance, Rent, Groceries)"
                className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder:text-slate-600 focus:outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-500/40 focus:shadow-lg focus:shadow-indigo-500/10 transition-all duration-200"
              />
            </div>

            <div className="pt-2">
              <button
                type="submit"
                className="w-full py-4 rounded-2xl font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-all duration-200 shadow-xl bg-gradient-to-r from-indigo-600 via-indigo-500 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white shadow-indigo-600/30 hover:shadow-indigo-500/50 hover:shadow-2xl active:scale-[0.99]"
              >
                <Send className="w-4 h-4" />
                Review &amp; Send Money
              </button>
            </div>

            <p className="text-center text-[11px] text-slate-500 flex items-center justify-center gap-1.5 pt-1">
              <ShieldCheck className="w-3.5 h-3.5 text-indigo-400/80" />
              Secured with 256-bit bank-grade encryption
            </p>
          </form>
        </div>
      )}

      {/* TAB 2: Clean Customer Activity Table with Search & Filter */}
      {/* TAB 2: Clean Customer Activity Table with Search, Date Filter, Status Filter & CSV Export */}
      {activeTab === 'history' && (
        <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-xl space-y-4">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
            <div>
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <FileText className="w-4 h-4 text-indigo-400" />
                Transaction Statement
              </h3>
              <p className="text-xs text-slate-400 mt-0.5">Click any entry to view, print, or download its official receipt</p>
            </div>

            {/* Quick Export Statement Button */}
            {(() => {
              const now = new Date();
              const filteredForExport = mockState.transfers.filter((tx) => {
                const query = searchQuery.toLowerCase().trim();
                const matchesSearch =
                  !query ||
                  tx.recipient_name?.toLowerCase().includes(query) ||
                  tx.to_account_id?.toLowerCase().includes(query) ||
                  tx.id?.toLowerCase().includes(query);
                const matchesStatus =
                  statusFilter === 'ALL' || tx.status === statusFilter;
                const isFrom = (tx.from_account_id || '').trim();
                let matchesAccount = true;
                if (accountFilter === '1000-2000-3001') {
                  matchesAccount = isFrom.includes('3001') || isFrom === 'A2001';
                } else if (accountFilter === '1000-2000-3003') {
                  matchesAccount = isFrom.includes('3003') || isFrom === 'A2003';
                }
                const txDate = new Date(tx.created_at);
                let matchesDate = true;
                if (dateFilter === 'TODAY') {
                  matchesDate = txDate.toDateString() === now.toDateString();
                } else if (dateFilter === 'MONTH') {
                  matchesDate =
                    txDate.getMonth() === now.getMonth() &&
                    txDate.getFullYear() === now.getFullYear();
                }
                return matchesSearch && matchesStatus && matchesAccount && matchesDate;
              });

              return (
                <button
                  type="button"
                  onClick={() => handleExportCSV(filteredForExport)}
                  title="Download filtered transactions as CSV statement"
                  className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-slate-800/90 hover:bg-slate-700 text-slate-300 hover:text-white border border-slate-700/80 text-xs font-medium transition-all shadow-sm active:scale-95 self-start md:self-auto cursor-pointer"
                >
                  <Download className="w-3.5 h-3.5 text-indigo-400" />
                  <span>Export Statement (CSV)</span>
                </button>
              );
            })()}
          </div>

          {/* Search Bar & Filter Controls Row */}
          <div className="grid grid-cols-1 md:grid-cols-12 gap-3 pt-1">
            {/* Search Box */}
            <div className="relative md:col-span-4">
              <Search className="w-4 h-4 absolute left-3.5 top-2.5 text-slate-400" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search by recipient, account, or ref..."
                className="w-full bg-slate-950/80 border border-slate-800 rounded-xl pl-10 pr-4 py-2 text-xs text-white placeholder:text-slate-600 focus:outline-none focus:border-indigo-400 focus:ring-1 focus:ring-indigo-500/30 transition-all"
              />
            </div>

            {/* Account Filter Pills */}
            <div className="md:col-span-3 flex items-center gap-1 bg-slate-950/80 p-1 rounded-xl border border-slate-800/90">
              <CreditCard className="w-3.5 h-3.5 text-slate-500 ml-1.5 mr-0.5 shrink-0" />
              {[
                { id: 'ALL', label: 'All' },
                { id: '1000-2000-3001', label: 'Savings' },
                { id: '1000-2000-3003', label: 'Credit' },
              ].map((pill) => (
                <button
                  key={pill.id}
                  type="button"
                  onClick={() => setAccountFilter(pill.id)}
                  className={`flex-1 py-1 rounded-lg text-[10px] font-semibold transition-all cursor-pointer ${
                    accountFilter === pill.id
                      ? 'bg-indigo-600 text-white shadow-sm shadow-indigo-600/30'
                      : 'text-slate-400 hover:text-white'
                  }`}
                >
                  {pill.label}
                </button>
              ))}
            </div>

            {/* Date Filter Pills */}
            <div className="md:col-span-3 flex items-center gap-1 bg-slate-950/80 p-1 rounded-xl border border-slate-800/90">
              <Calendar className="w-3.5 h-3.5 text-slate-500 ml-1.5 mr-0.5 shrink-0" />
              {[
                { id: 'ALL', label: 'All Dates' },
                { id: 'TODAY', label: 'Today' },
                { id: 'MONTH', label: 'Month' },
              ].map((pill) => (
                <button
                  key={pill.id}
                  type="button"
                  onClick={() => setDateFilter(pill.id)}
                  className={`flex-1 py-1 rounded-lg text-[10px] font-semibold transition-all cursor-pointer ${
                    dateFilter === pill.id
                      ? 'bg-indigo-600 text-white shadow-sm shadow-indigo-600/30'
                      : 'text-slate-400 hover:text-white'
                  }`}
                >
                  {pill.label}
                </button>
              ))}
            </div>

            {/* Status Filter Pills */}
            <div className="md:col-span-2 flex items-center gap-1 bg-slate-950/80 p-1 rounded-xl border border-slate-800/90">
              <Filter className="w-3.5 h-3.5 text-slate-500 ml-1.5 mr-0.5 shrink-0" />
              {[
                { id: 'ALL', label: 'All' },
                { id: 'SETTLED', label: 'Completed' },
                { id: 'PENDING_APPROVAL', label: 'Review' },
              ].map((pill) => (
                <button
                  key={pill.id}
                  type="button"
                  onClick={() => setStatusFilter(pill.id)}
                  className={`flex-1 py-1 rounded-lg text-[10px] font-semibold transition-all cursor-pointer ${
                    statusFilter === pill.id
                      ? 'bg-indigo-600 text-white shadow-sm shadow-indigo-600/30'
                      : 'text-slate-400 hover:text-white'
                  }`}
                >
                  {pill.label}
                </button>
              ))}
            </div>
          </div>

          {/* Filtered Transactions List */}
          {(() => {
            const now = new Date();
            const filteredTransfers = mockState.transfers.filter((tx) => {
              const query = searchQuery.toLowerCase().trim();
              const matchesSearch =
                !query ||
                tx.recipient_name?.toLowerCase().includes(query) ||
                tx.to_account_id?.toLowerCase().includes(query) ||
                tx.id?.toLowerCase().includes(query);
              const matchesStatus =
                statusFilter === 'ALL' || tx.status === statusFilter;
              const isFrom = (tx.from_account_id || '').trim();
              let matchesAccount = true;
              if (accountFilter === '1000-2000-3001') {
                matchesAccount = isFrom.includes('3001') || isFrom === 'A2001';
              } else if (accountFilter === '1000-2000-3003') {
                matchesAccount = isFrom.includes('3003') || isFrom === 'A2003';
              }
              const txDate = new Date(tx.created_at);
              let matchesDate = true;
              if (dateFilter === 'TODAY') {
                matchesDate = txDate.toDateString() === now.toDateString();
              } else if (dateFilter === 'MONTH') {
                matchesDate =
                  txDate.getMonth() === now.getMonth() &&
                  txDate.getFullYear() === now.getFullYear();
              }
              return matchesSearch && matchesStatus && matchesAccount && matchesDate;
            });

            if (filteredTransfers.length === 0) {
              return (
                <div className="text-center py-10 border border-dashed border-slate-800 rounded-2xl bg-slate-950/30 space-y-2">
                  <p className="text-xs text-slate-400">No transactions match your search or filter.</p>
                  {(searchQuery || statusFilter !== 'ALL' || dateFilter !== 'ALL' || accountFilter !== 'ALL') && (
                    <button
                      type="button"
                      onClick={() => {
                        setSearchQuery('');
                        setStatusFilter('ALL');
                        setDateFilter('ALL');
                        setAccountFilter('ALL');
                      }}
                      className="inline-flex items-center gap-1 text-[11px] text-indigo-400 hover:text-indigo-300 font-semibold cursor-pointer"
                    >
                      <RotateCcw className="w-3 h-3" /> Reset Filters
                    </button>
                  )}
                </div>
              );
            }

            return (
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs">
                  <thead className="border-b border-slate-800 text-slate-400 font-semibold uppercase text-[10px] tracking-wider">
                    <tr>
                      <th className="pb-3">Reference No.</th>
                      <th className="pb-3">Recipient</th>
                      <th className="pb-3">Amount</th>
                      <th className="pb-3">Status</th>
                      <th className="pb-3 text-right">Date &amp; Time</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/60">
                    {filteredTransfers.map((tx) => {
                      const isIncoming = tx.direction === 'INCOMING' || (tx.from_account_id || '').includes('9999') || (tx.recipient_name || '').includes('Payroll');
                      return (
                        <tr
                          key={tx.id}
                          onClick={() => handleViewReceipt(tx)}
                          title="Click to view transaction details and official receipt"
                          className="hover:bg-slate-800/60 cursor-pointer transition-colors group"
                        >
                          <td className="py-3.5 font-mono text-indigo-400 font-semibold">
                            <div className="flex items-center gap-1.5">
                              <Receipt className="w-3.5 h-3.5 text-slate-500 group-hover:text-indigo-400 transition-colors" />
                              <span>{tx.id}</span>
                            </div>
                            <div className="mt-1">
                              {isIncoming ? (
                                <span className="inline-flex items-center gap-1 text-[9px] font-sans font-semibold px-1.5 py-0.5 rounded bg-emerald-500/10 text-emerald-300 border border-emerald-500/20">
                                  <ArrowUpRight className="w-2.5 h-2.5 rotate-180 text-emerald-400" /> Payroll Credit
                                </span>
                              ) : (tx.from_account_id || '').includes('3003') || tx.from_account_id === 'A2003' ? (
                                <span className="inline-flex items-center gap-1 text-[9px] font-sans font-semibold px-1.5 py-0.5 rounded bg-purple-500/10 text-purple-300 border border-purple-500/20">
                                  <CreditCard className="w-2.5 h-2.5" /> Credit Line
                                </span>
                              ) : (
                                <span className="inline-flex items-center gap-1 text-[9px] font-sans font-semibold px-1.5 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                                  <Wallet className="w-2.5 h-2.5" /> Savings
                                </span>
                              )}
                            </div>
                          </td>
                          <td className="py-3.5">
                            <p className="font-semibold text-white group-hover:text-indigo-200 transition-colors">
                              {tx.recipient_name}
                            </p>
                            <p className="text-[10px] font-mono text-slate-400">
                              {isIncoming ? `From: ${tx.from_account_id}` : tx.to_account_id}
                            </p>
                          </td>
                          <td className="py-3.5 font-mono font-bold">
                            {isIncoming ? (
                              <span className="text-emerald-400 inline-flex items-center gap-1 font-bold">
                                <span className="text-xs">↙</span> +{formatPHP(tx.amount)}
                              </span>
                            ) : (
                              <span className="text-slate-100 inline-flex items-center gap-1 font-bold">
                                <span className="text-xs text-slate-400">↗</span> -{formatPHP(tx.amount)}
                              </span>
                            )}
                          </td>
                        <td className="py-3.5">
                          <span
                            className={`inline-flex items-center justify-center w-[140px] py-1 rounded-full text-[10px] font-semibold whitespace-nowrap border tracking-wide ${
                              tx.status === 'SETTLED'
                                ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                                : tx.status === 'PENDING_APPROVAL'
                                ? 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                                : 'bg-rose-500/10 text-rose-400 border-rose-500/20'
                            }`}
                          >
                            <span
                              className={`w-1.5 h-1.5 rounded-full mr-1.5 shrink-0 ${
                                tx.status === 'SETTLED'
                                  ? 'bg-emerald-400'
                                  : tx.status === 'PENDING_APPROVAL'
                                  ? 'bg-amber-400 animate-pulse'
                                  : 'bg-rose-400'
                              }`}
                            />
                            {tx.status === 'SETTLED' ? 'Completed' : tx.status === 'PENDING_APPROVAL' ? 'Pending Verification' : 'Cancelled'}
                          </span>
                        </td>
                        <td className="py-3.5 text-slate-400 text-[11px] text-right">
                          {new Date(tx.created_at).toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' })}{' '}
                          {new Date(tx.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                        </td>
                      </tr>
                    );
                  })}
                  </tbody>
                </table>
              </div>
            );
          })()}
        </div>
      )}

      {/* TAB 3: Customer Profile & KYC Details (Oracle XE USERS Schema) */}
      {activeTab === 'profile' && (
        <CustomerProfile showToast={showToast} activeAccountId={activeAccountId} onSwitchAccount={handleSelectAccount} />
      )}

      {/* 1. Transfer Review & Confirmation Modal */}
      {isConfirmModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700/80 rounded-3xl max-w-lg w-full p-6 sm:p-7 shadow-2xl space-y-5 relative">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400">
                  <ShieldCheck className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white tracking-tight">Review Transfer Details</h3>
                  <p className="text-xs text-slate-400">Verify recipient information before confirming</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setIsConfirmModalOpen(false)}
                className="text-slate-400 hover:text-white p-1.5 rounded-xl hover:bg-slate-800 transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Transfer Summary Card */}
            <div className="bg-slate-950/80 border border-slate-800 rounded-2xl p-4 space-y-3 text-xs">
              <div className="flex justify-between items-center py-1 border-b border-slate-800/60">
                <span className="text-slate-400">Recipient</span>
                <div className="text-right">
                  <span className="font-bold text-white block">{recipientName}</span>
                  <span className="font-mono text-[11px] text-slate-400">{toAccount}</span>
                </div>
              </div>

              <div className="flex justify-between items-center py-1 border-b border-slate-800/60">
                <span className="text-slate-400">From Account</span>
                <div className="text-right">
                  <span className="font-semibold text-slate-200 block">{user?.name || 'Juan Dela Cruz'}</span>
                  <span className="font-mono text-[11px] text-slate-400">{balance?.account_id || '1000-2000-3001'}</span>
                </div>
              </div>

              <div className="flex justify-between items-center py-1 border-b border-slate-800/60">
                <span className="text-slate-400">Transfer Amount</span>
                <span className="font-mono font-bold text-white text-sm">{formatPHP(numericAmount)}</span>
              </div>

              <div className="flex justify-between items-center py-1 border-b border-slate-800/60">
                <span className="text-slate-400">Transfer Fee</span>
                <span className="font-mono font-semibold text-emerald-400">₱ 0.00 (FREE)</span>
              </div>

              <div className="flex justify-between items-center py-1 border-b border-slate-800/60">
                <span className="text-slate-400">Purpose / Note</span>
                <span className="text-slate-200 italic">{memo || 'Fund Transfer'}</span>
              </div>

              <div className="flex justify-between items-center pt-2">
                <span className="font-semibold text-white">Total Amount to Deduct</span>
                <span className="font-mono font-bold text-indigo-400 text-base">{formatPHP(numericAmount)}</span>
              </div>
            </div>

            {/* High Value Warning if > ₱50k */}
            {numericAmount > THRESHOLDS.STP_MAX && (
              <div className="bg-amber-500/10 border border-amber-500/30 rounded-xl p-3.5 flex items-start gap-3">
                <AlertCircle className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
                <p className="text-[11px] text-amber-300/90 leading-relaxed">
                  <strong>Notice:</strong> This transfer exceeds ₱50,000.00. It will be routed for bank manager dual-control review, and the funds will be placed <strong>On Hold</strong> until verified.
                </p>
              </div>
            )}

            {/* Modal Actions */}
            <div className="flex items-center gap-3 pt-2">
              <button
                type="button"
                onClick={() => setIsConfirmModalOpen(false)}
                disabled={isSubmitting}
                className="w-1/3 py-3 rounded-xl border border-slate-700 bg-slate-800/60 hover:bg-slate-800 text-xs font-semibold text-slate-300 hover:text-white transition-all"
              >
                Back / Edit
              </button>
              <button
                type="button"
                onClick={handleExecuteTransfer}
                disabled={isSubmitting}
                className={`w-2/3 py-3 rounded-xl font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-all shadow-lg ${
                  isSubmitting
                    ? 'bg-slate-800 text-slate-500 cursor-not-allowed'
                    : 'bg-indigo-600 hover:bg-indigo-500 text-white shadow-indigo-600/30'
                }`}
              >
                {isSubmitting ? 'Sending...' : 'Confirm & Send Money 🔒'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 2. On-Screen Digital Receipt / Success Slip Modal */}
      {receiptData && (
        <div 
          onClick={(e) => {
            if (e.target === e.currentTarget) setReceiptData(null);
          }}
          className="fixed inset-0 z-50 bg-black/85 backdrop-blur-md flex items-center justify-center p-4 animate-in fade-in duration-200"
        >
          <div 
            id="printable-receipt"
            className="bg-slate-900 border border-slate-700/90 rounded-3xl max-w-md w-full p-6 sm:p-8 shadow-2xl relative overflow-hidden animate-in zoom-in-95 duration-200"
          >
            {/* Top decorative gradient bar */}
            <div className="no-print absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-emerald-400 via-indigo-500 to-purple-500" />

            {/* Print-Only Bank Header */}
            <div className="hidden print:block text-center border-b pb-3 mb-3">
              <h2 className="text-base font-bold uppercase tracking-wider print-text-dark">CAPSTONE CORE RETAIL BANK</h2>
              <p className="text-[11px] print-text-muted">Official Electronic Funds Transfer Confirmation Slip</p>
            </div>

            {/* Close 'X' Button */}
            <button
              type="button"
              onClick={() => setReceiptData(null)}
              aria-label="Close Receipt Slip"
              className="no-print absolute top-4 right-4 z-10 p-2 rounded-full bg-slate-800/80 hover:bg-slate-700 text-slate-400 hover:text-white border border-slate-700/80 transition-all active:scale-95 shadow-md focus:outline-none focus:ring-2 focus:ring-indigo-500 cursor-pointer"
            >
              <X className="w-4 h-4" />
            </button>

            {/* Perforated ticket circular notches */}
            <div className="no-print absolute -left-3 top-[236px] w-6 h-6 rounded-full bg-slate-950 border-r border-slate-700/90 pointer-events-none" />
            <div className="no-print absolute -right-3 top-[236px] w-6 h-6 rounded-full bg-slate-950 border-l border-slate-700/90 pointer-events-none" />

            {/* Header Icon with Animated Ripple */}
            <div className="text-center pt-2 pb-5 border-b border-dashed border-slate-800">
              <div className="relative w-16 h-16 mx-auto mb-3 flex items-center justify-center">
                {!receiptData.isHighValue && (
                  <span className="no-print absolute inset-0 rounded-full bg-emerald-400/20 animate-ping duration-1000 pointer-events-none" />
                )}
                <div className="relative w-16 h-16 rounded-full bg-emerald-500/10 border-2 border-emerald-500/30 flex items-center justify-center text-emerald-400 shadow-xl shadow-emerald-500/20">
                  {receiptData.isHighValue ? (
                    <Clock className="w-8 h-8 text-amber-400 animate-pulse" />
                  ) : (
                    <CheckCircle2 className="w-8 h-8" />
                  )}
                </div>
              </div>

              <h3 className="text-xl font-bold text-white tracking-tight print-text-dark">
                {receiptData.isHighValue ? 'Transfer Submitted' : 'Transfer Successful!'}
              </h3>
              <p className="text-xs text-slate-400 mt-1 print-text-muted">
                {receiptData.isHighValue
                  ? 'Under Verification: Awaiting Bank Manager Approval'
                  : 'Funds have been securely transferred'}
              </p>

              <div className="mt-4 font-mono font-black text-3xl text-white tracking-tight print-text-dark">
                -{formatPHP(receiptData.amount)}
              </div>
            </div>

            {/* Receipt Details Body */}
            <div className="py-5 space-y-3 text-xs border-b border-dashed border-slate-800">
              <div className="flex justify-between items-center py-0.5">
                <span className="text-slate-400 print-text-muted">Reference Number</span>
                <div className="flex items-center gap-1.5 font-mono text-indigo-400 font-bold bg-indigo-500/10 px-2 py-0.5 rounded-lg border border-indigo-500/20">
                  <span className="print-text-dark">{receiptData.refNumber}</span>
                  <button
                    type="button"
                    onClick={() => {
                      if (navigator.clipboard) {
                        navigator.clipboard.writeText(receiptData.refNumber);
                        setReceiptCopied(true);
                        setTimeout(() => setReceiptCopied(false), 2000);
                      }
                    }}
                    title="Copy Reference"
                    className="no-print p-1 hover:bg-slate-800 rounded text-slate-400 hover:text-white transition-colors cursor-pointer"
                  >
                    {receiptCopied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                  </button>
                </div>
              </div>

              <div className="flex justify-between items-center py-0.5">
                <span className="text-slate-400 print-text-muted">Date &amp; Time</span>
                <span className="text-slate-300 font-mono print-text-dark">
                  {receiptData.timestamp.toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' })}{' '}
                  &bull;{' '}
                  {receiptData.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </span>
              </div>

              <div className="flex justify-between items-center py-0.5">
                <span className="text-slate-400 print-text-muted">Sent To</span>
                <div className="text-right">
                  <span className="font-semibold text-white block print-text-dark">{receiptData.recipientName}</span>
                  <span className="text-[11px] font-mono text-slate-400 print-text-muted">{receiptData.toAccount}</span>
                </div>
              </div>

              <div className="flex justify-between items-center py-0.5">
                <span className="text-slate-400 print-text-muted">Sent From</span>
                <div className="text-right">
                  <span className="text-slate-300 block print-text-dark">{receiptData.senderName}</span>
                  <span className="text-[11px] font-mono text-slate-400 print-text-muted">{receiptData.fromAccount}</span>
                </div>
              </div>

              <div className="flex justify-between items-center py-0.5">
                <span className="text-slate-400 print-text-muted">Transfer Fee</span>
                <span className="font-mono text-emerald-400 font-semibold print-text-dark">₱ 0.00 (Waived)</span>
              </div>

              {receiptData.memo && (
                <div className="flex justify-between items-center py-0.5">
                  <span className="text-slate-400 print-text-muted">Note</span>
                  <span className="text-slate-300 italic print-text-dark">{receiptData.memo}</span>
                </div>
              )}

              <div className="flex justify-between items-center py-0.5">
                <span className="text-slate-400 print-text-muted">Status</span>
                <span
                  className={`px-2.5 py-0.5 rounded-full text-[10px] font-semibold border ${
                    receiptData.isHighValue
                      ? 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                      : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                  }`}
                >
                  {receiptData.isHighValue ? 'PENDING VERIFICATION' : 'COMPLETED'}
                </span>
              </div>
            </div>

            {/* Print-Only Footer Notice */}
            <div className="hidden print:block text-center pt-3 text-[9px] print-text-muted">
              Certified compliant with BSP Circular 1033 standards &bull; Capstone FSE Core Ledger
            </div>

            {/* Modal Actions */}
            <div className="no-print space-y-2.5 pt-5">
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={handleDownloadReceipt}
                  title="Download receipt slip as text file"
                  className="flex-1 py-2.5 rounded-xl border border-slate-700 bg-slate-800/80 hover:bg-slate-700 text-xs font-semibold text-slate-200 hover:text-white flex items-center justify-center gap-1.5 transition-all active:scale-[0.99] shadow-md cursor-pointer"
                >
                  <Download className="w-3.5 h-3.5 text-indigo-400" />
                  Download (.txt)
                </button>

                <button
                  type="button"
                  onClick={() => window.print()}
                  title="Print or save receipt as PDF"
                  className="flex-1 py-2.5 rounded-xl border border-slate-700 bg-slate-800/80 hover:bg-slate-700 text-xs font-semibold text-slate-200 hover:text-white flex items-center justify-center gap-1.5 transition-all active:scale-[0.99] shadow-md cursor-pointer"
                >
                  <Printer className="w-3.5 h-3.5 text-slate-400" />
                  Print / Save PDF
                </button>
              </div>

              <button
                type="button"
                onClick={() => setReceiptData(null)}
                className="w-full py-3 rounded-xl bg-gradient-to-r from-indigo-600 via-indigo-500 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white text-xs font-bold uppercase tracking-wider transition-all duration-200 shadow-xl shadow-indigo-600/30 hover:shadow-indigo-500/50 active:scale-[0.99] cursor-pointer"
              >
                Done / Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
