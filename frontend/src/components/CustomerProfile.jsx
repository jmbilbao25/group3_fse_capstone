import React, { useState, useEffect } from 'react';
import { 
  User, 
  Mail, 
  Phone, 
  Calendar, 
  ShieldCheck, 
  Lock, 
  KeyRound, 
  Edit3, 
  Save, 
  X, 
  CheckCircle2, 
  AlertCircle, 
  Clock,
  Smartphone,
  Eye,
  EyeOff,
  Landmark,
  Wallet
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { cn } from '../ui';
import Button from '../ui/Button';

export default function CustomerProfile({ showToast, activeAccountId = '1000-2000-3001' }) {
  const { user, updateUserProfile, isLoading } = useAuth();
  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  // Password / PIN modal or inline edit state
  const [showPasswordChange, setShowPasswordChange] = useState(false);
  const [showPinChange, setShowPinChange] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showNewPin, setShowNewPin] = useState(false);

  // Form state mapped to DB fields
  const [formData, setFormData] = useState({
    first_name: '',
    middle_name: '',
    last_name: '',
    email: '',
    phone_number: '',
    dob: '',
    government_id: '',
    new_password: '',
    new_pin: '',
  });

  // Initialize form data from authenticated user record
  useEffect(() => {
    if (user) {
      setFormData({
        first_name: user.first_name || '',
        middle_name: user.middle_name || '',
        last_name: user.last_name || '',
        email: user.email || '',
        phone_number: user.phone_number || '',
        dob: user.dob ? user.dob.split('T')[0] : '1990-05-14',
        government_id: user.government_id || '',
        new_password: '',
        new_pin: '',
      });
    }
  }, [user]);

  const handleInputChange = (field, value) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    setErrorMsg('');
  };

  const handleCancel = () => {
    setIsEditing(false);
    setShowPasswordChange(false);
    setShowPinChange(false);
    setErrorMsg('');
    if (user) {
      setFormData({
        first_name: user.first_name || '',
        middle_name: user.middle_name || '',
        last_name: user.last_name || '',
        email: user.email || '',
        phone_number: user.phone_number || '',
        dob: user.dob ? user.dob.split('T')[0] : '1990-05-14',
        government_id: user.government_id || '',
        new_password: '',
        new_pin: '',
      });
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    setSuccessMsg('');

    if (!formData.first_name.trim() || !formData.last_name.trim()) {
      setErrorMsg('First name and last name are required.');
      return;
    }
    if (!formData.email.trim() || !formData.email.includes('@')) {
      setErrorMsg('A valid email address is required.');
      return;
    }
    if (!formData.phone_number.trim()) {
      setErrorMsg('Phone number is required.');
      return;
    }

    if (showPasswordChange && formData.new_password) {
      if (formData.new_password.length < 8) {
        setErrorMsg('Password must be at least 8 characters long.');
        return;
      }
    }

    if (showPinChange && formData.new_pin) {
      if (!/^\d{6}$/.test(formData.new_pin)) {
        setErrorMsg('Transaction PIN must be exactly 6 numeric digits.');
        return;
      }
    }

    setIsSaving(true);
    try {
      const payload = {
        first_name: formData.first_name.trim(),
        middle_name: formData.middle_name.trim(),
        last_name: formData.last_name.trim(),
        email: formData.email.trim(),
        phone_number: formData.phone_number.trim(),
        dob: formData.dob,
        government_id: formData.government_id.trim(),
      };

      if (showPasswordChange && formData.new_password) {
        payload.password = formData.new_password;
      }
      if (showPinChange && formData.new_pin) {
        payload.pin = formData.new_pin;
      }

      await updateUserProfile(payload);
      setIsEditing(false);
      setShowPasswordChange(false);
      setShowPinChange(false);
      setFormData((prev) => ({ ...prev, new_password: '', new_pin: '' }));
      setSuccessMsg('KYC records and profile particulars updated successfully.');
      showToast?.({
        type: 'success',
        title: 'Profile Updated',
        detail: 'Your legal particulars and contact info were persisted to the ledger.',
      });
    } catch (err) {
      const detail = err.response?.data?.detail || err.response?.data?.message || err.message;
      setErrorMsg(detail || 'Failed to update profile. Please verify your inputs.');
      showToast?.({
        type: 'error',
        title: 'Update Failed',
        detail: detail || 'Could not save profile changes.',
      });
    } finally {
      setIsSaving(false);
    }
  };

  const formatFriendlyDate = (dateString) => {
    if (!dateString) return 'May 14, 1990';
    try {
      const d = new Date(dateString);
      return d.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
    } catch (_) {
      return dateString;
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-5 animate-enter">
      {/* 1. Header Banner */}
      <div className="p-5 bg-surface border border-line card-highlight flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-base font-semibold text-fg tracking-tight">
              Customer Identity &amp; Account Security
            </h2>
            <span className="px-2 py-0.5 text-2xs font-mono font-medium bg-settled-50 text-settled-700 dark:bg-settled-900/40 dark:text-settled-400 border border-settled-200 dark:border-settled-800 flex items-center gap-1">
              <ShieldCheck className="w-3 h-3 text-settled-600" />
              ID: {user?.user_id || 'U1001'} &bull; Verified
            </span>
          </div>
          <p className="text-xs text-fg-muted mt-1">
            Verified primary retail account &bull; Registered since {formatFriendlyDate(user?.created_at || '2024-01-10')}
          </p>
        </div>

        <div className="flex items-center gap-2">
          {!isEditing ? (
            <Button
              variant="secondary"
              size="sm"
              icon={Edit3}
              onClick={() => setIsEditing(true)}
            >
              Edit Details
            </Button>
          ) : (
            <Button
              variant="ghost"
              size="sm"
              icon={X}
              onClick={handleCancel}
              disabled={isSaving}
            >
              Cancel
            </Button>
          )}
        </div>
      </div>

      {/* Feedback Banners */}
      {errorMsg && (
        <div className="p-3 bg-voided-50 dark:bg-voided-900/30 border border-voided-200 dark:border-voided-800 text-voided-700 dark:text-voided-400 text-xs flex items-start gap-2">
          <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
          <span>{errorMsg}</span>
        </div>
      )}
      {successMsg && (
        <div className="p-3 bg-settled-50 dark:bg-settled-900/30 border border-settled-200 dark:border-settled-800 text-settled-700 dark:text-settled-400 text-xs flex items-start gap-2">
          <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5" />
          <span>{successMsg}</span>
        </div>
      )}

      <form onSubmit={handleSave} className="space-y-5">
        {/* 2. Personal Information */}
        <div className="p-5 bg-surface border border-line card-highlight space-y-4">
          <div className="flex items-center justify-between border-b border-line pb-3">
            <h3 className="text-xs font-semibold text-fg uppercase tracking-wider flex items-center gap-2">
              <User className="w-4 h-4 text-accent" />
              Legal Identity Particulars
            </h3>
            {isEditing && (
              <span className="text-2xs font-medium text-held-700 dark:text-held-400 bg-held-50 dark:bg-held-900/30 px-2 py-0.5 border border-held-200 dark:border-held-800">
                Editing Mode
              </span>
            )}
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-medium text-fg mb-1.5">
                First Name {isEditing && <span className="text-voided-600">*</span>}
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={formData.first_name}
                  onChange={(e) => handleInputChange('first_name', e.target.value)}
                  className="w-full bg-surface border border-line px-3 py-2 text-xs text-fg focus:outline-none focus:border-accent"
                  placeholder="First Name"
                  required
                />
              ) : (
                <div className="p-2.5 bg-sunken border border-line text-xs font-medium text-fg">
                  {user?.first_name || '—'}
                </div>
              )}
            </div>

            <div>
              <label className="block text-xs font-medium text-fg mb-1.5">
                Middle Name
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={formData.middle_name}
                  onChange={(e) => handleInputChange('middle_name', e.target.value)}
                  className="w-full bg-surface border border-line px-3 py-2 text-xs text-fg focus:outline-none focus:border-accent"
                  placeholder="Middle Name"
                />
              ) : (
                <div className="p-2.5 bg-sunken border border-line text-xs font-medium text-fg">
                  {user?.middle_name || '—'}
                </div>
              )}
            </div>

            <div>
              <label className="block text-xs font-medium text-fg mb-1.5">
                Last Name {isEditing && <span className="text-voided-600">*</span>}
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={formData.last_name}
                  onChange={(e) => handleInputChange('last_name', e.target.value)}
                  className="w-full bg-surface border border-line px-3 py-2 text-xs text-fg focus:outline-none focus:border-accent"
                  placeholder="Last Name"
                  required
                />
              ) : (
                <div className="p-2.5 bg-sunken border border-line text-xs font-medium text-fg">
                  {user?.last_name || '—'}
                </div>
              )}
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-1">
            <div>
              <label className="block text-xs font-medium text-fg mb-1.5">
                Date of Birth
              </label>
              {isEditing ? (
                <input
                  type="date"
                  value={formData.dob}
                  onChange={(e) => handleInputChange('dob', e.target.value)}
                  className="w-full bg-surface border border-line px-3 py-2 text-xs text-fg focus:outline-none focus:border-accent"
                />
              ) : (
                <div className="p-2.5 bg-sunken border border-line text-xs font-medium text-fg flex items-center gap-2">
                  <Calendar className="w-3.5 h-3.5 text-fg-subtle" />
                  <span>{formatFriendlyDate(user?.dob || '1990-05-14')}</span>
                </div>
              )}
            </div>

            <div>
              <label className="block text-xs font-medium text-fg mb-1.5">
                Government Identity Reference
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={formData.government_id}
                  onChange={(e) => handleInputChange('government_id', e.target.value)}
                  className="w-full bg-surface border border-line px-3 py-2 text-xs text-fg focus:outline-none focus:border-accent font-mono"
                  placeholder="e.g. PSA-1234-5678"
                />
              ) : (
                <div className="p-2.5 bg-sunken border border-line text-xs font-mono font-medium text-fg">
                  {user?.government_id || 'PSA-1234-5678'}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* 3. Contact & Communication */}
        <div className="p-5 bg-surface border border-line card-highlight space-y-4">
          <div className="flex items-center justify-between border-b border-line pb-3">
            <h3 className="text-xs font-semibold text-fg uppercase tracking-wider flex items-center gap-2">
              <Mail className="w-4 h-4 text-accent" />
              Verified Contact Channels
            </h3>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-medium text-fg mb-1.5">
                Email Address {isEditing && <span className="text-voided-600">*</span>}
              </label>
              {isEditing ? (
                <input
                  type="email"
                  value={formData.email}
                  onChange={(e) => handleInputChange('email', e.target.value)}
                  className="w-full bg-surface border border-line px-3 py-2 text-xs text-fg focus:outline-none focus:border-accent font-mono"
                  placeholder="juan.dc@email.com"
                  required
                />
              ) : (
                <div className="p-2.5 bg-sunken border border-line text-xs font-mono font-medium text-fg flex items-center gap-2">
                  <Mail className="w-3.5 h-3.5 text-fg-subtle" />
                  <span>{user?.email || 'juan.dc@email.com'}</span>
                </div>
              )}
            </div>

            <div>
              <label className="block text-xs font-medium text-fg mb-1.5">
                Mobile Number {isEditing && <span className="text-voided-600">*</span>}
              </label>
              {isEditing ? (
                <input
                  type="tel"
                  value={formData.phone_number}
                  onChange={(e) => handleInputChange('phone_number', e.target.value)}
                  className="w-full bg-surface border border-line px-3 py-2 text-xs text-fg focus:outline-none focus:border-accent font-mono"
                  placeholder="09171234567"
                  required
                />
              ) : (
                <div className="p-2.5 bg-sunken border border-line text-xs font-mono font-medium text-fg flex items-center gap-2">
                  <Smartphone className="w-3.5 h-3.5 text-fg-subtle" />
                  <span>{user?.phone_number || '09171234567'}</span>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* 4. Security Credentials & Authorization PIN */}
        <div className="p-5 bg-surface border border-line card-highlight space-y-4">
          <div className="flex items-center justify-between border-b border-line pb-3">
            <h3 className="text-xs font-semibold text-fg uppercase tracking-wider flex items-center gap-2">
              <Lock className="w-4 h-4 text-accent" />
              Security Credentials &amp; Transaction PIN
            </h3>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="p-3.5 bg-sunken border border-line space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-xs font-medium text-fg">Account Password</span>
                {!showPasswordChange ? (
                  <button
                    type="button"
                    onClick={() => setShowPasswordChange(true)}
                    className="text-xs text-accent hover:underline font-medium cursor-pointer"
                  >
                    Change
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={() => {
                      setShowPasswordChange(false);
                      setFormData((p) => ({ ...p, new_password: '' }));
                    }}
                    className="text-xs text-fg-muted cursor-pointer"
                  >
                    Cancel
                  </button>
                )}
              </div>
              {!showPasswordChange ? (
                <div className="text-xs font-mono text-fg-subtle tracking-widest">
                  &bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;
                </div>
              ) : (
                <div className="relative">
                  <input
                    type={showNewPassword ? 'text' : 'password'}
                    value={formData.new_password}
                    onChange={(e) => handleInputChange('new_password', e.target.value)}
                    placeholder="New password (min 8 chars)"
                    className="w-full bg-surface border border-line px-3 py-1.5 text-xs text-fg focus:outline-none focus:border-accent font-mono pr-8"
                  />
                  <button
                    type="button"
                    onClick={() => setShowNewPassword(!showNewPassword)}
                    className="absolute right-2 top-2 text-fg-subtle"
                  >
                    {showNewPassword ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                  </button>
                </div>
              )}
            </div>

            <div className="p-3.5 bg-sunken border border-line space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-xs font-medium text-fg">6-Digit Transaction PIN</span>
                {!showPinChange ? (
                  <button
                    type="button"
                    onClick={() => setShowPinChange(true)}
                    className="text-xs text-accent hover:underline font-medium cursor-pointer"
                  >
                    Change
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={() => {
                      setShowPinChange(false);
                      setFormData((p) => ({ ...p, new_pin: '' }));
                    }}
                    className="text-xs text-fg-muted cursor-pointer"
                  >
                    Cancel
                  </button>
                )}
              </div>
              {!showPinChange ? (
                <div className="text-xs font-mono text-fg-subtle tracking-widest">
                  &bull;&bull;&bull;&bull;&bull;&bull;
                </div>
              ) : (
                <input
                  type="password"
                  maxLength={6}
                  value={formData.new_pin}
                  onChange={(e) => handleInputChange('new_pin', e.target.value.replace(/\D/g, ''))}
                  placeholder="Enter 6-digit PIN"
                  className="w-full bg-surface border border-line px-3 py-1.5 text-xs text-fg focus:outline-none focus:border-accent font-mono"
                />
              )}
            </div>
          </div>
        </div>

        {/* 5. Registered Deposit Accounts */}
        <div className="p-5 bg-surface border border-line card-highlight space-y-3">
          <div className="flex items-center justify-between border-b border-line pb-2.5">
            <h3 className="text-xs font-semibold text-fg uppercase tracking-wider flex items-center gap-2">
              <Landmark className="w-4 h-4 text-accent" />
              Registered Accounts in Ledger
            </h3>
            <span className="text-2xs font-mono font-medium px-2 py-0.5 bg-sunken border border-line text-fg-muted">
              1 Deposit Account Active
            </span>
          </div>

          <div className="pt-1">
            <div className="p-3.5 bg-sunken border border-line space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-xs font-semibold text-fg">Primary Savings Deposit</span>
                <span className="text-2xs font-mono font-medium text-settled-700 dark:text-settled-400 bg-settled-50 dark:bg-settled-900/30 px-2 py-0.5 border border-settled-200 dark:border-settled-800">
                  DEPOSIT
                </span>
              </div>
              <p className="text-xs font-mono font-medium text-accent">1000-2000-3001</p>
              <div className="flex justify-between text-2xs text-fg-muted pt-1 border-t border-line">
                <span>Status: Active &bull; Tier 1 Regular</span>
                <span className="text-settled-600 dark:text-settled-400 font-medium font-mono">1.25% p.a.</span>
              </div>
            </div>
          </div>
        </div>

        {/* Action Save Bar */}
        {isEditing && (
          <div className="p-4 bg-accent-soft/40 border border-accent-line flex flex-col sm:flex-row items-center justify-between gap-3 animate-enter">
            <p className="text-xs text-fg font-medium">
              Review your details carefully before committing changes to the bank ledger.
            </p>
            <div className="flex items-center gap-2 w-full sm:w-auto">
              <Button
                variant="secondary"
                size="sm"
                onClick={handleCancel}
                disabled={isSaving}
              >
                Discard
              </Button>
              <Button
                variant="primary"
                size="sm"
                icon={Save}
                type="submit"
                disabled={isSaving || isLoading}
              >
                {isSaving ? 'Updating...' : 'Save Profile Changes'}
              </Button>
            </div>
          </div>
        )}
      </form>
    </div>
  );
}
