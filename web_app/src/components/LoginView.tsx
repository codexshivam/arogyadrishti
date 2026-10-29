import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { KeyRound, Phone, ArrowRight, CheckCircle2, AlertCircle, Activity, Sparkles } from 'lucide-react';

export const LoginView: React.FC = () => {
  const { sendOtp, confirmOtp } = useAuth();

  const [phone, setPhone] = useState('+919876543210');
  const [otp, setOtp] = useState('');
  const [pin, setPin] = useState('999999');
  const [step, setStep] = useState<'phone' | 'otp'>('phone');
  const [devOtpHint, setDevOtpHint] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleRequestOtp = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await sendOtp(phone);
      setStep('otp');
      if (res.dev_otp) {
        setDevOtpHint(res.dev_otp);
        setOtp(res.dev_otp);
      }
    } catch (err: any) {
      setError(err.message || 'Failed to request OTP. Check network or phone format.');
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await confirmOtp(phone, otp, pin);
    } catch (err: any) {
      setError(err.message || 'Authentication failed. Please verify the OTP code.');
    } finally {
      setLoading(false);
    }
  };

  const selectDemoAccount = (accPhone: string, accPin: string) => {
    setPhone(accPhone);
    setPin(accPin);
    setStep('phone');
    setDevOtpHint(null);
    setOtp('');
    setError(null);
  };

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        {/* Brand Header */}
        <div className="flex justify-center mb-3">
          <div className="w-14 h-14 rounded-2xl bg-linear-to-tr from-blue-600 to-indigo-600 flex items-center justify-center text-white shadow-lg shadow-blue-500/25">
            <Activity className="w-8 h-8" />
          </div>
        </div>
        <h2 className="text-center text-2xl font-black tracking-tight text-slate-900">
          Nidan<span className="text-blue-600">IQ</span> Console
        </h2>
        <p className="mt-1 text-center text-xs text-slate-500">
          Predictive Vector Surveillance & Municipal Outbreak Intelligence
        </p>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-white py-8 px-6 shadow-sm border border-slate-200 rounded-2xl sm:px-10">
          {error && (
            <div className="mb-5 p-3.5 bg-red-50 border border-red-200 rounded-xl flex items-start space-x-2.5 text-xs text-red-700">
              <AlertCircle className="w-4 h-4 text-red-500 shrink-0 mt-0.5" />
              <div className="flex-1 font-medium">{error}</div>
            </div>
          )}

          {step === 'phone' ? (
            <form onSubmit={handleRequestOtp} className="space-y-5">
              <div>
                <label htmlFor="phone" className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Mobile Number (+91 / +977)
                </label>
                <div className="relative rounded-lg shadow-2xs">
                  <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <Phone className="w-4 h-4" />
                  </div>
                  <input
                    type="tel"
                    id="phone"
                    required
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="+919876543210 or +9779841000001"
                    className="block w-full pl-10 pr-3.5 py-2.5 text-sm bg-slate-50 border border-slate-300 rounded-xl focus:bg-white focus:ring-2 focus:ring-blue-600 focus:border-blue-600 transition-all font-mono"
                  />
                </div>
                <p className="mt-1.5 text-[11px] text-slate-500">
                  Accepts verified Indian (+91) and Nepali (+977) staff mobile numbers.
                </p>
              </div>

              <button
                type="submit"
                disabled={loading || !phone}
                className="w-full flex justify-center items-center py-2.5 px-4 border border-transparent rounded-xl shadow-xs text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 focus:outline-hidden focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 transition-colors"
              >
                {loading ? (
                  <span className="flex items-center space-x-2">
                    <span className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    <span>Sending OTP...</span>
                  </span>
                ) : (
                  <span className="flex items-center space-x-1.5">
                    <span>Send Verification Code</span>
                    <ArrowRight className="w-4 h-4" />
                  </span>
                )}
              </button>
            </form>
          ) : (
            <form onSubmit={handleVerifyOtp} className="space-y-5">
              <div className="p-3 bg-blue-50 border border-blue-200 rounded-xl text-xs text-blue-800 flex items-center justify-between">
                <div>
                  <div className="font-semibold">OTP Code Dispatched</div>
                  <div className="text-[11px] text-blue-600 font-mono mt-0.5">{phone}</div>
                </div>
                <button
                  type="button"
                  onClick={() => setStep('phone')}
                  className="text-blue-700 font-bold hover:underline text-[11px]"
                >
                  Change
                </button>
              </div>

              {devOtpHint && (
                <div className="p-2.5 bg-emerald-50 border border-emerald-200 rounded-xl text-xs text-emerald-800 flex items-center justify-between">
                  <div className="flex items-center space-x-2">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                    <span>Dev OTP: <strong className="font-mono text-sm tracking-wider">{devOtpHint}</strong></span>
                  </div>
                  <span className="text-[10px] bg-emerald-100 text-emerald-800 px-2 py-0.5 rounded-full font-bold">
                    Auto-Filled
                  </span>
                </div>
              )}

              <div>
                <label htmlFor="otp" className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  6-Digit SMS OTP Code
                </label>
                <div className="relative rounded-lg shadow-2xs">
                  <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <KeyRound className="w-4 h-4" />
                  </div>
                  <input
                    type="text"
                    id="otp"
                    required
                    maxLength={6}
                    value={otp}
                    onChange={(e) => setOtp(e.target.value)}
                    placeholder="123456"
                    className="block w-full pl-10 pr-3.5 py-2.5 text-base tracking-widest font-mono text-center bg-slate-50 border border-slate-300 rounded-xl focus:bg-white focus:ring-2 focus:ring-blue-600 focus:border-blue-600 transition-all"
                  />
                </div>
              </div>

              <button
                type="submit"
                disabled={loading || otp.length !== 6}
                className="w-full flex justify-center items-center py-2.5 px-4 border border-transparent rounded-xl shadow-xs text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 focus:outline-hidden focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 transition-colors"
              >
                {loading ? (
                  <span className="flex items-center space-x-2">
                    <span className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    <span>Verifying...</span>
                  </span>
                ) : (
                  <span>Verify & Access Console</span>
                )}
              </button>
            </form>
          )}

          {/* Pre-Authorized Test Profiles */}
          <div className="mt-8 pt-6 border-t border-slate-100">
            <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-2.5 flex items-center gap-1.5">
              <Sparkles className="w-3.5 h-3.5 text-blue-500" />
              <span>Quick Test Access (Pre-Authorized Accounts)</span>
            </div>
            <div className="space-y-1.5">
              <button
                type="button"
                onClick={() => selectDemoAccount('+919876543210', '999999')}
                className={`w-full text-left px-3 py-2 rounded-xl text-xs flex items-center justify-between border transition-all ${
                  phone === '+919876543210'
                    ? 'bg-purple-50/70 border-purple-300 text-purple-900 font-semibold'
                    : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                }`}
              >
                <div>
                  <div className="font-bold">Federal System Admin</div>
                  <div className="text-[10px] text-slate-500 font-mono">+919876543210 • Full System RBAC</div>
                </div>
                <span className="text-[10px] px-2 py-0.5 rounded-full font-bold bg-purple-100 text-purple-800">
                  Admin
                </span>
              </button>

              <button
                type="button"
                onClick={() => selectDemoAccount('+919876543211', '888888')}
                className={`w-full text-left px-3 py-2 rounded-xl text-xs flex items-center justify-between border transition-all ${
                  phone === '+919876543211'
                    ? 'bg-blue-50/70 border-blue-300 text-blue-900 font-semibold'
                    : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                }`}
              >
                <div>
                  <div className="font-bold">Kathmandu Municipality Admin</div>
                  <div className="text-[10px] text-slate-500 font-mono">+919876543211 • Scoped: KMC (30608)</div>
                </div>
                <span className="text-[10px] px-2 py-0.5 rounded-full font-bold bg-blue-100 text-blue-800">
                  Municipality Admin
                </span>
              </button>

              <button
                type="button"
                onClick={() => selectDemoAccount('+919876543212', '777777')}
                className={`w-full text-left px-3 py-2 rounded-xl text-xs flex items-center justify-between border transition-all ${
                  phone === '+919876543212'
                    ? 'bg-emerald-50/70 border-emerald-300 text-emerald-900 font-semibold'
                    : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                }`}
              >
                <div>
                  <div className="font-bold">Frontline Field Visitor</div>
                  <div className="text-[10px] text-slate-500 font-mono">+919876543212 • KMC Ward 17</div>
                </div>
                <span className="text-[10px] px-2 py-0.5 rounded-full font-bold bg-emerald-100 text-emerald-800">
                  Field Visitor
                </span>
              </button>
            </div>
          </div>
        </div>

        <p className="mt-4 text-center text-[11px] text-slate-400">
          NidanIQ Digital Public Infrastructure • Government Health Operations
        </p>
      </div>
    </div>
  );
};
