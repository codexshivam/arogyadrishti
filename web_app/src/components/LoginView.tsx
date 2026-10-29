import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { NepalEmblemSvg } from './NepalEmblemSvg';
import { Shield, KeyRound, Phone, ArrowRight, CheckCircle2, AlertCircle } from 'lucide-react';

export const LoginView: React.FC = () => {
  const { sendOtp, confirmOtp, lang, toggleLang } = useAuth();

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
      setError(err.message || 'OTP अनुरोध असफल भयो (Failed to request OTP)');
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
      setError(err.message || 'प्रमाणीकरण असफल भयो (Authentication failed)');
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
    <div className="min-h-screen bg-[#F4F6F9] flex flex-col justify-between">
      {/* Top Bar with Language Toggle */}
      <div className="bg-white border-b border-slate-200 px-6 py-2.5 flex justify-between items-center">
        <div className="flex items-center space-x-2 text-xs font-semibold text-slate-600">
          <span className="text-[#C8102E] font-bold">नेपाल सरकार</span>
          <span>•</span>
          <span>स्वास्थ्य तथा जनसंख्या मन्त्रालय</span>
          <span>•</span>
          <span>EDCD Teku</span>
        </div>
        <div className="inline-flex rounded-md p-0.5 border border-slate-300 bg-slate-100 text-xs">
          <button
            type="button"
            onClick={() => lang !== 'en' && toggleLang()}
            className={`px-3 py-1 rounded font-medium transition-colors ${
              lang === 'en' ? 'bg-[#1B4D9B] text-white shadow-xs' : 'text-slate-700 hover:text-slate-900'
            }`}
          >
            English
          </button>
          <button
            type="button"
            onClick={() => lang !== 'ne' && toggleLang()}
            className={`px-3 py-1 rounded font-medium transition-colors ${
              lang === 'ne' ? 'bg-[#1B4D9B] text-white shadow-xs' : 'text-slate-700 hover:text-slate-900'
            }`}
          >
            नेपाली
          </button>
        </div>
      </div>

      {/* Main Dual-Column Authentication Body */}
      <div className="max-w-6xl w-full mx-auto p-4 sm:p-6 lg:p-8 flex-1 flex flex-col justify-center">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch">

          {/* Left Advisory Card (Matches CAMIS OCR e-Services layout) */}
          <div className="lg:col-span-6 bg-white rounded-xl border border-slate-200 p-6 sm:p-8 flex flex-col justify-between shadow-xs">
            <div>
              <div className="bg-slate-50 border border-slate-200 rounded-xl p-6 text-center mb-6">
                <div className="w-36 h-36 mx-auto bg-white p-2.5 border-2 border-slate-300 rounded-lg flex items-center justify-center shadow-inner">
                  {/* Decorative QR Code Representation */}
                  <div className="w-full h-full border-4 border-slate-800 grid grid-cols-3 gap-1 p-1">
                    <div className="bg-slate-800 rounded-xs"></div>
                    <div className="bg-slate-800 rounded-xs"></div>
                    <div className="bg-transparent"></div>
                    <div className="bg-slate-800 rounded-xs"></div>
                    <div className="bg-[#1B4D9B] rounded-xs"></div>
                    <div className="bg-slate-800 rounded-xs"></div>
                    <div className="bg-transparent"></div>
                    <div className="bg-slate-800 rounded-xs"></div>
                    <div className="bg-slate-800 rounded-xs"></div>
                  </div>
                </div>
                <h3 className="text-sm font-semibold text-slate-800 mt-4">
                  {lang === 'ne'
                    ? 'यदि तपाईंलाई NidanIQ प्रणाली प्रवेशमा समस्या छ भने, सहयोगका लागि स्क्यान गर्नुहोस्।'
                    : 'Scan QR code if you need technical assistance logging into NidanIQ.'}
                </h3>
                <p className="text-xs text-slate-500 mt-1">
                  National Health Hotline: <strong className="text-[#C8102E]">1115</strong> (हलो स्वास्थ्य)
                </p>
              </div>

              {/* Informational Pillars */}
              <div className="grid grid-cols-3 gap-3 text-xs">
                <div className="border border-slate-200 rounded-lg p-3 bg-slate-50 text-center">
                  <div className="font-bold text-[#1B4D9B] mb-1">
                    {lang === 'ne' ? 'निर्देशिका' : 'User Manual'}
                  </div>
                  <div className="text-[11px] text-slate-500">SOP 2083</div>
                </div>
                <div className="border border-slate-200 rounded-lg p-3 bg-slate-50 text-center">
                  <div className="font-bold text-[#1B4D9B] mb-1">
                    {lang === 'ne' ? 'गोपनीयता' : 'Privacy'}
                  </div>
                  <div className="text-[11px] text-slate-500">Act 2075</div>
                </div>
                <div className="border border-slate-200 rounded-lg p-3 bg-slate-50 text-center">
                  <div className="font-bold text-[#1B4D9B] mb-1">
                    {lang === 'ne' ? 'डेटा सर्भर' : 'Sovereignty'}
                  </div>
                  <div className="text-[11px] text-slate-500">IDMC Durbar</div>
                </div>
              </div>
            </div>

            <div className="mt-6 pt-4 border-t border-slate-200 text-xs text-slate-500 flex items-center justify-between">
              <span>Security Standard: Twilio SMS Gateway & Ed25519</span>
              <span className="text-[#107C41] font-semibold flex items-center gap-1">
                <CheckCircle2 className="w-3.5 h-3.5" /> LIVE
              </span>
            </div>
          </div>

          {/* Right Login Card (Clean Nepal Gov Theming) */}
          <div className="lg:col-span-6 bg-white rounded-xl border border-slate-200 p-6 sm:p-8 flex flex-col justify-between shadow-xs">
            <div>
              {/* Crest & Title */}
              <div className="text-center pb-5 border-b border-slate-100">
                <NepalEmblemSvg size={64} className="mx-auto mb-2" />
                <div className="text-xs font-bold text-[#C8102E]">नेपाल सरकार • Government of Nepal</div>
                <div className="text-sm font-semibold text-slate-700">उद्योग, स्वास्थ्य तथा जनसंख्या मन्त्रालय</div>
                <div className="text-xs text-slate-500">इपिडिमियोलोजी तथा रोग नियन्त्रण महाशाखा (EDCD Teku)</div>
              </div>

              <div className="mt-5 mb-4">
                <h2 className="text-lg font-bold text-[#1B4D9B]">
                  {lang === 'ne' ? 'NidanIQ ई-सेवा प्रणाली प्रवेश' : 'Welcome to NidanIQ e-Services'}
                </h2>
                <p className="text-xs text-slate-600 mt-1">
                  {lang === 'ne'
                    ? 'आफ्नो दर्ता भएको मोबाइल नम्बर (+977 वा +91) बाट सुरक्षित प्रवेश गर्नुहोस्।'
                    : 'Authenticate your government health staff access via SMS OTP (+977 / +91).'}
                </p>
              </div>

              {/* Error Banner */}
              {error && (
                <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg flex items-start gap-2.5 text-xs text-red-800">
                  <AlertCircle className="w-4 h-4 text-red-600 shrink-0 mt-0.5" />
                  <div>{error}</div>
                </div>
              )}

              {/* Dev OTP Pill */}
              {devOtpHint && (
                <div className="mb-4 p-3 bg-amber-50 border border-amber-300 rounded-lg text-xs text-amber-900">
                  <div className="font-bold flex items-center gap-1">
                    <span>Twilio / Local OTP Code:</span>
                    <span className="font-mono bg-white px-2 py-0.5 rounded border border-amber-300 text-sm font-bold text-amber-950">
                      {devOtpHint}
                    </span>
                  </div>
                  <div className="text-[11px] text-amber-700 mt-0.5">
                    (Auto-filled for rapid sign-in verification)
                  </div>
                </div>
              )}

              {/* Step 1: Phone Input Form */}
              {step === 'phone' ? (
                <form onSubmit={handleRequestOtp} className="space-y-4">
                  <div>
                    <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wider">
                      {lang === 'ne' ? 'मोबाइल नम्बर (+977 / +91)' : 'Mobile Phone Number (+977 / +91)'}
                    </label>
                    <div className="relative">
                      <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                        <Phone className="h-4 w-4 text-slate-400" />
                      </div>
                      <input
                        type="text"
                        value={phone}
                        onChange={(e) => setPhone(e.target.value)}
                        placeholder="+919876543210 or +9779841000017"
                        className="block w-full pl-9 pr-3 py-2.5 border border-slate-300 rounded-lg text-sm font-mono focus:outline-hidden focus:ring-2 focus:ring-[#1B4D9B] focus:border-transparent bg-slate-50/50"
                        required
                      />
                    </div>
                    <p className="text-[11px] text-slate-500 mt-1">
                      {lang === 'ne'
                        ? 'नेपाल (+977) तथा भारत (+91) मोबाइल नम्बर समर्थित छन्।'
                        : 'Supports sovereign Nepal (+977) and Indian (+91) mobile numbers.'}
                    </p>
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wider">
                      {lang === 'ne' ? 'सुरक्षा पिन (Security PIN)' : 'Security PIN'}
                    </label>
                    <div className="relative">
                      <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                        <KeyRound className="h-4 w-4 text-slate-400" />
                      </div>
                      <input
                        type="password"
                        value={pin}
                        onChange={(e) => setPin(e.target.value)}
                        placeholder="6-digit PIN"
                        className="block w-full pl-9 pr-3 py-2.5 border border-slate-300 rounded-lg text-sm font-mono focus:outline-hidden focus:ring-2 focus:ring-[#1B4D9B] focus:border-transparent bg-slate-50/50"
                        required
                      />
                    </div>
                  </div>

                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full bg-[#1B4D9B] hover:bg-[#123770] text-white font-bold py-2.5 px-4 rounded-lg text-sm transition-all shadow-xs flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
                  >
                    <span>{loading ? 'पठाउँदै...' : lang === 'ne' ? 'OTP पठाउनुहोस्' : 'Send SMS OTP'}</span>
                    <ArrowRight className="w-4 h-4" />
                  </button>
                </form>
              ) : (
                /* Step 2: OTP Verification Form */
                <form onSubmit={handleVerifyOtp} className="space-y-4">
                  <div>
                    <div className="flex justify-between items-center mb-1.5">
                      <label className="text-xs font-bold text-slate-700 uppercase tracking-wider">
                        {lang === 'ne' ? '६-अंकीय OTP कोड (6-Digit OTP)' : '6-Digit SMS OTP'}
                      </label>
                      <button
                        type="button"
                        onClick={() => setStep('phone')}
                        className="text-xs text-[#1B4D9B] hover:underline cursor-pointer"
                      >
                        {lang === 'ne' ? 'नम्बर बदल्नुहोस्' : 'Change Phone'}
                      </button>
                    </div>
                    <input
                      type="text"
                      maxLength={6}
                      value={otp}
                      onChange={(e) => setOtp(e.target.value)}
                      placeholder="e.g. 123456"
                      className="block w-full text-center tracking-widest text-xl font-bold py-2.5 border border-slate-300 rounded-lg font-mono focus:outline-hidden focus:ring-2 focus:ring-[#1B4D9B] bg-slate-50/50"
                      required
                      autoFocus
                    />
                  </div>

                  <button
                    type="submit"
                    disabled={loading || otp.length < 4}
                    className="w-full bg-[#1B4D9B] hover:bg-[#123770] text-white font-bold py-2.5 px-4 rounded-lg text-sm transition-all shadow-xs flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
                  >
                    <Shield className="w-4 h-4" />
                    <span>{loading ? 'प्रमाणीकरण गर्दै...' : lang === 'ne' ? 'प्रवेश गर्नुहोस् (Verify & Login)' : 'Verify & Enter Portal'}</span>
                  </button>
                </form>
              )}

              {/* Quick Demo Pre-Seeded Profiles */}
              <div className="mt-6 pt-4 border-t border-slate-200">
                <div className="text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-2">
                  {lang === 'ne' ? 'परीक्षण खाताहरू (Quick Role Testers):' : 'Pre-Authorized Demo Accounts:'}
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
                  <button
                    type="button"
                    onClick={() => selectDemoAccount('+919876543210', '999999')}
                    className="p-2 border border-slate-200 rounded-lg hover:border-[#1B4D9B] bg-slate-50 text-left cursor-pointer transition-colors"
                  >
                    <div className="font-bold text-[#1B4D9B] flex items-center gap-1">
                      <span>🛡️ Federal Admin (+91)</span>
                    </div>
                    <div className="text-[11px] text-slate-500 font-mono">+919876543210 (PIN: 999999)</div>
                  </button>

                  <button
                    type="button"
                    onClick={() => selectDemoAccount('+919876543211', '888888')}
                    className="p-2 border border-slate-200 rounded-lg hover:border-[#1B4D9B] bg-slate-50 text-left cursor-pointer transition-colors"
                  >
                    <div className="font-bold text-[#1B4D9B] flex items-center gap-1">
                      <span>🏛️ KMC Municipality Admin (+91)</span>
                    </div>
                    <div className="text-[11px] text-slate-500 font-mono">+919876543211 (PIN: 888888)</div>
                  </button>

                  <button
                    type="button"
                    onClick={() => selectDemoAccount('+919876543212', '777777')}
                    className="p-2 border border-slate-200 rounded-lg hover:border-[#1B4D9B] bg-slate-50 text-left cursor-pointer transition-colors"
                  >
                    <div className="font-bold text-[#107C41] flex items-center gap-1">
                      <span>🔍 Field Visitor (+91)</span>
                    </div>
                    <div className="text-[11px] text-slate-500 font-mono">+919876543212 (PIN: 777777)</div>
                  </button>

                  <button
                    type="button"
                    onClick={() => selectDemoAccount('+9779800000001', '999999')}
                    className="p-2 border border-slate-200 rounded-lg hover:border-[#1B4D9B] bg-slate-50 text-left cursor-pointer transition-colors"
                  >
                    <div className="font-bold text-[#C8102E] flex items-center gap-1">
                      <span>🇳🇵 Federal Admin (+977)</span>
                    </div>
                    <div className="text-[11px] text-slate-500 font-mono">+9779800000001 (PIN: 999999)</div>
                  </button>
                </div>
              </div>
            </div>

            <div className="mt-5 text-center text-[11px] text-slate-400">
              Government of Nepal • Integrated Data Management Center (IDMC Singha Durbar)
            </div>
          </div>

        </div>
      </div>

      {/* Footer (Matches MoHP screenshot Singhadurbar info bar) */}
      <footer className="bg-[#123770] text-white text-xs py-3 px-6 text-center border-t border-slate-800">
        <div className="max-w-6xl mx-auto flex flex-col sm:flex-row justify-between items-center gap-2 text-slate-300">
          <div>
            सिंहदरबार, काठमाडौँ, नेपाल (Singhadurbar, Kathmandu, Nepal) • info@mohp.gov.np
          </div>
          <div>
            जाडो: 9:00 AM - 4:00 PM | गर्मी: 9:00 AM - 5:00 PM (कार्यालय समय)
          </div>
        </div>
      </footer>
    </div>
  );
};
