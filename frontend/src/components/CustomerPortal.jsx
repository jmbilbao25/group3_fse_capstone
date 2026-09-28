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
  Mail, 
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
  RotateCcw,
  Sparkles,
  PhoneCall,
  QrCode,
  PieChart,
  HelpCircle,
  TrendingUp,
  Percent,
  Layers,
  ArrowRight,
  ExternalLink
} from 'lucide-react';
import { formatPHP, parseMaskedInput, generateUUID } from '../utils/currency';
import apiClient, { mockState, THRESHOLDS } from '../services/api';
import { useAuth } from '../context/AuthContext';
import CustomerProfile from './CustomerProfile';

export default function CustomerPortal({ balance, onTransactionComplete, onSwitchAccount, showToast }) {
  const { user } = useAuth();
  
  // Navigation tabs: 'accounts' (Bento Dashboard) | 'transfer' (Send Money) | 'history' (Statement) | 'profile' (KYC)
  const [activeTab, setActiveTab] = useState('accounts');
  const [copied, setCopied] = useState(false);
  const [qrModalOpen, setQrModalOpen] = useState(false);

  // Active Account State (SAVINGS vs CREDIT)
  const isCredit = balance?.account_type === 'CREDIT' || balance?.account_id === '1000-2000-3003';
  const activeAccountId = balance?.account_id || '1000-2000-3001';

  // Eye Toggle State (Show / Hide Balance & Account Number)
  const [isBalanceVisible, setIsBalanceVisible] = useState(true);
  const [isAccountVisible, setIsAccountVisible] = useState(true);

  // Real-time Live Clock for Signature Ribbon
  const [currentTime, setCurrentTime] = useState(new Date());
  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    onTransactionComplete?.();
  }, []);

  // Search & Filter State for Activity Tab
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL'); // 'ALL' | 'SETTLED' | 'PENDING_APPROVAL'
  const [dateFilter, setDateFilter] = useState('ALL');     // 'ALL' | 'TODAY' | 'MONTH'
  const [accountFilter, setAccountFilter] = useState('ALL'); // 'ALL' | '1000-2000-3001' | '1000-2000-3003'

  // Bento Donut Chart State Filter
  const [donutAccount, setDonutAccount] = useState('ALL');
  const [donutMonth, setDonutMonth] = useState('SEP_2026');

  const handleSelectAccount = (targetAccountId) => {
    if (balance?.account_id === targetAccountId) return;
    if (onSwitchAccount) {
      onSwitchAccount(targetAccountId);
      const isTargetCredit = targetAccountId.includes('3003');
      showToast({
        type: 'info',
        title: isTargetCredit ? 'Switched to Credit Facility' : 'Switched to Primary Savings',
        detail: `Now managing ${isTargetCredit ? 'Revolving Credit Line (1000-2000-3003)' : 'Primary Deposit Account (1000-2000-3001)'}.`,
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

  const handlePayCreditOption = (mode = 'FULL') => {
    setActiveTab('transfer');
    handleSelectAccount('1000-2000-3001');
    setToAccount('1000-2000-3003');
    setRecipientName('Juan Dela Cruz (Revolving Credit)');
    const totalDue = mockState.creditAccount?.current_balance ?? (balance?.current_balance || 2000);
    const minDue = Math.max(500, Math.min(totalDue, totalDue * 0.05));
    setCreditSettlementPlan(mode);

    if (mode === 'FULL') {
      setAmountInput(totalDue.toFixed(2));
      setMemo('Credit Line Full Statement Balance Settlement');
      showToast({
        type: 'info',
        title: 'Full Settlement Pre-filled',
        detail: `Pre-filled full balance of ${formatPHP(totalDue)} from Savings to Credit Line.`,
      });
    } else if (mode === 'MIN') {
      setAmountInput(minDue.toFixed(2));
      setMemo('Credit Line Minimum Amount Due (MAD) Settlement');
      showToast({
        type: 'info',
        title: 'Minimum Due Pre-filled',
        detail: `Pre-filled minimum amount due of ${formatPHP(minDue)} to avoid late charges.`,
      });
    } else {
      setAmountInput('');
      setMemo('Credit Line Partial Payment');
      showToast({
        type: 'info',
        title: 'Credit Settlement Ready',
        detail: 'Enter your preferred custom payment amount.',
      });
    }
  };

  const handlePayCreditBalance = () => handlePayCreditOption('FULL');

  const handleViewReceipt = (tx) => {
    const isIncoming = tx.direction === 'INCOMING' || (tx.from_account_id || '').includes('9999') || (tx.recipient_name || '').includes('Payroll');
    const isCreditSettlement = (tx.id || '').startsWith('CRD-PAY') || (tx.to_account_id || '').includes('3003') || (tx.memo || '').toLowerCase().includes('credit');
    
    setReceiptData({
      refNumber: tx.id,
      fromAccount: tx.from_account_id || balance?.account_id || '1000-2000-3001',
      senderName: isIncoming ? 'Executive Corporate Payroll ACH' : (user?.name || 'Juan Dela Cruz'),
      toAccount: tx.to_account_id,
      recipientName: tx.recipient_name,
      amount: tx.amount,
      fee: 0,
      memo: tx.memo || (isIncoming ? 'Payroll Credit' : isCreditSettlement ? 'Credit Facility Settlement' : 'Fund Transfer'),
      isHighValue: tx.status === 'PENDING_APPROVAL',
      isIncoming,
      isCreditSettlement,
      settlementPlan: isCreditSettlement ? (tx.amount >= 2000 ? 'Full Statement Balance Settlement' : tx.amount >= 500 ? 'Minimum Amount Due (MAD)' : 'Partial Principal Payment') : undefined,
      priorDebt: isCreditSettlement ? 2000 : undefined,
      remainingDebt: isCreditSettlement ? Math.max(0, 2000 - tx.amount) : undefined,
      restoredCreditLimit: isCreditSettlement ? Math.min(300000, 298000 + tx.amount) : undefined,
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

    let content = '';
    if (receiptData.isCreditSettlement) {
      content = `=====================================================
            AURABANK PREMIER VAULT
     OFFICIAL CREDIT FACILITY SETTLEMENT RECEIPT
=====================================================
Reference No.  : ${receiptData.refNumber}
Date & Time    : ${dateFormatted} ${timeFormatted}
Status         : ${receiptData.isHighValue ? 'PENDING VERIFICATION (UNDER REVIEW)' : 'COMPLETED (INSTANT BOOK SETTLEMENT)'}

SETTLEMENT SUMMARY
-----------------------------------------------------
Settlement Type: ${receiptData.settlementPlan || 'Full Statement Balance Settlement'}
Amount Paid    : PHP ${receiptData.amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
Service Fee    : PHP 0.00 (FREE - INTERNAL BOOK SETTLEMENT)
Remaining Debt : PHP ${(receiptData.remainingDebt ?? 0).toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
Restored Limit : PHP ${(receiptData.restoredCreditLimit ?? 300000).toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}

FACILITY & SENDER PARTICULARS
-----------------------------------------------------
Credit Line    : ${receiptData.toAccount} (${receiptData.recipientName})
Source Account : ${receiptData.fromAccount} (${receiptData.senderName})
Purpose / Note : ${receiptData.memo || 'Credit Facility Balance Settlement'}
=====================================================
This is a computer-generated electronic receipt.
Certified compliant with BSP Circular No. 1033 
and the Truth in Lending Act standards.
=====================================================`;
    } else {
      content = `=====================================================
            AURABANK PREMIER VAULT
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
    }

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
      const isCreditContext = accountFilter === '1000-2000-3003';
      const isIncoming = tx.direction === 'INCOMING' || 
                         (tx.from_account_id || '').includes('9999') || 
                         (tx.recipient_name || '').includes('Payroll') ||
                         (isCreditContext && (tx.to_account_id || '').includes('3003'));
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
    link.download = `AuraBank_Statement_${new Date().toISOString().split('T')[0]}.csv`;
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

  // Transfer Form State
  const [toAccount, setToAccount] = useState('');
  const [recipientName, setRecipientName] = useState('');
  const [amountInput, setAmountInput] = useState('');
  const [memo, setMemo] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [currentIdempotencyKey, setCurrentIdempotencyKey] = useState(generateUUID());
  const [creditSettlementPlan, setCreditSettlementPlan] = useState('FULL');

  // Modal States
  const [isConfirmModalOpen, setIsConfirmModalOpen] = useState(false);
  const [receiptData, setReceiptData] = useState(null);
  const [receiptCopied, setReceiptCopied] = useState(false);
  
  // Customer Email OTP Verification Modal State (Replaces Maker-Checker Approval for > ₱50k)
  const [isOtpModalOpen, setIsOtpModalOpen] = useState(false);
  const [otpInput, setOtpInput] = useState('');
  const [activePendingTx, setActivePendingTx] = useState(null);
  const [dispatchedOtpCode, setDispatchedOtpCode] = useState('');
  const [isVerifyingOtp, setIsVerifyingOtp] = useState(false);

  const numericAmount = parseFloat(amountInput) || 0;

  // Pre-flight check & credit payment state variables
  const isPayingCreditLine = (toAccount || '').replace(/[\s-]/g, '').includes('3003') || (toAccount || '').toUpperCase() === 'A2003';
  const totalCreditDebt = mockState.creditAccount?.current_balance ?? 2000;
  const minimumCreditDue = Math.max(500, Math.min(totalCreditDebt, totalCreditDebt * 0.05));
  const sourceAvailable = isCredit
    ? (mockState.creditAccount?.available_balance || balance?.available_balance || 0)
    : (mockState.account?.available_balance || balance?.available_balance || 0);

  const isInsufficientSourceFunds = numericAmount > sourceAvailable;
  const projectedSourceRemaining = Math.max(0, sourceAvailable - numericAmount);
  const projectedCreditDebt = Math.max(0, totalCreditDebt - numericAmount);
  const projectedRestoredCreditLimit = Math.min(
    mockState.creditAccount?.credit_limit || 300000,
    (mockState.creditAccount?.available_balance || 298000) + numericAmount
  );

  const handleAmountChange = (e) => {
    const masked = parseMaskedInput(e.target.value, 2);
    setAmountInput(masked);
  };

  const handleAddAmount = (addVal) => {
    const current = parseFloat(amountInput) || 0;
    const nextVal = (current + addVal).toFixed(2);
    setAmountInput(nextVal);
  };

  const handleSetMaxAmount = () => {
    const maxVal = sourceAvailable.toFixed(2);
    setAmountInput(maxVal);
  };

  const handleInitiateTransfer = (e) => {
    e.preventDefault();
    if (!toAccount.trim() || !recipientName.trim()) {
      showToast({
        type: 'error',
        title: 'Missing Details',
        detail: 'Please provide both recipient account number and full name.',
      });
      return;
    }

    const myAccountClean = (balance?.account_id || '1000-2000-3001').replace(/[\s-]/g, '').toUpperCase();
    const enteredAccountClean = toAccount.trim().replace(/[\s-]/g, '').toUpperCase();
    if (myAccountClean === enteredAccountClean) {
      showToast({
        type: 'error',
        title: 'Invalid Destination Account',
        detail: 'You cannot transfer funds to your own source account.',
      });
      return;
    }

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
          title: 'Account Not Found',
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

    if (numericAmount > sourceAvailable) {
      showToast({
        type: 'error',
        title: 'Insufficient Balance',
        detail: `You have ${formatPHP(sourceAvailable)} available in source account.`,
      });
      return;
    }

    setIsConfirmModalOpen(true);
  };

  const handleExecuteTransfer = async () => {
    setIsSubmitting(true);
    try {
      const isPayingCredit = (toAccount || '').replace(/[\s-]/g, '').includes('3003') || (toAccount || '').toUpperCase() === 'A2003';
      const generatedRef = isPayingCredit
        ? 'CRD-PAY-' + Math.floor(100000 + Math.random() * 900000)
        : 'TRX-' + Math.floor(100000 + Math.random() * 900000);

      const res = await apiClient.post(
        '/transfers',
        {
          from_account_id: balance?.account_id || '1000-2000-3001',
          to_account_id: toAccount.trim(),
          recipient_name: recipientName.trim(),
          amount: numericAmount,
          currency: 'PHP',
          memo: memo.trim() || (isPayingCredit ? 'Credit Line Statement Balance Settlement' : 'Fund Transfer'),
          maker_user_id: user?.user_id || 'U1001',
        },
        {
          headers: {
            'X-Idempotency-Key': currentIdempotencyKey,
          },
        }
      );

      const isHighValue = numericAmount > THRESHOLDS.STP_MAX;
      const totalCreditDebt = mockState.creditAccount?.current_balance ?? 2000;
      const minimumCreditDue = Math.max(500, Math.min(totalCreditDebt, totalCreditDebt * 0.05));
      const projectedRestoredCreditLimit = Math.min(
        mockState.creditAccount?.credit_limit || 300000,
        (mockState.creditAccount?.available_balance || 298000) + numericAmount
      );

      if (isHighValue) {
        setIsConfirmModalOpen(false);
        const code = res?.data?.verification_code || '849201';
        setActivePendingTx({
          transferId: res?.data?.transfer_id || res?.data?.transaction_id || generatedRef,
          amount: numericAmount,
          recipientName: recipientName.trim(),
          toAccount: toAccount.trim(),
          fromAccount: balance?.account_id || '1000-2000-3001',
          memo: memo.trim() || 'High-Value Fund Transfer',
          code: code,
        });
        setDispatchedOtpCode(code);
        setOtpInput('');
        setIsOtpModalOpen(true);
        showToast({
          type: 'info',
          title: 'Verification Code Dispatched',
          detail: `Transfer exceeds ₱50k threshold. 6-digit OTP dispatched to registered email in MailHog (:8025).`,
        });
        return;
      }

      if (isPayingCredit) {
        showToast({
          type: 'success',
          title: 'Credit Settlement Successful',
          detail: `Successfully paid ${formatPHP(numericAmount)} towards your Revolving Credit Line. Available limit restored!`,
        });
      } else {
        showToast({
          type: 'success',
          title: 'Transfer Successful',
          detail: `Successfully sent ${formatPHP(numericAmount)} to ${recipientName}.`,
        });
      }

      setReceiptData({
        refNumber: res?.data?.transfer_id || res?.data?.transaction_id || generatedRef,
        fromAccount: balance?.account_id || '1000-2000-3001',
        senderName: user?.name || 'Juan Dela Cruz',
        toAccount: toAccount.trim(),
        recipientName: recipientName.trim(),
        amount: numericAmount,
        fee: 0,
        memo: memo.trim() || (isPayingCredit ? 'Credit Line Statement Balance Settlement' : 'Fund Transfer'),
        isHighValue: false,
        isEmailVerified: false,
        isCreditSettlement: isPayingCredit,
        settlementPlan: isPayingCredit
          ? (numericAmount >= totalCreditDebt ? 'Full Statement Balance Settlement' : numericAmount >= minimumCreditDue ? 'Minimum Amount Due (MAD)' : 'Partial Principal Payment')
          : undefined,
        priorDebt: isPayingCredit ? totalCreditDebt : undefined,
        remainingDebt: isPayingCredit ? Math.max(0, totalCreditDebt - numericAmount) : undefined,
        restoredCreditLimit: isPayingCredit ? projectedRestoredCreditLimit : undefined,
        timestamp: new Date(),
      });

      setIsConfirmModalOpen(false);
      setToAccount('');
      setRecipientName('');
      setAmountInput('');
      setMemo('');
      setCurrentIdempotencyKey(generateUUID());
      onTransactionComplete();
    } catch (err) {
      const problem = err.response?.data;
      showToast({
        type: 'error',
        title: problem?.title || problem?.error || 'Transfer Failed',
        detail: problem?.detail || problem?.message || 'Unable to complete transfer. Please verify recipient details and try again.',
      });
      setIsConfirmModalOpen(false);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleVerifyOtp = async (codeToVerify) => {
    const code = (codeToVerify || otpInput || '').toString().trim();
    if (!code || code.length !== 6) {
      showToast({
        type: 'error',
        title: 'Invalid Code',
        detail: 'Please enter a valid 6-digit verification code.',
      });
      return;
    }

    setIsVerifyingOtp(true);
    try {
      const res = await apiClient.post('/transfers/verify-otp', {
        transfer_id: activePendingTx?.transferId,
        otp: code,
      });

      showToast({
        type: 'success',
        title: 'Transfer Verified & Settled',
        detail: `Transfer of ${formatPHP(activePendingTx?.amount || 0)} verified via MailHog OTP and settled successfully!`,
      });

      setReceiptData({
        refNumber: activePendingTx?.transferId,
        fromAccount: activePendingTx?.fromAccount || balance?.account_id || '1000-2000-3001',
        senderName: user?.name || 'Juan Dela Cruz',
        toAccount: activePendingTx?.toAccount,
        recipientName: activePendingTx?.recipientName,
        amount: activePendingTx?.amount,
        fee: 0,
        memo: activePendingTx?.memo,
        isHighValue: true,
        isEmailVerified: true,
        timestamp: new Date(),
      });

      setIsOtpModalOpen(false);
      setActivePendingTx(null);
      setOtpInput('');
      setToAccount('');
      setRecipientName('');
      setAmountInput('');
      setMemo('');
      setCurrentIdempotencyKey(generateUUID());
      onTransactionComplete();
    } catch (err) {
      const problem = err.response?.data;
      showToast({
        type: 'error',
        title: problem?.title || 'Verification Failed',
        detail: problem?.detail || 'Incorrect verification code. Please check MailHog (:8025) and try again.',
      });
    } finally {
      setIsVerifyingOtp(false);
    }
  };

  return (
    <div className="space-y-4">
      {/* ========================================================
          1. SIGNATURE QUICK GLANCE HORIZONTAL RIBBON
          (Inspired directly by the dark top ribbon in NetTeller / European private bank layout)
         ======================================================== */}
      <div className="bg-slate-900 border border-slate-800 rounded-2xl p-4 text-white shadow-lg overflow-hidden relative">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 relative z-10">
          {/* Live Date, Time & Calendar */}
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/20 text-cyan-400 flex items-center justify-center shrink-0">
              <Calendar className="w-5 h-5 text-cyan-400" />
            </div>
            <div>
              <p className="text-[11px] font-mono uppercase tracking-wider text-cyan-400 font-semibold">
                {currentTime.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric', year: 'numeric' })}
              </p>
              <p className="text-sm font-bold font-mono text-slate-100 flex items-center gap-2">
                <span>{currentTime.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit' })} PHT</span>
                <span className="text-[10px] font-sans px-2 py-0.2 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                  REAL-TIME STP
                </span>
              </p>
            </div>
          </div>

          {/* Quick Metrics Bar */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 lg:gap-6 divide-y sm:divide-y-0 sm:divide-x divide-slate-800/80 pt-2 lg:pt-0">
            {/* Metric 1: Current/Savings Account */}
            <div className="sm:px-3 first:pl-0 pt-2 sm:pt-0">
              <span className="text-[10px] font-semibold uppercase tracking-wider text-slate-400 flex items-center gap-1">
                <Wallet className="w-3 h-3 text-cyan-400" /> Primary Savings
              </span>
              <p className="text-sm font-bold font-mono text-white mt-0.5">
                {formatVisiblePHP(mockState.account?.available_balance || 14275000)}
              </p>
              <span className="text-[9px] text-slate-400 font-mono">...3001 &bull; 1.25% p.a.</span>
            </div>

            {/* Metric 2: Credit Facility Limit */}
            <div className="sm:px-3 pt-2 sm:pt-0">
              <span className="text-[10px] font-semibold uppercase tracking-wider text-slate-400 flex items-center gap-1">
                <CreditCard className="w-3 h-3 text-purple-400" /> Credit Facility
              </span>
              <p className="text-sm font-bold font-mono text-slate-200 mt-0.5">
                {formatVisiblePHP(mockState.creditAccount?.credit_limit || 300000)}
              </p>
              <span className="text-[9px] text-slate-400 font-mono">Drawn: {formatVisiblePHP(mockState.creditAccount?.current_balance || 2000)}</span>
            </div>

            {/* Metric 3: Active Soft Holds */}
            <div className="sm:px-3 pt-2 sm:pt-0">
              <span className="text-[10px] font-semibold uppercase tracking-wider text-slate-400 flex items-center gap-1">
                <Lock className="w-3 h-3 text-amber-400" /> On Hold (Review)
              </span>
              <p className="text-sm font-bold font-mono text-amber-300 mt-0.5">
                {formatVisiblePHP(mockState.account?.held_balance || 725000)}
              </p>
              <span className="text-[9px] text-amber-400/80 font-mono">AMLA Escrow Queue</span>
            </div>

            {/* Metric 4: Solvency & Protection */}
            <div className="sm:px-3 pt-2 sm:pt-0">
              <span className="text-[10px] font-semibold uppercase tracking-wider text-slate-400 flex items-center gap-1">
                <ShieldCheck className="w-3 h-3 text-emerald-400" /> Solvency Status
              </span>
              <p className="text-xs font-bold text-emerald-300 mt-0.5 flex items-center gap-1">
                <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" /> Prime AAA
              </p>
              <span className="text-[9px] text-slate-400">PDIC Insured ₱500k</span>
            </div>
          </div>
        </div>
      </div>

      {/* ========================================================
          2. SECONDARY HORIZONTAL NAVIGATION (TABS)
         ======================================================== */}
      <div className="bg-white border border-slate-200/90 rounded-2xl px-4 py-2.5 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-1 sm:gap-2 overflow-x-auto pb-1 sm:pb-0">
          <button
            type="button"
            onClick={() => setActiveTab('accounts')}
            className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all flex items-center gap-2 cursor-pointer shrink-0 ${
              activeTab === 'accounts'
                ? 'bg-cyan-600 text-white shadow-md shadow-cyan-600/20'
                : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
            }`}
          >
            <Layers className="w-3.5 h-3.5" />
            <span>Accounts &amp; Cards</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('transfer')}
            className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all flex items-center gap-2 cursor-pointer shrink-0 ${
              activeTab === 'transfer'
                ? 'bg-cyan-600 text-white shadow-md shadow-cyan-600/20'
                : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
            }`}
          >
            <Send className="w-3.5 h-3.5" />
            <span>Transfers &amp; Payments</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('history')}
            className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all flex items-center gap-2 cursor-pointer shrink-0 ${
              activeTab === 'history'
                ? 'bg-cyan-600 text-white shadow-md shadow-cyan-600/20'
                : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
            }`}
          >
            <FileText className="w-3.5 h-3.5" />
            <span>Statement &amp; Activity</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('profile')}
            className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all flex items-center gap-2 cursor-pointer shrink-0 ${
              activeTab === 'profile'
                ? 'bg-cyan-600 text-white shadow-md shadow-cyan-600/20'
                : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
            }`}
          >
            <User className="w-3.5 h-3.5" />
            <span>Profile &amp; Security</span>
          </button>
        </div>

        {/* Global Privacy Eye Toggle */}
        <div className="flex items-center gap-2 self-end sm:self-auto text-xs text-slate-500">
          <button
            type="button"
            onClick={() => setIsBalanceVisible(!isBalanceVisible)}
            className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg hover:bg-slate-100 text-slate-600 hover:text-slate-900 transition-colors border border-slate-200 cursor-pointer"
            title={isBalanceVisible ? 'Hide Balance Digits' : 'Reveal Balance Digits'}
          >
            {isBalanceVisible ? <Eye className="w-3.5 h-3.5 text-cyan-600" /> : <EyeOff className="w-3.5 h-3.5 text-slate-400" />}
            <span className="text-[11px] font-semibold">{isBalanceVisible ? 'Hide Figures' : 'Show Figures'}</span>
          </button>
        </div>
      </div>

      {/* ========================================================
          3. MAIN LAYOUT: TWO COLUMNS (Sidebar 280px + Content Bento)
         ======================================================== */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-5 items-start">
        
        {/* ========================================================
            LEFT SIDEBAR (Col span 3.5 / ~280px)
            (Favourites, Featured Promo Banner, Need Help 24/7)
           ======================================================== */}
        <div className="lg:col-span-3 space-y-4">
          
          {/* Favourites Card */}
          <div className="bg-white border border-slate-200/90 rounded-2xl p-4 shadow-sm space-y-2">
            <h4 className="text-xs font-bold uppercase tracking-wider text-slate-500 px-1 pb-1 border-b border-slate-100">
              Favourites &amp; Actions
            </h4>
            <div className="space-y-1">
              <button
                type="button"
                onClick={() => setActiveTab('accounts')}
                className={`w-full text-left px-3 py-2 rounded-xl text-xs font-semibold flex items-center justify-between transition-all cursor-pointer ${
                  activeTab === 'accounts' ? 'bg-cyan-50 text-cyan-800' : 'text-slate-700 hover:bg-slate-50'
                }`}
              >
                <span className="flex items-center gap-2">
                  <Wallet className="w-3.5 h-3.5 text-cyan-600" /> My Accounts
                </span>
                <ChevronRight className="w-3 h-3 text-slate-400" />
              </button>

              <button
                type="button"
                onClick={() => setActiveTab('transfer')}
                className={`w-full text-left px-3 py-2 rounded-xl text-xs font-semibold flex items-center justify-between transition-all cursor-pointer ${
                  activeTab === 'transfer' ? 'bg-cyan-50 text-cyan-800' : 'text-slate-700 hover:bg-slate-50'
                }`}
              >
                <span className="flex items-center gap-2">
                  <Send className="w-3.5 h-3.5 text-cyan-600" /> Send Money
                </span>
                <ChevronRight className="w-3 h-3 text-slate-400" />
              </button>

              <button
                type="button"
                onClick={() => setActiveTab('history')}
                className={`w-full text-left px-3 py-2 rounded-xl text-xs font-semibold flex items-center justify-between transition-all cursor-pointer ${
                  activeTab === 'history' ? 'bg-cyan-50 text-cyan-800' : 'text-slate-700 hover:bg-slate-50'
                }`}
              >
                <span className="flex items-center gap-2">
                  <FileText className="w-3.5 h-3.5 text-cyan-600" /> Transaction History
                </span>
                <ChevronRight className="w-3 h-3 text-slate-400" />
              </button>

              <button
                type="button"
                onClick={handlePayCreditBalance}
                className="w-full text-left px-3 py-2 rounded-xl text-xs font-semibold flex items-center justify-between text-purple-700 hover:bg-purple-50 transition-all cursor-pointer"
              >
                <span className="flex items-center gap-2">
                  <CreditCard className="w-3.5 h-3.5 text-purple-600" /> Pay Credit Balance
                </span>
                <span className="text-[10px] font-mono font-bold bg-purple-100 px-1.5 py-0.2 rounded text-purple-800">
                  {formatVisiblePHP(mockState.creditAccount?.current_balance || 2000)}
                </span>
              </button>

              <button
                type="button"
                onClick={() => setQrModalOpen(true)}
                className="w-full text-left px-3 py-2 rounded-xl text-xs font-semibold flex items-center justify-between text-slate-700 hover:bg-slate-50 transition-all cursor-pointer"
              >
                <span className="flex items-center gap-2">
                  <QrCode className="w-3.5 h-3.5 text-slate-600" /> Receive via QR
                </span>
                <ChevronRight className="w-3 h-3 text-slate-400" />
              </button>

              <button
                type="button"
                onClick={() => setActiveTab('profile')}
                className={`w-full text-left px-3 py-2 rounded-xl text-xs font-semibold flex items-center justify-between transition-all cursor-pointer ${
                  activeTab === 'profile' ? 'bg-cyan-50 text-cyan-800' : 'text-slate-700 hover:bg-slate-50'
                }`}
              >
                <span className="flex items-center gap-2">
                  <ShieldCheck className="w-3.5 h-3.5 text-cyan-600" /> Security &amp; OTP
                </span>
                <ChevronRight className="w-3 h-3 text-slate-400" />
              </button>
            </div>
          </div>

          {/* Featured Promo Card (AuraVisa 0% Curve Graphic Banner) */}
          <div className="bg-gradient-to-br from-cyan-600 via-cyan-700 to-slate-900 rounded-2xl p-4 text-white shadow-md relative overflow-hidden group">
            <div className="absolute -right-6 -bottom-6 w-28 h-28 rounded-full bg-cyan-400/20 blur-xl pointer-events-none group-hover:scale-125 transition-transform duration-500" />
            <div className="relative z-10 space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-[10px] font-bold uppercase tracking-widest text-cyan-200">
                  Featured Facility
                </span>
                <CreditCard className="w-4 h-4 text-cyan-200" />
              </div>
              <h4 className="text-base font-extrabold tracking-tight">
                AuraVisa Premier
              </h4>
              <p className="text-[11px] text-cyan-100/90 leading-relaxed">
                0% interest for up to 25 days. Settle statement dues instantly with zero transaction fee from your savings.
              </p>
              <div className="pt-1">
                <button
                  type="button"
                  onClick={handlePayCreditBalance}
                  className="w-full py-2 px-3 rounded-xl bg-white hover:bg-cyan-50 text-cyan-900 font-bold text-xs flex items-center justify-center gap-1.5 transition-all shadow-sm active:scale-95 cursor-pointer"
                >
                  <span>Settle Balance (₱2,000)</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          </div>

          {/* Need Help Card (24/7 Hotline + Callback) */}
          <div className="bg-white border border-slate-200/90 rounded-2xl p-4 shadow-sm space-y-3">
            <div className="flex items-center gap-2 pb-2 border-b border-slate-100">
              <div className="w-7 h-7 rounded-lg bg-cyan-50 border border-cyan-100 text-cyan-600 flex items-center justify-center">
                <PhoneCall className="w-3.5 h-3.5" />
              </div>
              <div>
                <h4 className="text-xs font-bold text-slate-900">Need Help?</h4>
                <p className="text-[10px] text-slate-500">24/7 Priority Concierge</p>
              </div>
            </div>

            <div className="space-y-1.5 text-xs">
              <div className="flex justify-between items-center text-slate-600">
                <span>Hotline:</span>
                <a href="tel:+63288881234" className="font-bold text-cyan-700 hover:underline font-mono">
                  +63 2 8888 1234
                </a>
              </div>
              <div className="flex justify-between items-center text-slate-600">
                <span>Email:</span>
                <span className="font-mono text-[11px] text-slate-700">concierge@aura.bank</span>
              </div>
            </div>

            <button
              type="button"
              onClick={() => {
                showToast({
                  type: 'info',
                  title: 'Callback Requested',
                  detail: 'A private banker will contact you on your registered phone within 5 minutes.',
                });
              }}
              className="w-full py-1.5 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 text-slate-700 text-xs font-semibold transition-all cursor-pointer"
            >
              Request Fast Callback
            </button>

            <div className="text-[10px] text-slate-400 pt-1 text-center border-t border-slate-100">
              PDIC Insured up to ₱500,000 per depositor
            </div>
          </div>
        </div>

        {/* ========================================================
            RIGHT MAIN COLUMN (Col span 8.5 / Bento Grid or Tabs)
           ======================================================== */}
        <div className="lg:col-span-9 space-y-5">
          
          {/* ========================================================
              TAB 1: ACCOUNTS & CARDS (The Bento Grid from media_1790561839892.png)
             ======================================================== */}
          {activeTab === 'accounts' && (
            <div className="space-y-5 animate-in fade-in duration-200">
              
              {/* BENTO CARD 1: CASH FLOW & SPENDING BY CATEGORY (SVG Donut Chart) */}
              <div className="bg-white border border-slate-200/90 rounded-2xl p-5 shadow-sm space-y-4">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
                  <div>
                    <h3 className="text-base font-extrabold text-slate-900 tracking-tight flex items-center gap-2">
                      <PieChart className="w-4 h-4 text-cyan-600" />
                      Spending &amp; Cash Flow by Category
                    </h3>
                    <p className="text-xs text-slate-500">Real-time ledger outflow allocation and operational cash disbursements</p>
                  </div>

                  <div className="flex items-center gap-2">
                    {/* Account Selector Filter */}
                    <select
                      value={donutAccount}
                      onChange={(e) => setDonutAccount(e.target.value)}
                      className="bg-slate-50 border border-slate-200 rounded-xl px-2.5 py-1 text-xs text-slate-700 font-semibold focus:outline-none focus:border-cyan-500 cursor-pointer"
                    >
                      <option value="ALL">All Facilities</option>
                      <option value="3001">Primary Savings (3001)</option>
                      <option value="3003">Credit Line (3003)</option>
                    </select>

                    <select
                      value={donutMonth}
                      onChange={(e) => setDonutMonth(e.target.value)}
                      className="bg-slate-50 border border-slate-200 rounded-xl px-2.5 py-1 text-xs text-slate-700 font-semibold focus:outline-none focus:border-cyan-500 cursor-pointer"
                    >
                      <option value="SEP_2026">September 2026</option>
                      <option value="AUG_2026">August 2026</option>
                    </select>
                  </div>
                </div>

                {/* SVG Donut Chart + Category Breakdown Legend */}
                <div className="grid grid-cols-1 md:grid-cols-12 gap-6 items-center">
                  {/* Left: SVG Donut Visual */}
                  <div className="md:col-span-5 flex flex-col items-center justify-center relative py-2">
                    <div className="relative w-44 h-44">
                      <svg viewBox="0 0 100 100" className="w-full h-full -rotate-90">
                        {/* Circle circumference is 2 * PI * 40 = 251.32 */}
                        {/* Slice 1: Escrow & Real Estate (50%) -> 125.66 */}
                        <circle
                          cx="50"
                          cy="50"
                          r="40"
                          fill="transparent"
                          stroke="#0284c7"
                          strokeWidth="14"
                          strokeDasharray="125.66 251.32"
                          strokeDashoffset="0"
                          className="hover:opacity-85 transition-opacity"
                        />
                        {/* Slice 2: Vendor Suppliers (37%) -> 93 */}
                        <circle
                          cx="50"
                          cy="50"
                          r="40"
                          fill="transparent"
                          stroke="#0891b2"
                          strokeWidth="14"
                          strokeDasharray="93 251.32"
                          strokeDashoffset="-125.66"
                          className="hover:opacity-85 transition-opacity"
                        />
                        {/* Slice 3: Corporate Payroll & Transfers (12%) -> 30.16 */}
                        <circle
                          cx="50"
                          cy="50"
                          r="40"
                          fill="transparent"
                          stroke="#10b981"
                          strokeWidth="14"
                          strokeDasharray="30.16 251.32"
                          strokeDashoffset="-218.66"
                          className="hover:opacity-85 transition-opacity"
                        />
                        {/* Slice 4: Other / Fees (1%) -> 2.5 */}
                        <circle
                          cx="50"
                          cy="50"
                          r="40"
                          fill="transparent"
                          stroke="#8b5cf6"
                          strokeWidth="14"
                          strokeDasharray="2.5 251.32"
                          strokeDashoffset="-248.82"
                          className="hover:opacity-85 transition-opacity"
                        />
                      </svg>
                      {/* Center metric */}
                      <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
                        <span className="text-[10px] uppercase font-bold text-slate-400">Total Outflow</span>
                        <span className="text-base font-extrabold font-mono text-slate-900 tracking-tight">₱727,000</span>
                        <span className="text-[9px] text-emerald-600 font-semibold">100% STP Tracked</span>
                      </div>
                    </div>
                  </div>

                  {/* Right: Legend Breakdown List */}
                  <div className="md:col-span-7 space-y-2.5">
                    <div className="flex items-center justify-between p-2 rounded-xl bg-slate-50 border border-slate-100 text-xs">
                      <div className="flex items-center gap-2">
                        <span className="w-3 h-3 rounded-md bg-[#0284c7]" />
                        <span className="font-semibold text-slate-800">Commercial Real Estate Escrow</span>
                      </div>
                      <div className="text-right font-mono">
                        <span className="font-bold text-slate-900">₱650,000.00</span>
                        <span className="text-[10px] text-slate-400 ml-1.5">(50%)</span>
                      </div>
                    </div>

                    <div className="flex items-center justify-between p-2 rounded-xl bg-slate-50 border border-slate-100 text-xs">
                      <div className="flex items-center gap-2">
                        <span className="w-3 h-3 rounded-md bg-[#0891b2]" />
                        <span className="font-semibold text-slate-800">Vendor &amp; Supplier Invoices</span>
                      </div>
                      <div className="text-right font-mono">
                        <span className="font-bold text-slate-900">₱75,000.00</span>
                        <span className="text-[10px] text-slate-400 ml-1.5">(37%)</span>
                      </div>
                    </div>

                    <div className="flex items-center justify-between p-2 rounded-xl bg-slate-50 border border-slate-100 text-xs">
                      <div className="flex items-center gap-2">
                        <span className="w-3 h-3 rounded-md bg-[#10b981]" />
                        <span className="font-semibold text-slate-800">Executive Payroll &amp; Fund Transfers</span>
                      </div>
                      <div className="text-right font-mono">
                        <span className="font-bold text-slate-900">₱2,000.00</span>
                        <span className="text-[10px] text-slate-400 ml-1.5">(12%)</span>
                      </div>
                    </div>

                    <div className="flex items-center justify-between p-2 rounded-xl bg-slate-50 border border-slate-100 text-xs">
                      <div className="flex items-center gap-2">
                        <span className="w-3 h-3 rounded-md bg-[#8b5cf6]" />
                        <span className="font-semibold text-slate-800">Bank Fees &amp; Operating Taxes</span>
                      </div>
                      <div className="text-right font-mono">
                        <span className="font-bold text-slate-900">₱0.00 (Waived)</span>
                        <span className="text-[10px] text-slate-400 ml-1.5">(1%)</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {/* BENTO MIDDLE ROW: (Left: My Accounts & Facilities + Right: Recent Transactions) */}
              <div className="grid grid-cols-1 md:grid-cols-12 gap-5 items-stretch">
                
                {/* MIDDLE LEFT: MY ACCOUNTS CARD (Col 6) */}
                <div className="md:col-span-6 bg-white border border-slate-200/90 rounded-2xl p-5 shadow-sm space-y-4 flex flex-col justify-between">
                  <div>
                    <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                      <div>
                        <h4 className="text-base font-extrabold text-slate-900 tracking-tight flex items-center gap-2">
                          <Wallet className="w-4 h-4 text-cyan-600" />
                          My Accounts &amp; Facilities
                        </h4>
                        <p className="text-xs text-slate-500">Deposit vaults &amp; revolving credit lines</p>
                      </div>

                      {/* Account Switcher Pills */}
                      <div className="flex items-center p-1 rounded-xl bg-slate-100 border border-slate-200 text-xs">
                        <button
                          type="button"
                          onClick={() => handleSelectAccount('1000-2000-3001')}
                          className={`px-2.5 py-1 rounded-lg font-bold transition-all cursor-pointer ${
                            !isCredit ? 'bg-white text-cyan-900 shadow-sm' : 'text-slate-500 hover:text-slate-900'
                          }`}
                        >
                          Savings
                        </button>
                        <button
                          type="button"
                          onClick={() => handleSelectAccount('1000-2000-3003')}
                          className={`px-2.5 py-1 rounded-lg font-bold transition-all cursor-pointer ${
                            isCredit ? 'bg-white text-purple-900 shadow-sm' : 'text-slate-500 hover:text-slate-900'
                          }`}
                        >
                          Credit
                        </button>
                      </div>
                    </div>

                    {/* Active Account Details Box */}
                    <div className="mt-4 p-4 rounded-xl bg-slate-50 border border-slate-200/80 space-y-3">
                      <div className="flex items-center justify-between">
                        <div>
                          <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500">
                            {isCredit ? 'Credit Line Facility' : 'Primary Deposit Account'}
                          </span>
                          <div className="flex items-center gap-2 mt-0.5">
                            <span className="text-xs font-mono font-bold text-slate-900">
                              {formatVisibleAccount(balance?.account_id)}
                            </span>
                            <button
                              type="button"
                              onClick={handleCopyAccount}
                              title="Copy account number"
                              className="text-slate-400 hover:text-slate-700 transition p-0.5 rounded cursor-pointer"
                            >
                              {copied ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
                            </button>
                          </div>
                        </div>

                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full border ${
                          isCredit ? 'bg-purple-100 text-purple-800 border-purple-200' : 'bg-emerald-100 text-emerald-800 border-emerald-200'
                        }`}>
                          {isCredit ? 'Revolving Line' : 'Prime Active'}
                        </span>
                      </div>

                      {/* Balance Display */}
                      <div className="pt-2 border-t border-slate-200/60">
                        <span className="text-[10px] font-semibold text-slate-500 uppercase tracking-wider block">
                          {isCredit ? 'Available Credit Line' : 'Available Liquid Balance'}
                        </span>
                        <div className="text-2xl font-mono font-extrabold text-slate-900 mt-0.5">
                          {formatVisiblePHP(balance?.available_balance)}
                        </div>
                        <div className="flex items-center justify-between text-[11px] text-slate-500 font-mono mt-1">
                          <span>Total Balance: {formatVisiblePHP(isCredit ? (balance?.credit_limit || 300000) : balance?.current_balance)}</span>
                          {!isCredit && <span>Held: {formatVisiblePHP(balance?.held_balance)}</span>}
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Actions for Account */}
                  <div className="pt-2 space-y-2">
                    {isCredit ? (
                      <div className="grid grid-cols-2 gap-2">
                        <button
                          type="button"
                          onClick={() => handlePayCreditOption('FULL')}
                          className="py-2 px-3 rounded-xl bg-cyan-600 hover:bg-cyan-700 text-white font-bold text-xs flex items-center justify-center gap-1.5 transition-all shadow-sm active:scale-95 cursor-pointer"
                        >
                          <CreditCard className="w-3.5 h-3.5" />
                          <span>Pay Full ({formatVisiblePHP(balance?.current_balance || 2000)})</span>
                        </button>
                        <button
                          type="button"
                          onClick={() => handlePayCreditOption('MIN')}
                          className="py-2 px-3 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs flex items-center justify-center gap-1.5 transition-all border border-slate-200 cursor-pointer"
                        >
                          <Clock className="w-3.5 h-3.5" />
                          <span>Pay Min (₱500)</span>
                        </button>
                      </div>
                    ) : (
                      <div className="grid grid-cols-2 gap-2">
                        <button
                          type="button"
                          onClick={() => setActiveTab('transfer')}
                          className="py-2 px-3 rounded-xl bg-cyan-600 hover:bg-cyan-700 text-white font-bold text-xs flex items-center justify-center gap-1.5 transition-all shadow-sm active:scale-95 cursor-pointer"
                        >
                          <Send className="w-3.5 h-3.5" />
                          <span>Transfer Money</span>
                        </button>
                        <button
                          type="button"
                          onClick={() => setQrModalOpen(true)}
                          className="py-2 px-3 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs flex items-center justify-center gap-1.5 transition-all border border-slate-200 cursor-pointer"
                        >
                          <QrCode className="w-3.5 h-3.5" />
                          <span>Receive via QR</span>
                        </button>
                      </div>
                    )}
                  </div>
                </div>

                {/* MIDDLE RIGHT: RECENT TRANSACTIONS (Col 6) */}
                <div className="md:col-span-6 bg-white border border-slate-200/90 rounded-2xl p-5 shadow-sm space-y-4 flex flex-col justify-between">
                  <div>
                    <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                      <div>
                        <h4 className="text-base font-extrabold text-slate-900 tracking-tight flex items-center gap-2">
                          <Receipt className="w-4 h-4 text-cyan-600" />
                          Last Transactions
                        </h4>
                        <p className="text-xs text-slate-500">Click any item to view official printable receipt slip</p>
                      </div>

                      <button
                        type="button"
                        onClick={() => setActiveTab('history')}
                        className="text-xs font-bold text-cyan-700 hover:text-cyan-800 flex items-center gap-1 cursor-pointer"
                      >
                        <span>View Statement</span>
                        <ChevronRight className="w-3.5 h-3.5" />
                      </button>
                    </div>

                    {/* 5 Recent Transaction Items */}
                    <div className="divide-y divide-slate-100 mt-2">
                      {mockState.transfers.slice(0, 4).map((tx) => {
                        const isIncoming = tx.direction === 'INCOMING' || (tx.from_account_id || '').includes('9999') || (tx.recipient_name || '').includes('Payroll');
                        return (
                          <div
                            key={tx.id}
                            onClick={() => handleViewReceipt(tx)}
                            className="py-2.5 flex items-center justify-between hover:bg-slate-50 rounded-xl px-2 transition-all cursor-pointer group"
                            title="Click to view and print official digital receipt slip"
                          >
                            <div className="flex items-center gap-3">
                              <div className={`w-8 h-8 rounded-lg flex items-center justify-center text-xs shrink-0 ${
                                isIncoming 
                                  ? 'bg-emerald-100 text-emerald-700' 
                                  : 'bg-slate-100 text-slate-700 group-hover:bg-cyan-50 group-hover:text-cyan-700'
                              }`}>
                                {isIncoming ? <ArrowUpRight className="w-4 h-4 rotate-180" /> : <Send className="w-3.5 h-3.5" />}
                              </div>
                              <div>
                                <p className="text-xs font-bold text-slate-900 group-hover:text-cyan-700 transition-colors">
                                  {tx.recipient_name}
                                </p>
                                <p className="text-[10px] text-slate-400 font-mono">
                                  {tx.id} &bull; {new Date(tx.created_at).toLocaleDateString([], { month: 'short', day: 'numeric' })}
                                </p>
                              </div>
                            </div>

                            <div className="text-right">
                              <p className={`text-xs font-mono font-bold ${
                                isIncoming ? 'text-emerald-600' : 'text-slate-900'
                              }`}>
                                {isIncoming ? '+' : '-'}{formatPHP(tx.amount)}
                              </p>
                              <span className={`inline-block text-[9px] font-semibold px-1.5 py-0.2 rounded-full border ${
                                tx.status === 'SETTLED'
                                  ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                                  : 'bg-amber-50 text-amber-700 border-amber-200'
                              }`}>
                                {tx.status === 'SETTLED' ? 'Completed' : 'Review'}
                              </span>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>

                  <div className="pt-2 text-center border-t border-slate-100">
                    <button
                      type="button"
                      onClick={() => setActiveTab('history')}
                      className="text-xs font-bold text-slate-600 hover:text-cyan-700 flex items-center justify-center gap-1 mx-auto cursor-pointer"
                    >
                      <span>Open Comprehensive Audit Statement</span>
                      <ArrowRight className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              </div>

              {/* BENTO BOTTOM ROW: LIQUIDITY RESERVES & ESCROW GOALS */}
              <div className="bg-white border border-slate-200/90 rounded-2xl p-5 shadow-sm space-y-4">
                <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                  <div>
                    <h4 className="text-base font-extrabold text-slate-900 tracking-tight flex items-center gap-2">
                      <TrendingUp className="w-4 h-4 text-cyan-600" />
                      Liquidity Reserves &amp; Escrow Accounts
                    </h4>
                    <p className="text-xs text-slate-500">Corporate treasury allocations and statutory reserves</p>
                  </div>
                  <span className="text-xs font-bold font-mono text-cyan-800 bg-cyan-50 px-2.5 py-1 rounded-xl border border-cyan-200">
                    Total Reserves: ₱14,275,000.00
                  </span>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  {/* Goal 1 */}
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-2">
                    <div className="flex justify-between items-center text-xs">
                      <span className="font-bold text-slate-800">Property Escrow Reserve</span>
                      <span className="font-mono font-bold text-cyan-700">65%</span>
                    </div>
                    <div className="w-full h-2 bg-slate-200 rounded-full overflow-hidden">
                      <div className="h-full bg-cyan-600 rounded-full" style={{ width: '65%' }} />
                    </div>
                    <div className="flex justify-between items-center text-[10px] text-slate-500 font-mono">
                      <span>₱650,000.00</span>
                      <span>Target: ₱1,000,000.00</span>
                    </div>
                  </div>

                  {/* Goal 2 */}
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-2">
                    <div className="flex justify-between items-center text-xs">
                      <span className="font-bold text-slate-800">Emergency Liquidity Vault</span>
                      <span className="font-mono font-bold text-emerald-600">100%</span>
                    </div>
                    <div className="w-full h-2 bg-slate-200 rounded-full overflow-hidden">
                      <div className="h-full bg-emerald-500 rounded-full" style={{ width: '100%' }} />
                    </div>
                    <div className="flex justify-between items-center text-[10px] text-slate-500 font-mono">
                      <span>₱5,000,000.00</span>
                      <span>Fully Funded &bull; Safe</span>
                    </div>
                  </div>

                  {/* Goal 3 */}
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-2">
                    <div className="flex justify-between items-center text-xs">
                      <span className="font-bold text-slate-800">Working Capital Operating Float</span>
                      <span className="font-mono font-bold text-purple-700">86%</span>
                    </div>
                    <div className="w-full h-2 bg-slate-200 rounded-full overflow-hidden">
                      <div className="h-full bg-purple-600 rounded-full" style={{ width: '86%' }} />
                    </div>
                    <div className="flex justify-between items-center text-[10px] text-slate-500 font-mono">
                      <span>₱8,625,000.00</span>
                      <span>Target: ₱10,000,000.00</span>
                    </div>
                  </div>
                </div>
              </div>

            </div>
          )}

          {/* ========================================================
              TAB 2: TRANSFERS & PAYMENTS (Send Money + Credit Settle)
             ======================================================== */}
          {activeTab === 'transfer' && (
            <div className="bg-white border border-slate-200/90 rounded-2xl p-6 shadow-sm space-y-6 max-w-3xl mx-auto animate-in fade-in duration-200">
              <div className="border-b border-slate-100 pb-4">
                <h3 className="text-lg font-extrabold text-slate-900 tracking-tight flex items-center gap-2">
                  <Send className="w-5 h-5 text-cyan-600" />
                  Initiate Fund Transfer &amp; Settlement
                </h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Transfer funds immediately via Oracle XE Real-Time STP Ledger or settle your Credit Line balance.
                </p>
              </div>

              <form onSubmit={handleInitiateTransfer} className="space-y-5">
                {/* Source Account Chooser */}
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                    Source Account (Debit From)
                  </label>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <button
                      type="button"
                      onClick={() => handleSelectAccount('1000-2000-3001')}
                      className={`p-3.5 rounded-xl border text-left transition-all cursor-pointer ${
                        !isCredit
                          ? 'bg-cyan-50/80 border-cyan-500 ring-2 ring-cyan-500/20 shadow-sm'
                          : 'bg-slate-50 border-slate-200 hover:border-slate-300'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-bold text-slate-900 flex items-center gap-1.5">
                          <Wallet className="w-3.5 h-3.5 text-cyan-600" /> Primary Savings
                        </span>
                        <span className="text-[10px] font-mono px-2 py-0.2 rounded bg-emerald-100 text-emerald-800 font-bold">
                          SAVINGS
                        </span>
                      </div>
                      <div className="mt-2 text-xs font-mono font-bold text-slate-900">
                        {formatVisiblePHP(mockState.account?.available_balance || 14275000)}
                      </div>
                      <span className="text-[10px] text-slate-500 font-mono">1000-2000-3001</span>
                    </button>

                    <button
                      type="button"
                      onClick={() => handleSelectAccount('1000-2000-3003')}
                      className={`p-3.5 rounded-xl border text-left transition-all cursor-pointer ${
                        isCredit
                          ? 'bg-purple-50/80 border-purple-500 ring-2 ring-purple-500/20 shadow-sm'
                          : 'bg-slate-50 border-slate-200 hover:border-slate-300'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-bold text-slate-900 flex items-center gap-1.5">
                          <CreditCard className="w-3.5 h-3.5 text-purple-600" /> Credit Line Facility
                        </span>
                        <span className="text-[10px] font-mono px-2 py-0.2 rounded bg-purple-100 text-purple-800 font-bold">
                          CREDIT
                        </span>
                      </div>
                      <div className="mt-2 text-xs font-mono font-bold text-slate-900">
                        {formatVisiblePHP(mockState.creditAccount?.available_balance || 298000)}
                      </div>
                      <span className="text-[10px] text-slate-500 font-mono">1000-2000-3003</span>
                    </button>
                  </div>
                </div>

                {/* Recipient Account & Recipient Name */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
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
                      placeholder="e.g. 1000-2000-3002"
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2.5 text-xs font-mono text-slate-900 placeholder:text-slate-400 focus:outline-none focus:border-cyan-600 focus:bg-white focus:ring-2 focus:ring-cyan-500/20 transition-all"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                      Recipient Full Legal Name
                    </label>
                    <input
                      type="text"
                      required
                      value={recipientName}
                      onChange={(e) => setRecipientName(e.target.value)}
                      placeholder="e.g. Maria Clara Santos"
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2.5 text-xs text-slate-900 placeholder:text-slate-400 focus:outline-none focus:border-cyan-600 focus:bg-white focus:ring-2 focus:ring-cyan-500/20 transition-all"
                    />
                  </div>
                </div>

                {/* Quick Beneficiary Shortcuts */}
                <div className="flex flex-wrap items-center gap-2 -mt-1">
                  <span className="text-[11px] font-bold text-slate-500">Quick Beneficiary:</span>
                  <button
                    type="button"
                    onClick={() => {
                      setToAccount('1000-2000-3002');
                      setRecipientName('Maria Clara Santos');
                    }}
                    className="px-2.5 py-1 rounded-lg bg-slate-100 hover:bg-cyan-50 border border-slate-200 hover:border-cyan-300 text-[11px] font-semibold text-slate-700 hover:text-cyan-800 transition-all flex items-center gap-1 cursor-pointer"
                  >
                    <UserCheck className="w-3 h-3 text-cyan-600" />
                    Maria Clara Santos (1000-2000-3002)
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setToAccount('1000-2000-3003');
                      setRecipientName('Juan Dela Cruz (Revolving Credit)');
                    }}
                    className="px-2.5 py-1 rounded-lg bg-purple-50 hover:bg-purple-100 border border-purple-200 text-[11px] font-semibold text-purple-800 transition-all flex items-center gap-1 cursor-pointer"
                  >
                    <CreditCard className="w-3 h-3 text-purple-600" />
                    My Credit Facility (1000-2000-3003)
                  </button>
                </div>

                {/* Credit Settlement Options when paying Credit Line */}
                {isPayingCreditLine && (
                  <div className="p-4 rounded-xl bg-purple-50 border border-purple-200 space-y-3 animate-in fade-in">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold text-purple-900 flex items-center gap-1.5">
                        <CreditCard className="w-4 h-4 text-purple-600" />
                        Credit Facility Settlement Plan
                      </span>
                      <span className="text-xs font-mono text-slate-700">
                        Total Statement Due: <strong className="text-purple-900 font-bold">{formatPHP(totalCreditDebt)}</strong>
                      </span>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                      <button
                        type="button"
                        onClick={() => {
                          setCreditSettlementPlan('FULL');
                          setAmountInput(totalCreditDebt.toFixed(2));
                          setMemo('Credit Line Full Statement Balance Settlement');
                        }}
                        className={`p-2.5 rounded-xl border text-left transition-all cursor-pointer ${
                          parseFloat(amountInput) === totalCreditDebt
                            ? 'bg-purple-600 text-white shadow-sm font-semibold'
                            : 'bg-white border-purple-200 text-slate-700 hover:bg-purple-100/50'
                        }`}
                      >
                        <span className="text-[10px] uppercase font-bold block">Full Balance</span>
                        <span className="text-xs font-mono font-bold block mt-0.5">{formatPHP(totalCreditDebt)}</span>
                        <span className="text-[9px] opacity-80 block">0% Interest &bull; Clean</span>
                      </button>

                      <button
                        type="button"
                        onClick={() => {
                          setCreditSettlementPlan('MIN');
                          setAmountInput(minimumCreditDue.toFixed(2));
                          setMemo('Credit Line Minimum Amount Due (MAD) Settlement');
                        }}
                        className={`p-2.5 rounded-xl border text-left transition-all cursor-pointer ${
                          parseFloat(amountInput) === minimumCreditDue
                            ? 'bg-purple-600 text-white shadow-sm font-semibold'
                            : 'bg-white border-purple-200 text-slate-700 hover:bg-purple-100/50'
                        }`}
                      >
                        <span className="text-[10px] uppercase font-bold block">Minimum Due</span>
                        <span className="text-xs font-mono font-bold block mt-0.5">{formatPHP(minimumCreditDue)}</span>
                        <span className="text-[9px] opacity-80 block">Avoids Late Charges</span>
                      </button>

                      <button
                        type="button"
                        onClick={() => {
                          setCreditSettlementPlan('CUSTOM');
                          if (parseFloat(amountInput) === totalCreditDebt || parseFloat(amountInput) === minimumCreditDue) {
                            setAmountInput('');
                          }
                          setMemo('Credit Line Partial Payment');
                        }}
                        className={`p-2.5 rounded-xl border text-left transition-all cursor-pointer ${
                          parseFloat(amountInput) !== totalCreditDebt && parseFloat(amountInput) !== minimumCreditDue && parseFloat(amountInput) > 0
                            ? 'bg-purple-600 text-white shadow-sm font-semibold'
                            : 'bg-white border-purple-200 text-slate-700 hover:bg-purple-100/50'
                        }`}
                      >
                        <span className="text-[10px] uppercase font-bold block">Custom Amount</span>
                        <span className="text-xs font-mono font-bold block mt-0.5">Any ₱ Amount</span>
                        <span className="text-[9px] opacity-80 block">Partial Paydown</span>
                      </button>
                    </div>
                  </div>
                )}

                {/* Amount Input */}
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5 flex items-center justify-between">
                    <span>Transfer Amount (PHP)</span>
                    <span className="text-[11px] text-slate-500 font-medium">
                      Available in Source: <strong className="text-slate-900 font-mono">{formatPHP(sourceAvailable)}</strong>
                    </span>
                  </label>
                  <div className="relative">
                    <span className="absolute left-3.5 top-2.5 text-sm font-mono text-slate-500 font-bold">₱</span>
                    <input
                      type="text"
                      required
                      value={amountInput}
                      onChange={handleAmountChange}
                      placeholder="0.00"
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl pl-8 pr-3.5 py-2.5 text-sm font-mono font-bold text-slate-900 placeholder:text-slate-400 focus:outline-none focus:border-cyan-600 focus:bg-white focus:ring-2 focus:ring-cyan-500/20 transition-all"
                    />
                  </div>

                  {/* Quick Add Chips */}
                  <div className="flex flex-wrap items-center gap-2 mt-2.5">
                    <span className="text-[11px] font-bold text-slate-500 mr-1">Quick Add:</span>
                    {[500, 1000, 5000].map((quickVal) => (
                      <button
                        key={quickVal}
                        type="button"
                        onClick={() => handleAddAmount(quickVal)}
                        className="px-2.5 py-1 rounded-lg bg-slate-100 hover:bg-slate-200 text-xs font-mono font-semibold text-slate-700 transition-all cursor-pointer active:scale-95"
                      >
                        +₱{quickVal.toLocaleString()}
                      </button>
                    ))}
                    <button
                      type="button"
                      onClick={handleSetMaxAmount}
                      className="px-3 py-1 rounded-lg bg-cyan-50 hover:bg-cyan-100 text-xs font-mono font-bold text-cyan-800 transition-all ml-auto cursor-pointer"
                    >
                      MAX Available
                    </button>
                  </div>
                </div>

                {/* Pre-Flight Funds Check */}
                {isInsufficientSourceFunds && (
                  <div className="p-3.5 rounded-xl bg-rose-50 border border-rose-200 flex items-start gap-2.5 text-xs text-rose-700 animate-fadeIn">
                    <AlertCircle className="w-4 h-4 text-rose-600 shrink-0 mt-0.5" />
                    <div>
                      <strong className="block font-bold">Insufficient Balance</strong>
                      <span>Source only has {formatPHP(sourceAvailable)} available. Shortfall: {formatPHP(numericAmount - sourceAvailable)}.</span>
                    </div>
                  </div>
                )}

                {/* Note / Memo */}
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                    Purpose / Note <span className="text-slate-400 font-normal">(Optional)</span>
                  </label>
                  <input
                    type="text"
                    value={memo}
                    onChange={(e) => setMemo(e.target.value)}
                    placeholder="e.g. Escrow settlement, Hardware invoice, Allowance"
                    className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2.5 text-xs text-slate-900 placeholder:text-slate-400 focus:outline-none focus:border-cyan-600 focus:bg-white focus:ring-2 focus:ring-cyan-500/20 transition-all"
                  />
                </div>

                {/* Submit Action */}
                <div className="pt-2">
                  <button
                    type="submit"
                    disabled={isSubmitting || isInsufficientSourceFunds || numericAmount <= 0}
                    className={`w-full py-3.5 rounded-xl font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-all shadow-md ${
                      isInsufficientSourceFunds || numericAmount <= 0
                        ? 'bg-slate-200 text-slate-400 cursor-not-allowed'
                        : isPayingCreditLine
                        ? 'bg-purple-600 hover:bg-purple-700 text-white shadow-purple-600/25 active:scale-[0.99] cursor-pointer'
                        : 'bg-cyan-600 hover:bg-cyan-700 text-white shadow-cyan-600/25 active:scale-[0.99] cursor-pointer'
                    }`}
                  >
                    {isPayingCreditLine ? <CreditCard className="w-4 h-4" /> : <Send className="w-4 h-4" />}
                    {isInsufficientSourceFunds
                      ? 'Insufficient Funds to Transfer'
                      : numericAmount <= 0
                      ? 'Enter Amount to Proceed'
                      : isPayingCreditLine
                      ? 'Review & Settle Credit Line 💳'
                      : 'Review & Send Funds 🔒'}
                  </button>
                </div>

                <p className="text-center text-[11px] text-slate-400 flex items-center justify-center gap-1">
                  <ShieldCheck className="w-3.5 h-3.5 text-cyan-600" />
                  Secured by Oracle 21c SCN &amp; 256-bit bank encryption &bull; Real-time STP
                </p>
              </form>
            </div>
          )}

          {/* ========================================================
              TAB 3: STATEMENT & ACTIVITY (Table, Search, Filters & CSV)
             ======================================================== */}
          {activeTab === 'history' && (
            <div className="bg-white border border-slate-200/90 rounded-2xl p-5 shadow-sm space-y-4 animate-in fade-in duration-200">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
                <div>
                  <h3 className="text-base font-extrabold text-slate-900 tracking-tight flex items-center gap-2">
                    <FileText className="w-4 h-4 text-cyan-600" />
                    Transaction Activity &amp; Audit Statement
                  </h3>
                  <p className="text-xs text-slate-500">Official immutable transaction log. Click any record to inspect and download receipt.</p>
                </div>

                {(() => {
                  const now = new Date();
                  const filteredForExport = mockState.transfers.filter((tx) => {
                    const query = searchQuery.toLowerCase().trim();
                    const matchesSearch =
                      !query ||
                      tx.recipient_name?.toLowerCase().includes(query) ||
                      tx.to_account_id?.toLowerCase().includes(query) ||
                      tx.id?.toLowerCase().includes(query);
                    const matchesStatus = statusFilter === 'ALL' || tx.status === statusFilter;
                    const isFrom = (tx.from_account_id || '').trim();
                    let matchesAccount = true;
                    if (accountFilter === '1000-2000-3001') {
                      matchesAccount = isFrom.includes('3001') || isFrom === 'A2001';
                    } else if (accountFilter === '1000-2000-3003') {
                      matchesAccount = isFrom.includes('3003') || isFrom === 'A2003' || (tx.to_account_id || '').includes('3003');
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
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-50 hover:bg-slate-100 text-slate-700 border border-slate-200 text-xs font-bold transition-all shadow-sm active:scale-95 cursor-pointer self-start sm:self-auto"
                    >
                      <Download className="w-3.5 h-3.5 text-cyan-600" />
                      <span>Download Statement (CSV)</span>
                    </button>
                  );
                })()}
              </div>

              {/* Search Bar & Filters */}
              <div className="grid grid-cols-1 md:grid-cols-12 gap-3">
                <div className="relative md:col-span-4">
                  <Search className="w-4 h-4 absolute left-3.5 top-2.5 text-slate-400" />
                  <input
                    type="text"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="Search by recipient, account, or ref..."
                    className="w-full bg-slate-50 border border-slate-200 rounded-xl pl-9 pr-3.5 py-1.5 text-xs text-slate-900 placeholder:text-slate-400 focus:outline-none focus:border-cyan-600 focus:bg-white"
                  />
                </div>

                <div className="md:col-span-3 flex items-center gap-1 bg-slate-50 p-1 rounded-xl border border-slate-200 text-xs">
                  <span className="text-[10px] font-bold text-slate-400 px-1">Account:</span>
                  {[
                    { id: 'ALL', label: 'All' },
                    { id: '1000-2000-3001', label: 'Savings' },
                    { id: '1000-2000-3003', label: 'Credit' },
                  ].map((p) => (
                    <button
                      key={p.id}
                      type="button"
                      onClick={() => setAccountFilter(p.id)}
                      className={`flex-1 py-1 rounded-lg text-[10px] font-bold transition-all cursor-pointer ${
                        accountFilter === p.id ? 'bg-cyan-600 text-white shadow-xs' : 'text-slate-600 hover:text-slate-900'
                      }`}
                    >
                      {p.label}
                    </button>
                  ))}
                </div>

                <div className="md:col-span-3 flex items-center gap-1 bg-slate-50 p-1 rounded-xl border border-slate-200 text-xs">
                  <span className="text-[10px] font-bold text-slate-400 px-1">Date:</span>
                  {[
                    { id: 'ALL', label: 'All' },
                    { id: 'TODAY', label: 'Today' },
                    { id: 'MONTH', label: 'Month' },
                  ].map((p) => (
                    <button
                      key={p.id}
                      type="button"
                      onClick={() => setDateFilter(p.id)}
                      className={`flex-1 py-1 rounded-lg text-[10px] font-bold transition-all cursor-pointer ${
                        dateFilter === p.id ? 'bg-cyan-600 text-white shadow-xs' : 'text-slate-600 hover:text-slate-900'
                      }`}
                    >
                      {p.label}
                    </button>
                  ))}
                </div>

                <div className="md:col-span-2 flex items-center gap-1 bg-slate-50 p-1 rounded-xl border border-slate-200 text-xs">
                  {[
                    { id: 'ALL', label: 'All' },
                    { id: 'SETTLED', label: 'Settled' },
                    { id: 'PENDING_APPROVAL', label: 'Review' },
                  ].map((p) => (
                    <button
                      key={p.id}
                      type="button"
                      onClick={() => setStatusFilter(p.id)}
                      className={`flex-1 py-1 rounded-lg text-[10px] font-bold transition-all cursor-pointer ${
                        statusFilter === p.id ? 'bg-cyan-600 text-white shadow-xs' : 'text-slate-600 hover:text-slate-900'
                      }`}
                    >
                      {p.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Transactions Table */}
              {(() => {
                const now = new Date();
                const filteredTransfers = mockState.transfers.filter((tx) => {
                  const query = searchQuery.toLowerCase().trim();
                  const matchesSearch =
                    !query ||
                    tx.recipient_name?.toLowerCase().includes(query) ||
                    tx.to_account_id?.toLowerCase().includes(query) ||
                    tx.id?.toLowerCase().includes(query);
                  const matchesStatus = statusFilter === 'ALL' || tx.status === statusFilter;
                  const isFrom = (tx.from_account_id || '').trim();
                  let matchesAccount = true;
                  if (accountFilter === '1000-2000-3001') {
                    matchesAccount = isFrom.includes('3001') || isFrom === 'A2001';
                  } else if (accountFilter === '1000-2000-3003') {
                    matchesAccount = isFrom.includes('3003') || isFrom === 'A2003' || (tx.to_account_id || '').includes('3003');
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
                    <div className="text-center py-12 border border-dashed border-slate-200 rounded-xl bg-slate-50 space-y-2">
                      <p className="text-xs text-slate-500">No transactions match your search criteria.</p>
                      <button
                        type="button"
                        onClick={() => {
                          setSearchQuery('');
                          setStatusFilter('ALL');
                          setDateFilter('ALL');
                          setAccountFilter('ALL');
                        }}
                        className="inline-flex items-center gap-1 text-xs text-cyan-700 hover:text-cyan-800 font-bold cursor-pointer"
                      >
                        <RotateCcw className="w-3 h-3" /> Reset Filters
                      </button>
                    </div>
                  );
                }

                return (
                  <div className="overflow-x-auto border border-slate-100 rounded-xl">
                    <table className="w-full text-left text-xs">
                      <thead className="bg-slate-50 border-b border-slate-200 text-slate-500 font-bold uppercase text-[10px] tracking-wider">
                        <tr>
                          <th className="py-2.5 px-3">Reference No.</th>
                          <th className="py-2.5 px-3">Beneficiary / Party</th>
                          <th className="py-2.5 px-3">Amount (PHP)</th>
                          <th className="py-2.5 px-3">Status</th>
                          <th className="py-2.5 px-3 text-right">Timestamp</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100">
                        {filteredTransfers.map((tx) => {
                          const isCreditContext = accountFilter === '1000-2000-3003';
                          const isPaymentToCredit = (tx.to_account_id || '').includes('3003') || tx.to_account_id === 'A2003';
                          const isIncoming = tx.direction === 'INCOMING' || 
                                             (tx.from_account_id || '').includes('9999') || 
                                             (tx.recipient_name || '').includes('Payroll') ||
                                             (isCreditContext && isPaymentToCredit);
                          return (
                            <tr
                              key={tx.id}
                              onClick={() => handleViewReceipt(tx)}
                              className="hover:bg-slate-50 cursor-pointer transition-colors group"
                              title="Click to view and print official digital receipt slip"
                            >
                              <td className="py-3 px-3 font-mono font-bold text-cyan-800">
                                <div className="flex items-center gap-1.5">
                                  <Receipt className="w-3.5 h-3.5 text-slate-400 group-hover:text-cyan-600 transition-colors" />
                                  <span>{tx.id}</span>
                                </div>
                                <div className="mt-0.5">
                                  {isIncoming ? (
                                    <span className="text-[9px] font-semibold text-emerald-700 bg-emerald-50 px-1.5 py-0.2 rounded border border-emerald-200">
                                      Payroll Credit
                                    </span>
                                  ) : (tx.from_account_id || '').includes('3003') ? (
                                    <span className="text-[9px] font-semibold text-purple-700 bg-purple-50 px-1.5 py-0.2 rounded border border-purple-200">
                                      Credit Facility
                                    </span>
                                  ) : (
                                    <span className="text-[9px] font-semibold text-cyan-700 bg-cyan-50 px-1.5 py-0.2 rounded border border-cyan-200">
                                      Savings Deposit
                                    </span>
                                  )}
                                </div>
                              </td>

                              <td className="py-3 px-3">
                                <p className="font-bold text-slate-900 group-hover:text-cyan-700 transition-colors">
                                  {isCreditContext && isPaymentToCredit ? 'Credit Settlement Payment' : tx.recipient_name}
                                </p>
                                <p className="text-[10px] font-mono text-slate-400">
                                  {isIncoming ? `From: ${tx.from_account_id}` : tx.to_account_id}
                                </p>
                              </td>

                              <td className="py-3 px-3 font-mono font-bold">
                                {isIncoming ? (
                                  <span className="text-emerald-600 font-bold">+{formatPHP(tx.amount)}</span>
                                ) : (
                                  <span className="text-slate-900 font-bold">-{formatPHP(tx.amount)}</span>
                                )}
                              </td>

                              <td className="py-3 px-3">
                                <span
                                  className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[10px] font-bold border ${
                                    tx.status === 'SETTLED'
                                      ? 'bg-emerald-50 text-emerald-800 border-emerald-200'
                                      : 'bg-amber-50 text-amber-800 border-amber-200'
                                  }`}
                                >
                                  <span
                                    className={`w-1.5 h-1.5 rounded-full mr-1.5 ${
                                      tx.status === 'SETTLED' ? 'bg-emerald-500' : 'bg-amber-500 animate-pulse'
                                    }`}
                                  />
                                  {tx.status === 'SETTLED' ? 'Completed' : tx.status === 'PENDING_VERIFICATION' ? 'Awaiting Email OTP' : 'Pending Review'}
                                </span>
                              </td>

                              <td className="py-3 px-3 text-slate-500 text-[11px] text-right font-mono">
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

          {/* ========================================================
              TAB 4: PROFILE & SECURITY (KYC Details)
             ======================================================== */}
          {activeTab === 'profile' && (
            <CustomerProfile showToast={showToast} activeAccountId={activeAccountId} onSwitchAccount={handleSelectAccount} />
          )}

        </div>
      </div>

      {/* ========================================================
          MODAL 1: TRANSFER REVIEW & CONFIRMATION MODAL
         ======================================================== */}
      {isConfirmModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 animate-in fade-in duration-200">
          <div className="bg-white border border-slate-200 rounded-3xl max-w-lg w-full p-6 shadow-2xl space-y-5 relative">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div className="flex items-center gap-3">
                <div className={`w-10 h-10 rounded-xl ${isPayingCreditLine ? 'bg-purple-100 text-purple-700' : 'bg-cyan-100 text-cyan-700'} flex items-center justify-center`}>
                  {isPayingCreditLine ? <CreditCard className="w-5 h-5" /> : <ShieldCheck className="w-5 h-5" />}
                </div>
                <div>
                  <h3 className="text-base font-extrabold text-slate-900 tracking-tight">
                    {isPayingCreditLine ? 'Review Credit Facility Settlement' : 'Review Fund Transfer'}
                  </h3>
                  <p className="text-xs text-slate-500">Verify particulars before posting immutable ledger mutation</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setIsConfirmModalOpen(false)}
                className="text-slate-400 hover:text-slate-600 p-1 rounded-lg cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="bg-slate-50 border border-slate-200/90 rounded-2xl p-4 space-y-2.5 text-xs">
              <div className="flex justify-between items-center py-1 border-b border-slate-200/60">
                <span className="text-slate-500">{isPayingCreditLine ? 'Settled Facility' : 'Recipient'}</span>
                <div className="text-right">
                  <span className="font-bold text-slate-900">{recipientName}</span>
                  <span className="font-mono text-[11px] text-slate-500 block">{toAccount}</span>
                </div>
              </div>

              <div className="flex justify-between items-center py-1 border-b border-slate-200/60">
                <span className="text-slate-500">From Source</span>
                <div className="text-right">
                  <span className="font-bold text-slate-900">{user?.name || 'Juan Dela Cruz'}</span>
                  <span className="font-mono text-[11px] text-slate-500 block">{balance?.account_id || '1000-2000-3001'}</span>
                </div>
              </div>

              <div className="flex justify-between items-center py-1 border-b border-slate-200/60">
                <span className="text-slate-500">Transfer Amount</span>
                <span className="font-mono font-extrabold text-slate-900 text-sm">{formatPHP(numericAmount)}</span>
              </div>

              <div className="flex justify-between items-center py-1 border-b border-slate-200/60">
                <span className="text-slate-500">Service Fee</span>
                <span className="font-mono font-bold text-emerald-700">₱ 0.00 (FREE &bull; WAIVED)</span>
              </div>

              {isPayingCreditLine && (
                <>
                  <div className="flex justify-between items-center py-1 border-b border-slate-200/60">
                    <span className="text-slate-500">Remaining Debt</span>
                    <span className="font-mono font-bold text-emerald-700">{formatPHP(projectedCreditDebt)}</span>
                  </div>
                  <div className="flex justify-between items-center py-1 border-b border-slate-200/60">
                    <span className="text-slate-500">Restored Available Line</span>
                    <span className="font-mono font-bold text-purple-700">{formatPHP(projectedRestoredCreditLimit)}</span>
                  </div>
                </>
              )}

              <div className="flex justify-between items-center py-1">
                <span className="text-slate-500">Memo / Note</span>
                <span className="text-slate-800 italic">{memo || (isPayingCreditLine ? 'Credit Facility Settlement' : 'Fund Transfer')}</span>
              </div>
            </div>

            {/* High Value Customer Email Verification Notice if > ₱50k */}
            {numericAmount > THRESHOLDS.STP_MAX && (
              <div className="bg-sky-50 border border-sky-200 rounded-xl p-3 flex items-start gap-2.5 text-xs text-sky-950">
                <Mail className="w-4 h-4 text-sky-600 shrink-0 mt-0.5" />
                <p>
                  <strong>Customer Email Verification Required:</strong> Transfers exceeding ₱50,000.00 require direct email OTP verification via MailHog (:8025) to verify that it's you transferring the money.
                </p>
              </div>
            )}

            <div className="flex items-center gap-3 pt-2">
              <button
                type="button"
                onClick={() => setIsConfirmModalOpen(false)}
                disabled={isSubmitting}
                className="w-1/3 py-2.5 rounded-xl border border-slate-200 text-xs font-bold text-slate-700 hover:bg-slate-50 transition cursor-pointer"
              >
                Back / Edit
              </button>
              <button
                type="button"
                onClick={handleExecuteTransfer}
                disabled={isSubmitting}
                className={`w-2/3 py-2.5 rounded-xl font-bold text-xs uppercase tracking-wider text-white transition-all shadow-md cursor-pointer ${
                  isPayingCreditLine
                    ? 'bg-purple-600 hover:bg-purple-700 shadow-purple-600/25'
                    : 'bg-cyan-600 hover:bg-cyan-700 shadow-cyan-600/25'
                }`}
              >
                {isSubmitting
                  ? 'Processing Ledger...'
                  : isPayingCreditLine
                  ? 'Confirm Settlement 💳'
                  : numericAmount > THRESHOLDS.STP_MAX
                  ? 'Proceed to Email Verification ✉️'
                  : 'Confirm & Transfer 🔒'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================
          MODAL 1B: CUSTOMER EMAIL OTP VERIFICATION MODAL (> ₱50,000.00)
          (Direct Customer Multi-Factor Verification via MailHog)
         ======================================================== */}
      {isOtpModalOpen && activePendingTx && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 animate-in fade-in duration-200">
          <div className="bg-white border border-slate-200 rounded-3xl max-w-lg w-full p-6 sm:p-7 shadow-2xl space-y-5 relative">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-sky-100 text-sky-700 flex items-center justify-center">
                  <Mail className="w-5 h-5" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-base font-extrabold text-slate-900 tracking-tight">
                      Customer Email Verification
                    </h3>
                    <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-sky-100 text-sky-800 border border-sky-200">
                      Tier 2 (&gt; ₱50,000)
                    </span>
                  </div>
                  <p className="text-xs text-slate-500">Maker-Checker superseded &bull; Direct Customer 2FA via MailHog</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => {
                  setIsOtpModalOpen(false);
                  setActivePendingTx(null);
                }}
                className="text-slate-400 hover:text-slate-600 p-1 rounded-lg cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Transfer Summary Card */}
            <div className="bg-slate-50 border border-slate-200/90 rounded-2xl p-4 space-y-2 text-xs">
              <div className="flex justify-between items-center py-1 border-b border-slate-200/60">
                <span className="text-slate-500">Transfer Reference</span>
                <span className="font-mono font-bold text-slate-900">{activePendingTx.transferId}</span>
              </div>
              <div className="flex justify-between items-center py-1 border-b border-slate-200/60">
                <span className="text-slate-500">Transfer Amount</span>
                <span className="font-mono font-extrabold text-slate-900 text-sm">{formatPHP(activePendingTx.amount)}</span>
              </div>
              <div className="flex justify-between items-center py-1 border-b border-slate-200/60">
                <span className="text-slate-500">Beneficiary</span>
                <span className="font-bold text-slate-900">{activePendingTx.recipientName} ({activePendingTx.toAccount})</span>
              </div>
              <div className="flex justify-between items-center py-1">
                <span className="text-slate-500">Customer Registered Email</span>
                <span className="font-mono font-semibold text-slate-800">juan.dc@email.com</span>
              </div>
            </div>

            {/* Instruction Banner */}
            <div className="bg-sky-50 border border-sky-200 rounded-2xl p-4 text-xs text-sky-950 space-y-2">
              <div className="flex items-center gap-2 font-bold text-sky-900">
                <ShieldCheck className="w-4 h-4 text-sky-600" />
                <span>Security Verification via MailHog Inbox</span>
              </div>
              <p className="text-slate-600 leading-relaxed">
                For transfers exceeding <strong>₱50,000.00</strong>, a 6-digit one-time security code was dispatched to your email to verify that it's you transferring the money.
              </p>
              <div className="flex flex-wrap items-center gap-2 pt-1">
                <a
                  href="http://localhost:8025"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-sky-600 text-white font-bold text-[11px] hover:bg-sky-700 transition shadow-sm cursor-pointer"
                >
                  <Mail className="w-3.5 h-3.5" />
                  <span>Open MailHog Inbox (:8025)</span>
                  <ExternalLink className="w-3 h-3" />
                </a>
                {dispatchedOtpCode && (
                  <button
                    type="button"
                    onClick={() => {
                      setOtpInput(dispatchedOtpCode);
                      showToast({
                        type: 'info',
                        title: 'OTP Auto-filled',
                        detail: `Loaded code [${dispatchedOtpCode}] from MailHog dispatch event.`,
                      });
                    }}
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white border border-sky-300 text-sky-800 font-bold text-[11px] hover:bg-sky-50 transition cursor-pointer"
                  >
                    <Sparkles className="w-3.5 h-3.5 text-amber-500" />
                    <span>Auto-Fill Code: {dispatchedOtpCode}</span>
                  </button>
                )}
              </div>
            </div>

            {/* OTP Input Form */}
            <form onSubmit={(e) => { e.preventDefault(); handleVerifyOtp(); }} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-2">
                  Enter 6-Digit Verification Code
                </label>
                <input
                  type="text"
                  maxLength={6}
                  value={otpInput}
                  onChange={(e) => setOtpInput(e.target.value.replace(/\D/g, ''))}
                  placeholder="&bull; &bull; &bull; &bull; &bull; &bull;"
                  className="w-full text-center font-mono text-2xl tracking-[0.5em] py-3 px-4 rounded-xl border border-slate-300 bg-slate-50 focus:bg-white focus:border-cyan-600 focus:ring-4 focus:ring-cyan-600/10 outline-none transition font-bold"
                  autoFocus
                />
                <p className="text-[11px] text-slate-400 mt-1 text-center font-mono">
                  Check your MailHog browser tab on port 8025 for incoming verification advice.
                </p>
              </div>

              <div className="flex items-center gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => {
                    setIsOtpModalOpen(false);
                    setActivePendingTx(null);
                  }}
                  disabled={isVerifyingOtp}
                  className="w-1/3 py-2.5 rounded-xl border border-slate-200 text-xs font-bold text-slate-700 hover:bg-slate-50 transition cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isVerifyingOtp || otpInput.trim().length !== 6}
                  className="w-2/3 py-2.5 rounded-xl font-bold text-xs uppercase tracking-wider text-white transition-all shadow-md bg-cyan-600 hover:bg-cyan-700 shadow-cyan-600/25 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                >
                  {isVerifyingOtp ? 'Verifying OTP...' : 'Verify & Settle Transfer 🚀'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ========================================================
          MODAL 2: OFFICIAL DIGITAL PERFORATED PRINTABLE RECEIPT
         ======================================================== */}
      {receiptData && (
        <div 
          onClick={(e) => {
            if (e.target === e.currentTarget) setReceiptData(null);
          }}
          className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 animate-in fade-in duration-200"
        >
          <div 
            id="printable-receipt"
            className="bg-white border border-slate-200 rounded-3xl max-w-md w-full p-6 sm:p-7 shadow-2xl relative overflow-hidden animate-in zoom-in-95 duration-200"
          >
            {/* Top decorative gradient bar */}
            <div className="no-print absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-cyan-600 via-cyan-500 to-purple-600" />

            {/* Print Header */}
            <div className="hidden print:block text-center border-b pb-3 mb-3">
              <h2 className="text-base font-bold uppercase tracking-wider print-text-dark">AURABANK PREMIER VAULT</h2>
              <p className="text-[11px] print-text-muted">Official Electronic Funds Transfer Confirmation Slip</p>
            </div>

            {/* Close 'X' Button */}
            <button
              type="button"
              onClick={() => setReceiptData(null)}
              aria-label="Close Receipt Slip"
              className="no-print absolute top-4 right-4 z-10 p-1.5 rounded-full bg-slate-100 hover:bg-slate-200 text-slate-500 hover:text-slate-800 transition cursor-pointer"
            >
              <X className="w-4 h-4" />
            </button>

            {/* Perforated ticket circular notches */}
            <div className="no-print absolute -left-3 top-[236px] w-6 h-6 rounded-full bg-slate-900/60 pointer-events-none" />
            <div className="no-print absolute -right-3 top-[236px] w-6 h-6 rounded-full bg-slate-900/60 pointer-events-none" />

            {/* Header Icon */}
            <div className="text-center pt-2 pb-4 border-b border-dashed border-slate-200">
              <div className="w-14 h-14 mx-auto mb-2 rounded-full bg-emerald-100 border border-emerald-200 text-emerald-700 flex items-center justify-center shadow-md">
                {receiptData.isHighValue && !receiptData.isEmailVerified ? (
                  <Clock className="w-7 h-7 text-amber-600 animate-pulse" />
                ) : (
                  <CheckCircle2 className="w-7 h-7 text-emerald-600" />
                )}
              </div>

              <h3 className="text-lg font-extrabold text-slate-900 tracking-tight print-text-dark">
                {receiptData.isCreditSettlement 
                  ? 'Credit Settlement Successful' 
                  : receiptData.isEmailVerified
                  ? 'Transfer Verified & Settled'
                  : receiptData.isHighValue 
                  ? 'Transfer Awaiting Verification' 
                  : 'Transfer Successful'}
              </h3>
              <p className="text-xs text-slate-500 mt-0.5 print-text-muted">
                {receiptData.isCreditSettlement
                  ? 'Funds posted & revolving credit limit restored'
                  : receiptData.isEmailVerified
                  ? 'Verified via MailHog Customer Security OTP • Settled Instantly'
                  : receiptData.isHighValue
                  ? 'Customer Verification Required (Security OTP Dispatched via MailHog)'
                  : 'Funds debited and credited via STP ledger'}
              </p>

              <div className="mt-3 font-mono font-extrabold text-2xl text-slate-900 tracking-tight print-text-dark">
                -{formatPHP(receiptData.amount)}
              </div>
            </div>

            {/* Receipt Details Body */}
            <div className="py-4 space-y-2.5 text-xs border-b border-dashed border-slate-200">
              <div className="flex justify-between items-center">
                <span className="text-slate-500 print-text-muted">Reference Number</span>
                <div className="flex items-center gap-1.5 font-mono text-cyan-800 font-bold bg-cyan-50 px-2 py-0.5 rounded border border-cyan-200">
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
                    className="no-print text-slate-400 hover:text-slate-700 cursor-pointer"
                  >
                    {receiptCopied ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
                  </button>
                </div>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-slate-500 print-text-muted">Date &amp; Time</span>
                <span className="text-slate-800 font-mono print-text-dark">
                  {receiptData.timestamp.toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' })}{' '}
                  &bull;{' '}
                  {receiptData.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </span>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-slate-500 print-text-muted">{receiptData.isCreditSettlement ? 'Settled Facility' : 'Sent To'}</span>
                <div className="text-right">
                  <span className="font-bold text-slate-900 block print-text-dark">{receiptData.recipientName}</span>
                  <span className="text-[11px] font-mono text-slate-500 print-text-muted">{receiptData.toAccount}</span>
                </div>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-slate-500 print-text-muted">{receiptData.isCreditSettlement ? 'Source Account' : 'Sent From'}</span>
                <div className="text-right">
                  <span className="font-semibold text-slate-800 block print-text-dark">{receiptData.senderName}</span>
                  <span className="text-[11px] font-mono text-slate-500 print-text-muted">{receiptData.fromAccount}</span>
                </div>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-slate-500 print-text-muted">Transaction Fee</span>
                <span className="font-mono text-emerald-700 font-bold print-text-dark">₱ 0.00 (Waived)</span>
              </div>

              {receiptData.isCreditSettlement && (
                <>
                  <div className="flex justify-between items-center">
                    <span className="text-slate-500 print-text-muted">Remaining Debt</span>
                    <span className="font-mono text-emerald-700 font-bold print-text-dark">{formatPHP(receiptData.remainingDebt ?? 0)}</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-slate-500 print-text-muted">Restored Available Credit</span>
                    <span className="font-mono text-purple-700 font-bold print-text-dark">{formatPHP(receiptData.restoredCreditLimit ?? 300000)}</span>
                  </div>
                </>
              )}

              {receiptData.memo && (
                <div className="flex justify-between items-center">
                  <span className="text-slate-500 print-text-muted">Purpose Note</span>
                  <span className="text-slate-800 italic print-text-dark">{receiptData.memo}</span>
                </div>
              )}

              <div className="flex justify-between items-center">
                <span className="text-slate-500 print-text-muted">Status</span>
                <span
                  className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${
                    receiptData.isHighValue && !receiptData.isEmailVerified
                      ? 'bg-amber-50 text-amber-800 border-amber-200'
                      : 'bg-emerald-50 text-emerald-800 border-emerald-200'
                  }`}
                >
                  {receiptData.isHighValue && !receiptData.isEmailVerified ? 'PENDING VERIFICATION' : 'COMPLETED'}
                </span>
              </div>
            </div>

            {/* Print Footer */}
            <div className="hidden print:block text-center pt-2 text-[9px] print-text-muted">
              Certified compliant with BSP Circular 1033 standards &bull; AuraBank Premier Vault Core Ledger
            </div>

            {/* Modal Actions */}
            <div className="no-print space-y-2 pt-4">
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={handleDownloadReceipt}
                  className="flex-1 py-2 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 text-xs font-bold text-slate-700 flex items-center justify-center gap-1.5 transition cursor-pointer"
                >
                  <Download className="w-3.5 h-3.5 text-cyan-600" />
                  Download (.txt)
                </button>

                <button
                  type="button"
                  onClick={() => window.print()}
                  className="flex-1 py-2 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 text-xs font-bold text-slate-700 flex items-center justify-center gap-1.5 transition cursor-pointer"
                >
                  <Printer className="w-3.5 h-3.5 text-slate-600" />
                  Print Receipt
                </button>
              </div>

              <button
                type="button"
                onClick={() => setReceiptData(null)}
                className="w-full py-2.5 rounded-xl bg-cyan-600 hover:bg-cyan-700 text-white text-xs font-bold uppercase tracking-wider transition-all shadow-md shadow-cyan-600/20 cursor-pointer"
              >
                Close Receipt
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================
          MODAL 3: RECEIVE VIA QR CODE MODAL
         ======================================================== */}
      {qrModalOpen && (
        <div 
          onClick={(e) => {
            if (e.target === e.currentTarget) setQrModalOpen(false);
          }}
          className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 animate-in fade-in duration-200"
        >
          <div className="bg-white border border-slate-200 rounded-3xl max-w-sm w-full p-6 shadow-2xl relative text-center space-y-4">
            <button
              type="button"
              onClick={() => setQrModalOpen(false)}
              className="absolute top-4 right-4 p-1 rounded-lg text-slate-400 hover:text-slate-700 cursor-pointer"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="w-12 h-12 rounded-2xl bg-cyan-50 border border-cyan-100 text-cyan-600 flex items-center justify-center mx-auto shadow-sm">
              <QrCode className="w-6 h-6" />
            </div>

            <div>
              <h3 className="text-base font-extrabold text-slate-900 tracking-tight">Receive via QR Code</h3>
              <p className="text-xs text-slate-500">Scan to transfer funds directly to this account</p>
            </div>

            {/* Simulated QR Code Graphic */}
            <div className="p-4 bg-slate-50 border border-slate-200 rounded-2xl inline-block mx-auto">
              <div className="w-44 h-44 bg-white border border-slate-200 rounded-xl p-2 flex items-center justify-center shadow-inner relative">
                {/* SVG QR Code Pattern */}
                <svg viewBox="0 0 100 100" className="w-full h-full text-slate-900">
                  <rect x="5" y="5" width="26" height="26" fill="currentColor" rx="2" />
                  <rect x="9" y="9" width="18" height="18" fill="white" rx="1" />
                  <rect x="13" y="13" width="10" height="10" fill="currentColor" rx="1" />
                  
                  <rect x="69" y="5" width="26" height="26" fill="currentColor" rx="2" />
                  <rect x="73" y="9" width="18" height="18" fill="white" rx="1" />
                  <rect x="77" y="13" width="10" height="10" fill="currentColor" rx="1" />
                  
                  <rect x="5" y="69" width="26" height="26" fill="currentColor" rx="2" />
                  <rect x="9" y="73" width="18" height="18" fill="white" rx="1" />
                  <rect x="13" y="77" width="10" height="10" fill="currentColor" rx="1" />
                  
                  {/* Decorative Dots */}
                  <rect x="38" y="10" width="8" height="8" fill="currentColor" />
                  <rect x="52" y="14" width="6" height="12" fill="currentColor" />
                  <rect x="38" y="24" width="12" height="6" fill="currentColor" />
                  <rect x="12" y="38" width="14" height="6" fill="currentColor" />
                  <rect x="30" y="38" width="8" height="8" fill="currentColor" />
                  <rect x="44" y="38" width="16" height="8" fill="currentColor" />
                  <rect x="68" y="38" width="10" height="6" fill="currentColor" />
                  <rect x="84" y="38" width="8" height="14" fill="currentColor" />
                  <rect x="12" y="50" width="10" height="10" fill="currentColor" />
                  <rect x="28" y="52" width="14" height="6" fill="currentColor" />
                  <rect x="48" y="50" width="10" height="10" fill="currentColor" />
                  <rect x="64" y="50" width="14" height="8" fill="currentColor" />
                  <rect x="38" y="68" width="8" height="12" fill="currentColor" />
                  <rect x="52" y="68" width="14" height="6" fill="currentColor" />
                  <rect x="72" y="68" width="8" height="14" fill="currentColor" />
                  <rect x="86" y="68" width="6" height="6" fill="currentColor" />
                  <rect x="38" y="84" width="12" height="8" fill="currentColor" />
                  <rect x="56" y="82" width="8" height="10" fill="currentColor" />
                  <rect x="70" y="86" width="12" height="6" fill="currentColor" />
                </svg>
                {/* Center Bank Logo */}
                <div className="absolute inset-0 m-auto w-8 h-8 rounded-lg bg-cyan-600 text-white flex items-center justify-center font-bold text-xs shadow-md">
                  A
                </div>
              </div>
            </div>

            <div className="text-xs space-y-1">
              <p className="font-bold text-slate-900">{user?.name || 'Juan Dela Cruz'}</p>
              <p className="font-mono text-cyan-800 font-bold text-sm">{balance?.account_id || '1000-2000-3001'}</p>
              <p className="text-[11px] text-slate-500">AuraBank &bull; Primary Savings Vault</p>
            </div>

            <button
              type="button"
              onClick={handleCopyAccount}
              className="w-full py-2.5 rounded-xl bg-cyan-600 hover:bg-cyan-700 text-white font-bold text-xs flex items-center justify-center gap-1.5 transition cursor-pointer shadow-md shadow-cyan-600/20"
            >
              {copied ? <Check className="w-3.5 h-3.5 text-emerald-300" /> : <Copy className="w-3.5 h-3.5" />}
              <span>{copied ? 'Account Copied to Clipboard!' : 'Copy Account Number'}</span>
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
