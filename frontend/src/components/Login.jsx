import React, { useState } from 'react';
import { 
  Landmark, 
  Lock, 
  Mail, 
  Eye, 
  EyeOff, 
  LogIn, 
  AlertCircle, 
  CheckCircle2, 
  ShieldCheck,
  Sparkles
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export default function Login({ onLoginSuccess }) {
  const { login, isLoading } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Demo accounts for fast autofill during evaluation & live defense
  const demoAccounts = [
    {
      label: 'Juan (Customer)',
      role: 'Maker',
      email: 'juan.dc@email.com',
      password: 'password123',
      color: 'hover:border-indigo-500/50 hover:bg-indigo-500/10 text-indigo-300'
    },
    {
      label: 'Beatriz (L1 Checker)',
      role: 'Manager L1',
      email: 'beatriz.ocampo@bank.com',
      password: 'password123',
      color: 'hover:border-amber-500/50 hover:bg-amber-500/10 text-amber-300'
    },
    {
      label: 'Carlos (L2 Approver)',
      role: 'Senior Manager L2',
      email: 'carlos.mendoza@bank.com',
      password: 'password123',
      color: 'hover:border-emerald-500/50 hover:bg-emerald-500/10 text-emerald-300'
    },
    {
      label: 'Diana (Auditor)',
      role: 'Compliance',
      email: 'diana.admin@bank.com',
      password: 'password123',
      color: 'hover:border-rose-500/50 hover:bg-rose-500/10 text-rose-300'
    }
  ];

  const handleAutofill = (acc) => {
    setEmail(acc.email);
    setPassword(acc.password);
    setErrorMsg('');
  };

  const handleSubmit = async (e) => {
    e?.preventDefault();
    if (!email.trim()) {
      setErrorMsg('Please enter your corporate email or assigned username.');
      return;
    }
    setErrorMsg('');
    setIsSubmitting(true);
    try {
      const res = await login(email.trim(), password || 'password123');
      if (res?.success) {
        onLoginSuccess?.();
      } else {
        setErrorMsg(res?.error || 'Authentication rejected by security gateway.');
      }
    } catch (_) {
      setErrorMsg('Network error connecting to authentication service.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col justify-center items-center p-4 sm:p-6 font-sans selection:bg-indigo-500 selection:text-white relative overflow-hidden">
      {/* Ambient Lighting & Glows */}
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[550px] h-[550px] bg-gradient-to-tr from-indigo-600/10 via-purple-600/10 to-emerald-600/10 blur-3xl pointer-events-none rounded-full" />
      <div className="absolute bottom-10 right-10 w-80 h-80 bg-amber-500/5 blur-3xl pointer-events-none rounded-full" />

      <div className="max-w-md w-full mx-auto space-y-6 relative z-10">
        {/* Bank Brand Header */}
        <div className="text-center space-y-2">
          <div className="inline-flex p-3.5 bg-gradient-to-br from-indigo-500 via-indigo-600 to-indigo-700 rounded-2xl shadow-xl shadow-indigo-500/25 border border-indigo-400/30">
            <Landmark className="w-8 h-8 text-white" />
          </div>
          <div>
            <div className="inline-flex items-center gap-2">
              <h1 className="text-2xl font-bold text-white tracking-tight">
                EastWest Retail Core
              </h1>
              <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold bg-emerald-500/15 text-emerald-400 border border-emerald-500/30">
                v1.0-PROD
              </span>
            </div>
            <p className="text-xs text-slate-400 mt-1">
              Role-Based Access Control &bull; BSP Circular 808 Gateway
            </p>
          </div>
        </div>

        {/* Enterprise Bank Sign-In Card */}
        <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-6 sm:p-8 shadow-2xl backdrop-blur-xl space-y-6">
          <div className="space-y-1">
            <h2 className="text-lg font-bold text-white flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-indigo-400" />
              Operator Sign-In
            </h2>
            <p className="text-xs text-slate-400">
              Enter your banking credentials to open your designated role workstation.
            </p>
          </div>

          {errorMsg && (
            <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-300 text-xs flex items-start gap-2 animate-fadeIn">
              <AlertCircle className="w-4 h-4 shrink-0 mt-0.5 text-rose-400" />
              <span>{errorMsg}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Email / Username Field */}
            <div>
              <label className="block text-[11px] font-semibold text-slate-300 uppercase tracking-wider mb-1.5">
                Username or Corporate Email
              </label>
              <div className="relative">
                <Mail className="w-4 h-4 text-slate-500 absolute left-3.5 top-3" />
                <input
                  type="text"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="e.g. juan.dc@email.com or beatriz"
                  autoComplete="username"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-10 pr-3.5 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 transition-all"
                />
              </div>
            </div>

            {/* Password Field with Eye Toggle */}
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label className="block text-[11px] font-semibold text-slate-300 uppercase tracking-wider">
                  Password / Security Token
                </label>
                <span className="text-[10px] text-slate-500 font-mono">
                  Default: password123
                </span>
              </div>
              <div className="relative">
                <Lock className="w-4 h-4 text-slate-500 absolute left-3.5 top-3" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter password"
                  autoComplete="current-password"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-10 pr-10 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 transition-all font-mono"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-2.5 text-slate-500 hover:text-slate-300 p-0.5 rounded cursor-pointer transition-colors"
                  title={showPassword ? 'Hide password' : 'Show password'}
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={isSubmitting || isLoading}
              className="w-full py-3 rounded-xl text-xs font-bold bg-indigo-600 hover:bg-indigo-500 active:scale-[0.99] text-white shadow-lg shadow-indigo-600/30 transition-all flex items-center justify-center gap-2 cursor-pointer mt-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <LogIn className="w-4 h-4" />
              <span>{isSubmitting || isLoading ? 'Authenticating & Verifying Role...' : 'Sign In to Workstation'}</span>
            </button>
          </form>

          {/* Discreet Demo Autofill Helper */}
          <div className="pt-4 border-t border-slate-800/80 space-y-2.5">
            <div className="flex items-center justify-between text-[11px] text-slate-400">
              <span className="flex items-center gap-1.5 font-medium text-slate-300">
                <Sparkles className="w-3.5 h-3.5 text-amber-400" />
                Demo Accounts Autofill
              </span>
              <span className="text-[10px] text-slate-500">1-click fill</span>
            </div>

            <div className="grid grid-cols-2 gap-2">
              {demoAccounts.map((acc) => (
                <button
                  key={acc.email}
                  type="button"
                  onClick={() => handleAutofill(acc)}
                  className={`px-2.5 py-2 rounded-xl text-left bg-slate-950/60 border border-slate-800/80 text-[11px] transition-all cursor-pointer ${acc.color}`}
                >
                  <p className="font-semibold leading-tight">{acc.label}</p>
                  <p className="text-[9px] text-slate-500 font-mono mt-0.5">{acc.role}</p>
                </button>
              ))}
            </div>
          </div>

          {/* Security & Audit Verification Note */}
          <div className="text-[11px] text-slate-500 space-y-1 pt-1 border-t border-slate-800/50">
            <p className="flex items-center gap-1.5 text-slate-400">
              <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
              <span>Protected by volatile in-memory JWT tokens.</span>
            </p>
            <p className="text-[10px] text-slate-500">
              Segregation of Duties strictly verified at gateway before access is granted.
            </p>
          </div>
        </div>

        {/* Regulatory Compliance Footer */}
        <div className="flex flex-wrap items-center justify-center gap-3 text-[11px] text-slate-500 text-center">
          <span>&bull; BSP Circular 808</span>
          <span>&bull; AMLC R.A. 9160 CTR</span>
          <span>&bull; SCN Append-Only Ledger</span>
        </div>
      </div>
    </div>
  );
}
