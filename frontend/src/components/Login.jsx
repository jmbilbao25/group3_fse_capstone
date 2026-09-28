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
  Sparkles,
  ArrowRight
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
      label: 'Juan Dela Cruz',
      role: 'Private Client (Maker)',
      email: 'juan.dc@email.com',
      password: 'password123',
      color: 'hover:border-cyan-400 hover:bg-cyan-50/50 text-slate-800'
    },
    {
      label: 'Beatriz Ocampo',
      role: 'Operations Manager',
      email: 'beatriz.ocampo@bank.com',
      password: 'password123',
      color: 'hover:border-amber-400 hover:bg-amber-50/50 text-slate-800'
    },
    {
      label: 'Carlos Mendoza',
      role: 'Operations Manager',
      email: 'carlos.mendoza@bank.com',
      password: 'password123',
      color: 'hover:border-emerald-400 hover:bg-emerald-50/50 text-slate-800'
    },
    {
      label: 'Diana Admin',
      role: 'Compliance & Audit Vault',
      email: 'diana.admin@bank.com',
      password: 'password123',
      color: 'hover:border-slate-400 hover:bg-slate-100 text-slate-800'
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
    <div className="min-h-screen bg-slate-50 text-slate-900 flex flex-col justify-center items-center p-4 sm:p-6 font-sans selection:bg-cyan-600 selection:text-white relative overflow-hidden">
      {/* Subtle Atmospheric Gradients */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-gradient-to-b from-cyan-100/60 via-slate-100/30 to-transparent blur-3xl pointer-events-none rounded-full" />
      <div className="absolute bottom-10 right-10 w-96 h-96 bg-cyan-50/80 blur-3xl pointer-events-none rounded-full" />

      <div className="max-w-md w-full mx-auto space-y-6 relative z-10">
        {/* Bank Brand Header */}
        <div className="text-center space-y-2.5">
          <div className="inline-flex p-3.5 bg-gradient-to-br from-cyan-600 via-cyan-700 to-slate-900 rounded-2xl shadow-xl shadow-cyan-600/20 border border-cyan-500/30 text-white">
            <Landmark className="w-8 h-8 text-white" />
          </div>
          <div>
            <div className="inline-flex items-center gap-2">
              <h1 className="text-3xl font-extrabold text-slate-900 tracking-tight flex items-center">
                aura<span className="text-cyan-600">.</span>bank
              </h1>
              <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold tracking-wider bg-cyan-100 text-cyan-800 border border-cyan-200">
                PREMIER VAULT
              </span>
            </div>
            <p className="text-xs text-slate-500 mt-1 font-medium">
              Private Wealth &bull; Core Ledger Mutation Gateway &bull; Port :3000
            </p>
          </div>
        </div>

        {/* Enterprise Bank Sign-In Card */}
        <div className="bg-white border border-slate-200/90 rounded-3xl p-6 sm:p-8 shadow-xl shadow-slate-200/50 space-y-6">
          <div className="space-y-1">
            <h2 className="text-base font-bold text-slate-900 flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-cyan-600" />
              Secure Client Sign-In
            </h2>
            <p className="text-xs text-slate-500">
              Enter your banking credentials to access your designated role portal.
            </p>
          </div>

          {errorMsg && (
            <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-start gap-2 animate-fadeIn">
              <AlertCircle className="w-4 h-4 shrink-0 mt-0.5 text-rose-600" />
              <span>{errorMsg}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Email / Username Field */}
            <div>
              <label className="block text-[11px] font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Username or Corporate Email
              </label>
              <div className="relative">
                <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-3" />
                <input
                  type="text"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="e.g. juan.dc@email.com or beatriz"
                  autoComplete="username"
                  className="w-full bg-slate-50/80 border border-slate-200 rounded-xl pl-10 pr-3.5 py-2.5 text-xs text-slate-900 placeholder-slate-400 focus:outline-none focus:border-cyan-600 focus:bg-white focus:ring-2 focus:ring-cyan-500/20 transition-all"
                />
              </div>
            </div>

            {/* Password Field with Eye Toggle */}
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label className="block text-[11px] font-bold text-slate-700 uppercase tracking-wider">
                  Password / Security PIN
                </label>
                <span className="text-[10px] text-slate-400 font-mono">
                  Default: password123
                </span>
              </div>
              <div className="relative">
                <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-3" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter password"
                  autoComplete="current-password"
                  className="w-full bg-slate-50/80 border border-slate-200 rounded-xl pl-10 pr-10 py-2.5 text-xs text-slate-900 placeholder-slate-400 focus:outline-none focus:border-cyan-600 focus:bg-white focus:ring-2 focus:ring-cyan-500/20 transition-all font-mono"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-2.5 text-slate-400 hover:text-slate-600 p-0.5 rounded cursor-pointer transition-colors"
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
              className="w-full py-3 rounded-xl text-xs font-bold bg-cyan-600 hover:bg-cyan-700 active:scale-[0.99] text-white shadow-lg shadow-cyan-600/25 transition-all flex items-center justify-center gap-2 cursor-pointer mt-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <LogIn className="w-4 h-4" />
              <span>{isSubmitting || isLoading ? 'Authenticating & Verifying Role...' : 'Access Premier Workstation'}</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </form>

          {/* Discreet Demo Autofill Helper */}
          <div className="pt-4 border-t border-slate-100 space-y-2.5">
            <div className="flex items-center justify-between text-[11px] text-slate-600">
              <span className="flex items-center gap-1.5 font-bold text-slate-800">
                <Sparkles className="w-3.5 h-3.5 text-amber-500" />
                Select Persona (Instant Autofill)
              </span>
              <span className="text-[10px] text-slate-400 font-mono">1-click fill</span>
            </div>

            <div className="grid grid-cols-2 gap-2">
              {demoAccounts.map((acc) => (
                <button
                  key={acc.email}
                  type="button"
                  onClick={() => handleAutofill(acc)}
                  className={`px-3 py-2 rounded-xl text-left bg-slate-50 border border-slate-200 text-[11px] transition-all cursor-pointer ${acc.color}`}
                >
                  <p className="font-bold text-slate-900 leading-tight">{acc.label}</p>
                  <p className="text-[10px] text-slate-500 mt-0.5">{acc.role}</p>
                </button>
              ))}
            </div>
          </div>

          {/* Security & Audit Verification Note */}
          <div className="text-[11px] text-slate-500 space-y-1 pt-1 border-t border-slate-100">
            <p className="flex items-center gap-1.5 text-slate-700 font-medium">
              <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
              <span>Protected by 256-bit encryption &amp; volatile session tokens.</span>
            </p>
            <p className="text-[10px] text-slate-400">
              Segregation of Duties strictly verified at gateway before access is granted.
            </p>
          </div>
        </div>

        {/* Regulatory Compliance Footer */}
        <div className="flex flex-wrap items-center justify-center gap-3 text-[11px] text-slate-400 text-center font-medium">
          <span>&bull; BSP Circular 808</span>
          <span>&bull; AMLC R.A. 9160 CTR</span>
          <span>&bull; SCN Append-Only Ledger</span>
          <span>&bull; PDIC Insured</span>
        </div>
      </div>
    </div>
  );
}
