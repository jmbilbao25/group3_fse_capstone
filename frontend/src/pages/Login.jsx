import { useState } from 'react';
import { ArrowRight, ShieldCheck } from 'lucide-react';
import { useAuth } from '../context/Auth';
import { errorMessage } from '../lib/api';
import { Aurora, Button, ErrorNote, Logo } from '../components/ui';

const DEMO = [
  { email: 'beatriz.ocampo@bank.com', who: 'Beatriz Ocampo', role: 'Maker, onboarding' },
  { email: 'diana.admin@bank.com', who: 'Diana Vance', role: 'Checker, compliance' },
  { email: 'carlos.mendoza@bank.com', who: 'Carlos Mendoza', role: 'Maker, branch operations' },
];

const field =
  'h-12 w-full rounded-xl bg-white px-4 text-[15px] ring-1 ring-inset ring-ink-100 transition-shadow focus:outline-none focus:ring-2 focus:ring-ink placeholder:text-ink-300';

export default function Login() {
  const { login, verifyOtp } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [otp, setOtp] = useState('');
  const [challenge, setChallenge] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      if (challenge) await verifyOtp(challenge.userId, otp, email);
      else {
        const r = await login(email, password);
        if (r.status === 'MFA_REQUIRED') setChallenge(r);
      }
    } catch (err) {
      setError(err.response ? errorMessage(err) : err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="grid min-h-[100dvh] lg:grid-cols-[1.1fr_1fr]">
      <section className="relative hidden overflow-hidden lg:block">
        <Aurora />
        <div className="relative z-10 flex h-full flex-col justify-between p-12 text-white">
          <div className="flex items-center gap-3">
            <Logo size={40} />
            <span className="text-lg font-semibold">Aura Console</span>
          </div>
          <div className="max-w-md animate-rise">
            <h1 className="text-5xl font-semibold leading-[1.05] tracking-[-0.035em]">Every decision has two names on it.</h1>
            <p className="mt-5 text-lg text-white/70">
              Laya screens identities and transfers. People approve them. Maker and checker are always different staff.
            </p>
          </div>
          <p className="flex items-center gap-2 text-sm text-white/50">
            <ShieldCheck className="size-4" /> Staff access only. Activity is recorded.
          </p>
        </div>
      </section>

      <section className="flex items-center justify-center px-6 py-12">
        <form onSubmit={submit} className="w-full max-w-sm animate-rise">
          <div className="mb-8 lg:hidden">
            <Logo size={44} />
          </div>
          <h2 className="text-[28px] font-semibold tracking-[-0.03em]">{challenge ? 'Check your email' : 'Sign in'}</h2>
          <p className="mt-1.5 text-ink-500">
            {challenge ? `We sent a 6-digit code to ${challenge.maskedEmail}.` : 'Use your Aura staff account.'}
          </p>

          <div className="mt-8 space-y-3">
            {challenge ? (
              <input
                autoFocus inputMode="numeric" autoComplete="one-time-code" maxLength={6} placeholder="000000"
                value={otp} onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                className={`${field} text-center font-mono text-xl tracking-[.5em]`} aria-label="Verification code"
              />
            ) : (
              <>
                <input type="email" required autoComplete="username" placeholder="name@bank.com" value={email} onChange={(e) => setEmail(e.target.value)} className={field} aria-label="Email" />
                <input type="password" required autoComplete="current-password" placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)} className={field} aria-label="Password" />
              </>
            )}
          </div>

          {error && <div className="mt-4"><ErrorNote message={error} /></div>}

          <Button type="submit" loading={busy} className="mt-6 h-12 w-full" disabled={challenge ? otp.length !== 6 : false}>
            {challenge ? 'Verify' : 'Continue'} {!busy && <ArrowRight className="size-4" />}
          </Button>

          {challenge ? (
            <button type="button" onClick={() => { setChallenge(null); setOtp(''); }} className="mt-4 w-full text-sm text-ink-400 hover:text-ink">
              Use a different account
            </button>
          ) : (
            <div className="mt-10">
              <p className="label mb-3">Demo staff</p>
              <div className="space-y-1.5">
                {DEMO.map((d, i) => (
                  <button
                    type="button" key={d.email} style={{ animationDelay: `${120 + i * 50}ms` }}
                    onClick={() => { setEmail(d.email); setPassword('password123'); }}
                    className="flex w-full items-center justify-between rounded-xl px-3 py-2.5 text-left text-sm transition-colors hover:bg-white animate-rise"
                  >
                    <span className="font-medium">{d.who}</span>
                    <span className="text-ink-400">{d.role}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </form>
      </section>
    </div>
  );
}
