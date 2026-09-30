import React, { useState } from 'react';
import { AlertCircle, ArrowRight, Eye, EyeOff, Lock, Mail } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import Brand from './Brand';
import ThemeToggle from './ThemeToggle';
import { Button, Field, Input, Callout, cn } from '../ui';

const PERSONAS = [
  { name: 'Juan Dela Cruz', role: 'Customer', email: 'juan.dc@email.com' },
  { name: 'Diana Vance', role: 'Admin', email: 'diana.admin@bank.com' },
];

const DEMO_PASSWORD = 'password123';

export default function Login({ onLoginSuccess }) {
  const { login, isLoading } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const fill = (persona) => {
    setEmail(persona.email);
    setPassword(DEMO_PASSWORD);
    setError('');
  };

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!email.trim()) {
      setError('Enter the email address registered to your account.');
      return;
    }

    setError('');
    setSubmitting(true);

    try {
      const res = await login(email.trim(), password || DEMO_PASSWORD);
      if (res?.success) {
        onLoginSuccess?.();
      } else {
        setError(res?.error || 'That email and password combination was not recognised.');
      }
    } catch {
      setError('Could not reach the authentication service. Check your connection and try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const busy = submitting || isLoading;

  return (
    <div className="flex min-h-screen flex-col bg-canvas text-fg">
      <div className="flex items-center justify-between px-4 py-4 sm:px-6">
        <Brand />
        <ThemeToggle />
      </div>

      <div className="flex flex-1 items-start justify-center px-4 pb-10 pt-6 sm:items-center sm:pt-0">
        <div className="w-full max-w-sm">
          <h1 className="text-xl font-semibold tracking-tight text-fg">Sign in</h1>
          <p className="mt-1 text-sm text-fg-muted">
            Access your accounts, transfers, and statements.
          </p>

          <form onSubmit={handleSubmit} className="mt-6 space-y-4" noValidate>
            {error && (
              <Callout tone="voided" icon={AlertCircle} role="alert">
                {error}
              </Callout>
            )}

            <Field label="Email address" htmlFor="email">
              <Input
                id="email"
                name="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="username"
                autoFocus
                icon={Mail}
                size="lg"
              />
            </Field>

            <Field label="Password" htmlFor="password">
              <div className="relative">
                <Lock
                  className="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-fg-subtle"
                  aria-hidden="true"
                />
                <input
                  id="password"
                  name="password"
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete="current-password"
                  className={cn(
                    'h-11 w-full border border-line bg-sunken pl-9 pr-11 text-base text-fg',
                    'transition-[background-color,border-color] duration-[120ms]',
                    'placeholder:text-fg-subtle hover:border-line-strong',
                    'focus:border-accent focus:bg-surface'
                  )}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  aria-pressed={showPassword}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                  className="absolute right-0 top-0 flex h-11 w-11 items-center justify-center text-fg-subtle transition-colors hover:text-fg"
                >
                  {showPassword ? (
                    <EyeOff className="h-4 w-4" aria-hidden="true" />
                  ) : (
                    <Eye className="h-4 w-4" aria-hidden="true" />
                  )}
                </button>
              </div>
            </Field>

            <Button type="submit" variant="primary" size="lg" fullWidth loading={busy} icon={ArrowRight}>
              {busy ? 'Signing in' : 'Sign in'}
            </Button>
          </form>

          {/* Demo personas */}
          <div className="mt-8 border-t border-line pt-5">
            <div className="flex items-baseline justify-between gap-3">
              <h2 className="text-sm font-medium text-fg">Demo accounts</h2>
              <p className="text-xs text-fg-subtle">
                Password <code className="font-mono text-fg-muted">{DEMO_PASSWORD}</code>
              </p>
            </div>

            <ul className="mt-2 divide-y divide-line border border-line">
              {PERSONAS.map((persona) => (
                <li key={persona.email}>
                  <button
                    type="button"
                    onClick={() => fill(persona)}
                    className="flex w-full items-center justify-between gap-3 px-3 py-2.5 text-left transition-colors duration-[120ms] hover:bg-sunken"
                  >
                    <span className="min-w-0">
                      <span className="block truncate text-sm font-medium text-fg">
                        {persona.name}
                      </span>
                      <span className="block truncate text-xs text-fg-muted">{persona.role}</span>
                    </span>
                    <span className="shrink-0 text-xs text-accent-text">Use</span>
                  </button>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}
