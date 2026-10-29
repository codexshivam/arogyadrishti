import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { KeyRound, Phone, ArrowRight, CheckCircle2, AlertCircle, Sparkles } from 'lucide-react';

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
    <div className="min-h-screen bg-[#f7f9fb] flex flex-col justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        {/* Brand Header: Transparent background with red text logo */}
        <div className="text-center">
          <span className="text-3xl font-black tracking-tight text-[#a50c1f]">
            Nidan<span className="text-[#7c0012]">IQ</span>
          </span>
          <p className="mt-1 text-xs text-[#64748b] font-medium">
            Vector Surveillance &amp; Outbreak Intelligence Console
          </p>
        </div>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-white py-8 px-6 shadow-sm border border-[#e2e8f0] rounded-2xl sm:px-10">
          {error && (
            <div className="mb-5 p-3.5 bg-[#fee2e2] border border-[#fca5a5] rounded-xl flex items-start space-x-2.5 text-xs text-[#991b1b]">
              <AlertCircle className="w-4 h-4 text-[#ba1a1a] shrink-0 mt-0.5" />
              <div className="flex-1 font-medium">{error}</div>
            </div>
          )}

          {step === 'phone' ? (
            <form onSubmit={handleRequestOtp} className="space-y-5">
              <div>
                <label htmlFor="phone" className="block text-xs font-semibold text-[#0f172a] uppercase tracking-wider mb-1.5">
                  Mobile Number (+91 / +977)
                </label>
                <div className="relative rounded-lg">
                  <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-[#64748b]">
                    <Phone className="w-4 h-4" />
                  </div>
                  <input
                    type="tel"
                    id="phone"
                    required
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="+919876543210 or +9779841000001"
                    className="block w-full pl-10 pr-3.5 py-3 text-sm bg-white border border-[#cbd5e1] rounded-lg focus:outline-hidden focus:border-[#a50c1f] focus:ring-2 focus:ring-[#a50c1f]/20 transition-all font-mono"
                  />
                </div>
                <p className="mt-1.5 text-[11px] text-[#64748b]">
                  Accepts verified Indian (+91) and Nepali (+977) mobile numbers.
                </p>
              </div>

              <button
                type="submit"
                disabled={loading || !phone}
                className="w-full flex justify-center items-center py-3 px-4 border border-transparent rounded-lg shadow-xs text-sm font-semibold text-white bg-[#a50c1f] hover:bg-[#991b1b] active:bg-[#7c0012] focus:outline-hidden focus:ring-2 focus:ring-offset-2 focus:ring-[#a50c1f] disabled:opacity-50 min-h-[48px] transition-colors"
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
              <div className="p-3 bg-[#dae2fd]/40 border border-[#c7d2fe] rounded-xl text-xs text-[#131b2e] flex items-center justify-between">
                <div>
                  <div className="font-semibold text-[#0f172a]">OTP Code Dispatched</div>
                  <div className="text-[11px] text-[#334155] font-mono mt-0.5">{phone}</div>
                </div>
                <button
                  type="button"
                  onClick={() => setStep('phone')}
                  className="text-[#a50c1f] font-bold hover:underline text-[11px]"
                >
                  Change
                </button>
              </div>

              {devOtpHint && (
                <div className="p-2.5 bg-[#dcfce7] border border-[#86efac] rounded-xl text-xs text-[#166534] flex items-center justify-between">
                  <div className="flex items-center space-x-2">
                    <CheckCircle2 className="w-4 h-4 text-[#166534] shrink-0" />
                    <span>Dev OTP: <strong className="font-mono text-sm tracking-wider">{devOtpHint}</strong></span>
                  </div>
                  <span className="text-[10px] bg-[#bbf7d0] text-[#166534] px-2 py-0.5 rounded-full font-bold">
                    Auto-Filled
                  </span>
                </div>
              )}

              <div>
                <label htmlFor="otp" className="block text-xs font-semibold text-[#0f172a] uppercase tracking-wider mb-1.5">
                  6-Digit SMS OTP Code
                </label>
                <div className="relative rounded-lg">
                  <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-[#64748b]">
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
                    className="block w-full pl-10 pr-3.5 py-3 text-base tracking-widest font-mono text-center bg-white border border-[#cbd5e1] rounded-lg focus:outline-hidden focus:border-[#a50c1f] focus:ring-2 focus:ring-[#a50c1f]/20 transition-all"
                  />
                </div>
              </div>

              <button
                type="submit"
                disabled={loading || otp.length !== 6}
                className="w-full flex justify-center items-center py-3 px-4 border border-transparent rounded-lg shadow-xs text-sm font-semibold text-white bg-[#a50c1f] hover:bg-[#991b1b] active:bg-[#7c0012] focus:outline-hidden focus:ring-2 focus:ring-offset-2 focus:ring-[#a50c1f] disabled:opacity-50 min-h-[48px] transition-colors"
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
          <div className="mt-8 pt-6 border-t border-[#f1f5f9]">
            <div className="text-[11px] font-semibold text-[#64748b] uppercase tracking-wider mb-2.5 flex items-center gap-1.5">
              <Sparkles className="w-3.5 h-3.5 text-[#a50c1f]" />
              <span>Quick Test Access (Pre-Authorized Accounts)</span>
            </div>
            <div className="space-y-2">
              <button
                type="button"
                onClick={() => selectDemoAccount('+919876543210', '999999')}
                className={`w-full text-left px-3.5 py-2.5 rounded-xl text-xs flex items-center justify-between border transition-all ${
                  phone === '+919876543210'
                    ? 'bg-[#fee2e2]/70 border-[#fca5a5] text-[#991b1b]'
                    : 'bg-[#f8fafc] border-[#e2e8f0] text-[#334155] hover:bg-[#f1f5f9]'
                }`}
              >
                <div>
                  <div className="font-bold text-[#0f172a]">Federal System Admin</div>
                  <div className="text-[10px] text-[#64748b] font-mono">+919876543210 • Full System Access</div>
                </div>
                <span className="text-[10px] px-2 py-0.5 rounded-full font-bold bg-[#fee2e2] text-[#991b1b]">
                  Admin
                </span>
              </button>

              <button
                type="button"
                onClick={() => selectDemoAccount('+919876543211', '888888')}
                className={`w-full text-left px-3.5 py-2.5 rounded-xl text-xs flex items-center justify-between border transition-all ${
                  phone === '+919876543211'
                    ? 'bg-[#dae2fd]/60 border-[#c7d2fe] text-[#1e1b4b]'
                    : 'bg-[#f8fafc] border-[#e2e8f0] text-[#334155] hover:bg-[#f1f5f9]'
                }`}
              >
                <div>
                  <div className="font-bold text-[#0f172a]">Kathmandu Municipality Admin</div>
                  <div className="text-[10px] text-[#64748b] font-mono">+919876543211 • Scoped: KMC (30608)</div>
                </div>
                <span className="text-[10px] px-2 py-0.5 rounded-full font-bold bg-[#dae2fd] text-[#1e1b4b]">
                  Municipality Admin
                </span>
              </button>

              <button
                type="button"
                onClick={() => selectDemoAccount('+919876543212', '777777')}
                className={`w-full text-left px-3.5 py-2.5 rounded-xl text-xs flex items-center justify-between border transition-all ${
                  phone === '+919876543212'
                    ? 'bg-[#dcfce7]/70 border-[#86efac] text-[#166534]'
                    : 'bg-[#f8fafc] border-[#e2e8f0] text-[#334155] hover:bg-[#f1f5f9]'
                }`}
              >
                <div>
                  <div className="font-bold text-[#0f172a]">Frontline Field Visitor</div>
                  <div className="text-[10px] text-[#64748b] font-mono">+919876543212 • Ward 17</div>
                </div>
                <span className="text-[10px] px-2 py-0.5 rounded-full font-bold bg-[#dcfce7] text-[#166534]">
                  Field Visitor
                </span>
              </button>
            </div>
          </div>
        </div>

      </div>

      <footer className="mt-8 py-4 px-6 text-xs text-slate-500 font-medium">
        <div className="max-w-md mx-auto flex flex-col sm:flex-row justify-between items-center gap-2">
          <div className="flex items-center space-x-2">
            <span className="hover:text-[#a50c1f] transition-colors cursor-pointer">Privacy Policy</span>
            <span>|</span>
            <span className="hover:text-[#a50c1f] transition-colors cursor-pointer">Terms of Services</span>
          </div>
          <div className="text-slate-600">
            Developed &amp; Maintained by Shivam Yadav
          </div>
        </div>
      </footer>
    </div>
  );
};
