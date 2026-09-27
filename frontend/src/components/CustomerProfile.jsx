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
  EyeOff
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export default function CustomerProfile({ showToast }) {
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

  // Format Date for Customer Friendly Display
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
    <div className="max-w-4xl mx-auto space-y-6 animate-fadeIn">
      {/* 1. Customer Banking Profile Action Bar */}
      <div className="p-5 sm:p-6 rounded-3xl bg-slate-900/80 backdrop-blur-xl border border-slate-800 shadow-xl flex flex-col sm:flex-row sm:items-center justify-between gap-4 relative overflow-hidden">
        <div className="relative z-10">
          <div className="flex items-center gap-2">
            <h2 className="text-base sm:text-lg font-bold text-white tracking-tight">
              Personal Details &amp; Security Settings
            </h2>
            <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 flex items-center gap-1 font-mono">
              <ShieldCheck className="w-3 h-3 text-emerald-400" />
              ID: {user?.user_id || 'U1001'} &bull; Verified
            </span>
          </div>
          <p className="text-xs text-slate-400 mt-1">
            Registered customer account &bull; Member since {formatFriendlyDate(user?.created_at || '2024-01-10')}
          </p>
        </div>

        <div className="flex items-center gap-2 relative z-10">
          {!isEditing ? (
            <button
              type="button"
              onClick={() => setIsEditing(true)}
              className="px-4 py-2.5 rounded-xl text-xs font-semibold bg-indigo-600 hover:bg-indigo-500 text-white shadow-lg shadow-indigo-600/30 transition-all flex items-center gap-2 cursor-pointer"
            >
              <Edit3 className="w-3.5 h-3.5" />
              <span>Edit Details</span>
            </button>
          ) : (
            <button
              type="button"
              onClick={handleCancel}
              disabled={isSaving}
              className="px-4 py-2.5 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-300 transition-all flex items-center gap-2 cursor-pointer"
            >
              <X className="w-3.5 h-3.5" />
              <span>Cancel</span>
            </button>
          )}
        </div>
      </div>

        {/* Feedback Banners */}
        {errorMsg && (
          <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-300 text-xs flex items-start gap-2">
            <AlertCircle className="w-4 h-4 shrink-0 mt-0.5 text-rose-400" />
            <span>{errorMsg}</span>
          </div>
        )}
        {successMsg && (
          <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 text-xs flex items-start gap-2">
            <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5 text-emerald-400" />
            <span>{successMsg}</span>
          </div>
        )}

      <form onSubmit={handleSave} className="space-y-6">
        {/* 2. Personal Information */}
        <div className="p-6 sm:p-7 rounded-3xl bg-slate-900/80 backdrop-blur-xl border border-slate-800 shadow-xl space-y-5">
          <div className="flex items-center justify-between border-b border-slate-800/80 pb-3.5">
            <div>
              <h3 className="text-sm font-bold text-white flex items-center gap-2">
                <User className="w-4 h-4 text-indigo-400" />
                Personal Information
              </h3>
            </div>
            {isEditing && (
              <span className="text-[11px] font-medium text-amber-400 bg-amber-500/10 px-2 py-0.5 rounded-full border border-amber-500/20">
                Editing Mode
              </span>
            )}
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {/* First Name */}
            <div>
              <label className="block text-xs font-medium text-slate-400 mb-1.5">
                First Name {isEditing && <span className="text-rose-400">*</span>}
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={formData.first_name}
                  onChange={(e) => handleInputChange('first_name', e.target.value)}
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500 transition-all"
                  placeholder="First Name"
                  required
                />
              ) : (
                <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800/80 text-xs font-semibold text-white">
                  {user?.first_name || '—'}
                </div>
              )}
            </div>

            {/* Middle Name */}
            <div>
              <label className="block text-xs font-medium text-slate-400 mb-1.5">
                Middle Name
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={formData.middle_name}
                  onChange={(e) => handleInputChange('middle_name', e.target.value)}
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500 transition-all"
                  placeholder="Middle Name (optional)"
                />
              ) : (
                <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800/80 text-xs font-semibold text-white">
                  {user?.middle_name || '—'}
                </div>
              )}
            </div>

            {/* Last Name */}
            <div>
              <label className="block text-xs font-medium text-slate-400 mb-1.5">
                Last Name {isEditing && <span className="text-rose-400">*</span>}
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={formData.last_name}
                  onChange={(e) => handleInputChange('last_name', e.target.value)}
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500 transition-all"
                  placeholder="Last Name"
                  required
                />
              ) : (
                <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800/80 text-xs font-semibold text-white">
                  {user?.last_name || '—'}
                </div>
              )}
            </div>

            {/* Date of Birth */}
            <div>
              <label className="block text-xs font-medium text-slate-400 mb-1.5 flex items-center gap-1.5">
                <Calendar className="w-3.5 h-3.5 text-slate-500" />
                Date of Birth
              </label>
              {isEditing ? (
                <input
                  type="date"
                  value={formData.dob}
                  onChange={(e) => handleInputChange('dob', e.target.value)}
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-indigo-500 transition-all"
                />
              ) : (
                <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800/80 text-xs text-slate-200">
                  {formatFriendlyDate(user?.dob)}
                </div>
              )}
            </div>

            {/* Government Issued ID */}
            <div className="sm:col-span-2">
              <label className="block text-xs font-medium text-slate-400 mb-1.5 flex items-center gap-1.5">
                <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
                Government Issued ID
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={formData.government_id}
                  onChange={(e) => handleInputChange('government_id', e.target.value)}
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500 transition-all font-mono"
                  placeholder="e.g. PSA-1234-5678, UMID, Passport"
                />
              ) : (
                <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800/80 text-xs flex items-center justify-between">
                  <span className="font-mono text-white font-medium">
                    {user?.government_id || 'PSA-1234-5678'}
                  </span>
                  <span className="text-[10px] font-semibold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20">
                    Verified ID
                  </span>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* 3. Contact & Communication Details */}
        <div className="p-6 sm:p-7 rounded-3xl bg-slate-900/80 backdrop-blur-xl border border-slate-800 shadow-xl space-y-5">
          <div className="border-b border-slate-800/80 pb-3.5">
            <h3 className="text-sm font-bold text-white flex items-center gap-2">
              <Mail className="w-4 h-4 text-indigo-400" />
              Contact Information
            </h3>
            <p className="text-xs text-slate-400 mt-0.5">
              Channels where your transaction receipts and OTP security codes are sent.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Email Address */}
            <div>
              <label className="block text-xs font-medium text-slate-400 mb-1.5 flex items-center gap-1.5">
                <Mail className="w-3.5 h-3.5 text-slate-500" />
                Email Address {isEditing && <span className="text-rose-400">*</span>}
              </label>
              {isEditing ? (
                <input
                  type="email"
                  value={formData.email}
                  onChange={(e) => handleInputChange('email', e.target.value)}
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500 transition-all"
                  placeholder="your.email@address.com"
                  required
                />
              ) : (
                <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800/80 text-xs font-mono text-indigo-300">
                  {user?.email || 'juan.dc@email.com'}
                </div>
              )}
              <p className="text-[11px] text-slate-500 mt-1">Used for e-receipts and settlement notices.</p>
            </div>

            {/* Mobile Phone Number */}
            <div>
              <label className="block text-xs font-medium text-slate-400 mb-1.5 flex items-center gap-1.5">
                <Phone className="w-3.5 h-3.5 text-slate-500" />
                Mobile Phone Number {isEditing && <span className="text-rose-400">*</span>}
              </label>
              {isEditing ? (
                <input
                  type="text"
                  value={formData.phone_number}
                  onChange={(e) => handleInputChange('phone_number', e.target.value)}
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500 transition-all font-mono"
                  placeholder="09XXXXXXXXX"
                  required
                />
              ) : (
                <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800/80 text-xs font-mono text-slate-200">
                  {user?.phone_number || '09171234567'}
                </div>
              )}
              <p className="text-[11px] text-slate-500 mt-1">Used for One-Time PIN (OTP) transaction authorization.</p>
            </div>
          </div>
        </div>

        {/* 4. Security & Login Credentials */}
        <div className="p-6 sm:p-7 rounded-3xl bg-slate-900/80 backdrop-blur-xl border border-slate-800 shadow-xl space-y-5">
          <div className="border-b border-slate-800/80 pb-3.5">
            <h3 className="text-sm font-bold text-white flex items-center gap-2">
              <Lock className="w-4 h-4 text-indigo-400" />
              Security &amp; Credentials
            </h3>
            <p className="text-xs text-slate-400 mt-0.5">
              Manage your online banking sign-in password and transfer approval PIN.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Password Card */}
            <div className="p-4 rounded-2xl bg-slate-950/60 border border-slate-800/80 space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <KeyRound className="w-4 h-4 text-indigo-400" />
                  <span className="text-xs font-semibold text-white">Login Password</span>
                </div>
                {!showPasswordChange ? (
                  <button
                    type="button"
                    onClick={() => {
                      setIsEditing(true);
                      setShowPasswordChange(true);
                    }}
                    className="text-[11px] text-indigo-400 hover:text-indigo-300 font-semibold cursor-pointer hover:underline"
                  >
                    Change Password
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={() => {
                      setShowPasswordChange(false);
                      setFormData((p) => ({ ...p, new_password: '' }));
                    }}
                    className="text-[11px] text-slate-400 hover:text-white cursor-pointer"
                  >
                    Cancel
                  </button>
                )}
              </div>

              {!showPasswordChange ? (
                <div className="text-xs font-mono text-slate-400 tracking-widest pt-1">
                  &bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;&bull;
                </div>
              ) : (
                <div className="space-y-2 pt-1 animate-fadeIn">
                  <div className="relative">
                    <input
                      type={showNewPassword ? 'text' : 'password'}
                      value={formData.new_password}
                      onChange={(e) => handleInputChange('new_password', e.target.value)}
                      placeholder="Enter new password"
                      className="w-full bg-slate-900 border border-slate-700 rounded-xl pl-3 pr-9 py-2 text-xs text-white focus:outline-none focus:border-indigo-500"
                    />
                    <button
                      type="button"
                      onClick={() => setShowNewPassword(!showNewPassword)}
                      className="absolute right-2.5 top-2 text-slate-500 hover:text-slate-300 p-0.5"
                    >
                      {showNewPassword ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                    </button>
                  </div>
                  <p className="text-[10px] text-slate-500">Must be at least 8 characters with numbers and symbols.</p>
                </div>
              )}
            </div>

            {/* PIN Card */}
            <div className="p-4 rounded-2xl bg-slate-950/60 border border-slate-800/80 space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Smartphone className="w-4 h-4 text-emerald-400" />
                  <span className="text-xs font-semibold text-white">6-Digit Transaction PIN</span>
                </div>
                {!showPinChange ? (
                  <button
                    type="button"
                    onClick={() => {
                      setIsEditing(true);
                      setShowPinChange(true);
                    }}
                    className="text-[11px] text-emerald-400 hover:text-emerald-300 font-semibold cursor-pointer hover:underline"
                  >
                    Change PIN
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={() => {
                      setShowPinChange(false);
                      setFormData((p) => ({ ...p, new_pin: '' }));
                    }}
                    className="text-[11px] text-slate-400 hover:text-white cursor-pointer"
                  >
                    Cancel
                  </button>
                )}
              </div>

              {!showPinChange ? (
                <div className="text-xs font-mono text-slate-400 tracking-widest pt-1">
                  &bull;&bull;&bull;&bull;&bull;&bull;
                </div>
              ) : (
                <div className="space-y-2 pt-1 animate-fadeIn">
                  <div className="relative">
                    <input
                      type={showNewPin ? 'text' : 'password'}
                      maxLength={6}
                      value={formData.new_pin}
                      onChange={(e) => handleInputChange('new_pin', e.target.value.replace(/\D/g, ''))}
                      placeholder="Enter new 6-digit PIN"
                      className="w-full bg-slate-900 border border-slate-700 rounded-xl pl-3 pr-9 py-2 text-xs text-white focus:outline-none focus:border-indigo-500 font-mono"
                    />
                    <button
                      type="button"
                      onClick={() => setShowNewPin(!showNewPin)}
                      className="absolute right-2.5 top-2 text-slate-500 hover:text-slate-300 p-0.5"
                    >
                      {showNewPin ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                    </button>
                  </div>
                  <p className="text-[10px] text-slate-500">6 numeric digits used to authorize fund transfers.</p>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* 5. Account & Security Status Summary */}
        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800/80 flex flex-col sm:flex-row sm:items-center justify-between gap-4 text-xs text-slate-400">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400 shrink-0">
              <ShieldCheck className="w-4 h-4" />
            </div>
            <div>
              <p className="font-semibold text-slate-200">Account Protection Active</p>
              <p className="text-[11px] text-slate-400">
                Session protected by 256-bit TLS encryption &bull; Single-device dual factor verification
              </p>
            </div>
          </div>
          <div className="text-left sm:text-right font-mono text-[11px] text-slate-400 border-t sm:border-t-0 pt-2 sm:pt-0 border-slate-800">
            <span>Last Updated: </span>
            <span className="text-slate-300">{formatFriendlyDateTime(user?.updated_at || user?.created_at)}</span>
          </div>
        </div>

        {/* Action Save Bar (Visible when in Edit Mode) */}
        {isEditing && (
          <div className="p-4 rounded-2xl bg-indigo-950/40 border border-indigo-500/30 flex flex-col sm:flex-row items-center justify-between gap-3 animate-fadeIn">
            <p className="text-xs text-indigo-300">
              Review your details carefully before saving changes.
            </p>
            <div className="flex items-center gap-2.5 w-full sm:w-auto">
              <button
                type="button"
                onClick={handleCancel}
                disabled={isSaving}
                className="flex-1 sm:flex-none px-4 py-2 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-300 transition-colors cursor-pointer"
              >
                Discard
              </button>
              <button
                type="submit"
                disabled={isSaving || isLoading}
                className="flex-1 sm:flex-none px-5 py-2 rounded-xl text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-white shadow-lg shadow-indigo-600/30 transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
              >
                <Save className="w-3.5 h-3.5" />
                <span>{isSaving ? 'Updating Profile...' : 'Save Profile Changes'}</span>
              </button>
            </div>
          </div>
        )}
      </form>
    </div>
  );
}
