import React from 'react';
import { AlertCircle, CheckCircle2, Info, X } from 'lucide-react';

export default function Toast({ toast, onClose }) {
  if (!toast) return null;

  const isError = toast.type === 'error';
  const isWarning = toast.type === 'warning';

  return (
    <div className="fixed bottom-6 right-6 z-50 max-w-md w-full animate-slide-up">
      <div
        className={`p-4 rounded-xl border shadow-2xl backdrop-blur-md flex items-start gap-3 ${
          isError
            ? 'bg-rose-950/90 border-rose-500/40 text-rose-100 shadow-rose-950/50'
            : isWarning
            ? 'bg-amber-950/90 border-amber-500/40 text-amber-100 shadow-amber-950/50'
            : 'bg-emerald-950/90 border-emerald-500/40 text-emerald-100 shadow-emerald-950/50'
        }`}
      >
        <div className="mt-0.5 shrink-0">
          {isError ? (
            <AlertCircle className="w-5 h-5 text-rose-400" />
          ) : isWarning ? (
            <Info className="w-5 h-5 text-amber-400" />
          ) : (
            <CheckCircle2 className="w-5 h-5 text-emerald-400" />
          )}
        </div>

        <div className="flex-1 space-y-1">
          <p className="font-semibold text-sm leading-tight">{toast.title}</p>
          <p className="text-xs opacity-90 leading-relaxed">{toast.detail}</p>
          {toast.rfcInstance && (
            <p className="text-[10px] font-mono opacity-60">RFC-7807: {toast.rfcInstance}</p>
          )}
        </div>

        <button
          onClick={onClose}
          className="p-1 rounded-lg hover:bg-white/10 transition-colors shrink-0"
        >
          <X className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
}
