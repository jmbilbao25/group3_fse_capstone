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
  Sparkles,
  Smartphone,
  Eye,
  EyeOff,
  CreditCard,
  Landmark,
  Wallet
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export default function CustomerProfile({ showToast, activeAccountId = '1000-2000-3001', onSwitchAccount }) {
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
    e?.preventDefault();
    if (!formData.first_name.trim() || !formData.last_name.trim()) {
      setErrorMsg('Please enter your legal first and last name.');
      return;
    }
    if (!formData.email.trim()) {
      setErrorMsg('Please enter your valid email address for banking alerts.');
      return;
    }
    if (!formData.phone_number.trim()) {
      setErrorMsg('Please enter your mobile phone number for OTP verification.');
      return;
    }

    setIsSaving(true);
    setErrorMsg('');
    try {
      const payload = {
        first_name: formData.first_name.trim(),
        middle_name: formData.middle_name ? formData.middle_name.trim() : null,
        last_name: formData.last_name.trim(),
        email: formData.email.trim(),
        phone_number: formData.phone_number.trim(),
        dob: formData.dob,
        government_id: formData.government_id.trim(),
      };

      if (formData.new_password) {
        payload.new_password = formData.new_password;
      }
      if (formData.new_pin) {
        payload.new_pin = formData.new_pin;
      }

      const res = await updateUserProfile(payload);
      if (res?.success) {
        setIsEditing(false);
        setShowPasswordChange(false);
        setShowPinChange(false);
        setSuccessMsg('Your profile information was updated successfully.');
        setTimeout(() => setSuccessMsg(''), 5000);
        showToast?.({
          type: 'success',
          title: 'Profile Updated',
          detail: 'Your personal details have been securely updated in your banking account.',
        });
      } else {
        setErrorMsg(res?.error || 'Unable to save profile changes. Please try again.');
      }
    } catch (_) {
      setErrorMsg('Network error while saving profile. Please check your connection.');
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

  const formatFriendlyDateTime = (dateString) => {
    if (!dateString) return 'Recently';
    try {
      const d = new Date(dateString);
      return d.toLocaleDateString('en-US', { 
        month: 'short', 
        day: 'numeric', 
        year: 'numeric', 
        hour: 'numeric', 
        minute: '2-digit', 
        hour12: true 
      });
    } catch (_) {
      return dateString;
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-5 animate-in fade-in duration-200">
      {/* 1. Header Banner */}
      <div className="p-5 rounded-2xl bg-white border border-slate-200/90 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-base font-extrabold text-slate-900 tracking-tight">
              Personal KYC &amp; Account Security
            </h2>
            <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-cyan-50 text-cyan-800 border border-cyan-200 flex items-center gap-1 font-mono">
              <ShieldCheck className="w-3 h-3 text-cyan-600" />
              ID: {user?.user_id || 'U1001'} &bull; Verified
            </span>
          </div>
          <p className="text-xs text-slate-500 mt-0.5">
            Registered customer account &bull; Member since {formatFriendlyDate(user?.created_at || '2024-01-10')}
          </p>
        </div>

        <div className="flex items-center gap-2">
          {!isEditing ? (
            <button
              type="button"
              onClick={() => setIsEditing(true)}
              className="px-4 py-2 rounded-xl text-xs font-bold bg-cyan-600 hover:bg-cyan-700 text-white shadow-sm transition-all flex items-center gap-2 cursor-pointer"
            >
              <Edit3 className="w-3.5 h-3.5" />
              <span>Edit Details</span>
            </button>
          ) : (
            <button
              type="button"
              onClick={handleCancel}
              disabled={isSaving}
              className="px-4 py-2 rounded-xl text-xs font-bold bg-slate-100 hover:bg-slate-200 text-slate-700 transition-all flex items-center gap-2 cursor-pointer"
            >
              <X className="w-3.5 h-3.5" />
              <span>Cancel</span>
            </button>
          )}
        </div>
      </div>

      {/* Feedback Banners */}
      {errorMsg && (
        <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-start gap-2">
          <AlertCircle className="w-4 h-4 shrink-0 mt-0.5 text-rose-600" />
          <span>{errorMsg}</span>
        </div>
      )}
      {successMsg && (
        <div className="p-3 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs flex items-start gap-2">
          <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5 text-emerald-600" />
          <span>{successMsg}</span>
        </div>
      )}

      <form onSubmit={handleSave} className="space-y-5">
        {/* 2. Personal Information */}
        <div className="p-5 rounded-2xl bg-white border border-slate-200/90 shadow-sm space-y-4">
          <div className="flex items-center justify-between border-b border-slate-100 pb-3">
            <h3 className="text-xs font-bold text-slate-900 uppercase tracking-wider flex items-center gap-2">
              <User className="w-4 h-4 text-cyan-600" />
              Legal Identity Particulars
            </h3>
            {isEditing && (
              <span className="text-[10px] font-bold text-amber-700 bg-amber-50 px-2 py-0.5 rounded-full border border-amber-200">
                Editing Mode
              </span>
            )}
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5">
                First Name {isEditing && <span className="text-rose-500">*</span>}
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={formData.first_name}
                  onChange={(e) => handleInputChange('first_name', e.target.value)}
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2 text-xs text-slate-900 focus:outline-none focus:border-cyan-600 focus:bg-white"
                  placeholder="First Name"
                  required
                />
              ) : (
                <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs font-bold text-slate-900">
                  {user?.first_name || '—'}
                </div>
              )}
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5">
                Middle Name
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={formData.middle_name}
                  onChange={(e) => handleInputChange('middle_name', e.target.value)}
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2 text-xs text-slate-900 focus:outline-none focus:border-cyan-600 focus:bg-white"
                  placeholder="Middle Name"
                />
              ) : (
                <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs font-bold text-slate-900">
                  {user?.middle_name || '—'}
                </div>
              )}
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5">
                Last Name {isEditing && <span className="text-rose-500">*</span>}
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={formData.last_name}
                  onChange={(e) => handleInputChange('last_name', e.target.value)}
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2 text-xs text-slate-900 focus:outline-none focus:border-cyan-600 focus:bg-white"
                  placeholder="Last Name"
                  required
                />
              ) : (
                <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs font-bold text-slate-900">
                  {user?.last_name || '—'}
                </div>
              )}
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5 flex items-center gap-1.5">
                <Calendar className="w-3.5 h-3.5 text-slate-400" />
                Date of Birth
              </label>
              {isEditing ? (
                <input
                  type="date"
                  value={formData.dob}
                  onChange={(e) => handleInputChange('dob', e.target.value)}
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2 text-xs text-slate-900 focus:outline-none focus:border-cyan-600 focus:bg-white"
                />
              ) : (
                <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-800">
                  {formatFriendlyDate(user?.dob)}
                </div>
              )}
            </div>

            <div className="sm:col-span-2">
              <label className="block text-xs font-bold text-slate-700 mb-1.5 flex items-center gap-1.5">
                <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
                Government Issued ID
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={formData.government_id}
                  onChange={(e) => handleInputChange('government_id', e.target.value)}
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2 text-xs text-slate-900 focus:outline-none focus:border-cyan-600 focus:bg-white font-mono"
                  placeholder="e.g. PSA-1234-5678, UMID, Passport"
                />
              ) : (
                <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs flex items-center justify-between">
                  <span className="font-mono text-slate-900 font-bold">
                    {user?.government_id || 'PSA-1234-5678'}
                  </span>
                  <span className="text-[10px] font-bold text-emerald-800 bg-emerald-50 px-2 py-0.5 rounded border border-emerald-200">
                    Verified ID
                  </span>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* 3. Contact Information */}
        <div className="p-5 rounded-2xl bg-white border border-slate-200/90 shadow-sm space-y-4">
          <div className="border-b border-slate-100 pb-3">
            <h3 className="text-xs font-bold text-slate-900 uppercase tracking-wider flex items-center gap-2">
              <Mail className="w-4 h-4 text-cyan-600" />
              Contact Information &amp; OTP Channels
            </h3>
            <p className="text-xs text-slate-500 mt-0.5">
              Channels where transaction receipts and OTP authorization codes are delivered.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5 flex items-center gap-1.5">
                <Mail className="w-3.5 h-3.5 text-slate-400" />
                Email Address {isEditing && <span className="text-rose-500">*</span>}
              </label>
              {isEditing ? (
                <input
                  type="email"
                  value={formData.email}
                  onChange={(e) => handleInputChange('email', e.target.value)}
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2 text-xs text-slate-900 focus:outline-none focus:border-cyan-600 focus:bg-white"
                  placeholder="your.email@address.com"
                  required
                />
              ) : (
                <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs font-mono font-bold text-cyan-800">
                  {user?.email || 'juan.dc@email.com'}
                </div>
              )}
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5 flex items-center gap-1.5">
                <Phone className="w-3.5 h-3.5 text-slate-400" />
                Mobile Phone Number {isEditing && <span className="text-rose-500">*</span>}
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={formData.phone_number}
                  onChange={(e) => handleInputChange('phone_number', e.target.value)}
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2 text-xs text-slate-900 focus:outline-none focus:border-cyan-600 focus:bg-white font-mono"
                  placeholder="09XXXXXXXXX"
                  required
                />
              ) : (
                <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs font-mono font-bold text-slate-900">
                  {user?.phone_number || '09171234567'}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* 4. Credentials & PIN */}
        <div className="p-5 rounded-2xl bg-white border border-slate-200/90 shadow-sm space-y-4">
          <div className="border-b border-slate-100 pb-3">
            <h3 className="text-xs font-bold text-slate-900 uppercase tracking-wider flex items-center gap-2">
              <Lock className="w-4 h-4 text-cyan-600" />
              Credentials &amp; Security PIN
            </h3>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="p-4 rounded-xl bg-slate-50 border border-slate-200 space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-slate-800 flex items-center gap-1.5">
                  <KeyRound className="w-3.5 h-3.5 text-cyan-600" /> Sign-in Password
                </span>
                {!showPasswordChange ? (
                  <button
                    type="button"
                    onClick={() => {
                      setIsEditing(true);
                      setShowPasswordChange(true);
                    }}
                    className="text-xs text-cyan-700 hover:underline font-bold cursor-pointer"
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
                    className="text-xs text-slate-500 cursor-pointer"
                  >
                    Cancel
                  </button>
                )}
              </div>
              {!showPasswordChange ? (
                <div className="text-xs font-mono text-slate-400 tracking-widest">
                  &bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;
                </div>
              ) : (
                <input
                  type="password"
                  value={formData.new_password}
                  onChange={(e) => handleInputChange('new_password', e.target.value)}
                  placeholder="Enter new password"
                  className="w-full bg-white border border-slate-200 rounded-xl px-3 py-1.5 text-xs text-slate-900 focus:outline-none focus:border-cyan-600"
                />
              )}
            </div>

            <div className="p-4 rounded-xl bg-slate-50 border border-slate-200 space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-slate-800 flex items-center gap-1.5">
                  <Smartphone className="w-3.5 h-3.5 text-emerald-600" /> 6-Digit Transfer PIN
                </span>
                {!showPinChange ? (
                  <button
                    type="button"
                    onClick={() => {
                      setIsEditing(true);
                      setShowPinChange(true);
                    }}
                    className="text-xs text-cyan-700 hover:underline font-bold cursor-pointer"
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
                    className="text-xs text-slate-500 cursor-pointer"
                  >
                    Cancel
                  </button>
                )}
              </div>
              {!showPinChange ? (
                <div className="text-xs font-mono text-slate-400 tracking-widest">
                  &bull;&bull;&bull;&bull;&bull;&bull;
                </div>
              ) : (
                <input
                  type="password"
                  maxLength={6}
                  value={formData.new_pin}
                  onChange={(e) => handleInputChange('new_pin', e.target.value.replace(/\D/g, ''))}
                  placeholder="Enter 6-digit PIN"
                  className="w-full bg-white border border-slate-200 rounded-xl px-3 py-1.5 text-xs text-slate-900 focus:outline-none focus:border-cyan-600 font-mono"
                />
              )}
            </div>
          </div>
        </div>

        {/* 5. Linked Accounts */}
        <div className="p-5 rounded-2xl bg-white border border-slate-200/90 shadow-sm space-y-3">
          <div className="flex items-center justify-between border-b border-slate-100 pb-2.5">
            <h3 className="text-xs font-bold text-slate-900 uppercase tracking-wider flex items-center gap-2">
              <CreditCard className="w-4 h-4 text-cyan-600" />
              Registered Accounts in Ledger
            </h3>
            <span className="text-[10px] font-mono font-bold px-2 py-0.5 rounded-full bg-slate-100 text-slate-700">
              2 Accounts Linked
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
            <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-xs font-bold text-slate-900">Primary Savings Deposit</span>
                <span className="text-[10px] font-bold text-emerald-800 bg-emerald-50 px-2 py-0.2 rounded border border-emerald-200">
                  SAVINGS
                </span>
              </div>
              <p className="text-xs font-mono font-bold text-cyan-800">1000-2000-3001</p>
              <div className="flex justify-between text-[11px] text-slate-500 pt-1 border-t border-slate-200/60">
                <span>Status: Prime Active</span>
                <span className="text-emerald-700 font-bold">1.25% p.a.</span>
              </div>
            </div>

            <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-xs font-bold text-slate-900">Revolving Credit Facility</span>
                <span className="text-[10px] font-bold text-purple-800 bg-purple-50 px-2 py-0.2 rounded border border-purple-200">
                  CREDIT
                </span>
              </div>
              <p className="text-xs font-mono font-bold text-purple-800">1000-2000-3003</p>
              <div className="flex justify-between text-[11px] text-slate-500 pt-1 border-t border-slate-200/60">
                <span>Limit: ₱300,000.00</span>
                <span className="text-purple-700 font-bold">24% APR</span>
              </div>
            </div>
          </div>
        </div>

        {/* Action Save Bar */}
        {isEditing && (
          <div className="p-4 rounded-2xl bg-cyan-50 border border-cyan-200 flex flex-col sm:flex-row items-center justify-between gap-3 animate-in fade-in">
            <p className="text-xs text-cyan-900 font-medium">
              Review your details carefully before saving to the bank ledger.
            </p>
            <div className="flex items-center gap-2 w-full sm:w-auto">
              <button
                type="button"
                onClick={handleCancel}
                disabled={isSaving}
                className="flex-1 sm:flex-none px-4 py-2 rounded-xl text-xs font-bold bg-white hover:bg-slate-50 text-slate-700 border border-slate-200 transition cursor-pointer"
              >
                Discard
              </button>
              <button
                type="submit"
                disabled={isSaving || isLoading}
                className="flex-1 sm:flex-none px-5 py-2 rounded-xl text-xs font-bold bg-cyan-600 hover:bg-cyan-700 text-white shadow-sm transition flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
              >
                <Save className="w-3.5 h-3.5" />
                <span>{isSaving ? 'Updating...' : 'Save Profile Changes'}</span>
              </button>
            </div>
          </div>
        )}
      </form>
    </div>
  );
}
