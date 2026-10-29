import React from 'react';
import { useAuth } from '../context/AuthContext';
import { NepalEmblemSvg } from './NepalEmblemSvg';
import { LogOut, Shield, MapPin, Phone } from 'lucide-react';

export const Header: React.FC = () => {
  const { currentUser, logout, lang, toggleLang } = useAuth();

  const getRoleLabel = (role?: string) => {
    switch (role) {
      case 'admin':
        return lang === 'ne' ? 'प्रणाली प्रशासक (Federal Admin)' : 'Federal System Admin';
      case 'municipality_admin':
        return lang === 'ne' ? 'नगरपालिका प्रशासक (Palika Admin)' : 'Municipality Admin';
      case 'field_visitor':
        return lang === 'ne' ? 'क्षेत्र निरिक्षक (Field Visitor)' : 'Field Visitor';
      case 'fchv':
        return lang === 'ne' ? 'महिला स्वास्थ्य स्वयंसेविका (FCHV)' : 'FCHV';
      case 'ward_health_officer':
        return lang === 'ne' ? 'वार्ड स्वास्थ्य प्रमुख (WHO)' : 'Ward Health Officer';
      case 'palika_health_chief':
        return lang === 'ne' ? 'जनस्वास्थ्य प्रमुख (Chief)' : 'Palika Health Chief';
      case 'edcd_nodal':
        return lang === 'ne' ? 'इपिडिमियोलोजिस्ट (EDCD)' : 'EDCD Nodal';
      default:
        return role || 'Staff';
    }
  };

  return (
    <header className="bg-white border-b border-slate-200 sticky top-0 z-50 shadow-xs">
      {/* Top National Strip */}
      <div className="h-1.5 w-full bg-linear-to-r from-[#C8102E] via-[#1B4D9B] to-[#C8102E]" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
          {/* Left: Gov Branding & Crest */}
          <div className="flex items-center space-x-3.5">
            <NepalEmblemSvg size={58} className="shrink-0 drop-shadow-xs" />
            <div>
              <div className="flex items-center space-x-2">
                <span className="text-xs font-bold text-[#C8102E] tracking-wide uppercase">
                  {lang === 'ne' ? 'नेपाल सरकार • Government of Nepal' : 'Government of Nepal'}
                </span>
                <span className="text-slate-300">|</span>
                <span className="text-xs text-slate-500 font-mono">
                  {currentUser?.bs_ad_official_label || '२०८३ कार्तिक BS • 2026 AD'}
                </span>
              </div>
              <h1 className="text-base sm:text-lg font-bold text-[#1B4D9B] leading-tight">
                {lang === 'ne'
                  ? 'स्वास्थ्य तथा जनसंख्या मन्त्रालय — इपिडिमियोलोजी तथा रोग नियन्त्रण महाशाखा'
                  : 'Ministry of Health & Population — Epidemiology and Disease Control Division'}
              </h1>
              <p className="text-xs text-slate-600 font-medium">
                {lang === 'ne'
                  ? 'NidanIQ • नेपाल सार्वभौम भेक्टर निगरानी तथा प्रारम्भिक चेतावनी डिजिटल प्रणाली'
                  : 'NidanIQ • Sovereign Vector Surveillance & Dengue Early Warning Platform'}
              </p>
            </div>
          </div>

          {/* Right: User Status, Language Switch & Logout */}
          <div className="flex items-center space-x-3 justify-end flex-wrap gap-y-2">
            {/* Language Selector Pill (Matching OCR Gov screenshot) */}
            <div className="inline-flex rounded-md p-0.5 border border-slate-300 bg-slate-100 text-xs">
              <button
                type="button"
                onClick={() => lang !== 'en' && toggleLang()}
                className={`px-2.5 py-1 rounded font-medium transition-colors ${
                  lang === 'en'
                    ? 'bg-[#1B4D9B] text-white shadow-xs'
                    : 'text-slate-700 hover:text-slate-900'
                }`}
              >
                English
              </button>
              <button
                type="button"
                onClick={() => lang !== 'ne' && toggleLang()}
                className={`px-2.5 py-1 rounded font-medium transition-colors ${
                  lang === 'ne'
                    ? 'bg-[#1B4D9B] text-white shadow-xs'
                    : 'text-slate-700 hover:text-slate-900'
                }`}
              >
                नेपाली
              </button>
            </div>

            {/* Authenticated Staff Pill */}
            {currentUser && (
              <div className="flex items-center space-x-2 bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-xs">
                <Shield className="w-4 h-4 text-[#1B4D9B] shrink-0" />
                <div className="text-left">
                  <div className="font-semibold text-slate-800 flex items-center gap-1.5">
                    <span>{lang === 'ne' ? currentUser.full_name_ne || currentUser.full_name : currentUser.full_name}</span>
                    <span className="bg-[#1B4D9B]/10 text-[#1B4D9B] text-[10px] font-bold px-1.5 py-0.5 rounded">
                      {getRoleLabel(currentUser.role)}
                    </span>
                  </div>
                  <div className="text-[11px] text-slate-500 flex items-center gap-2">
                    <span className="flex items-center gap-0.5">
                      <MapPin className="w-3 h-3 text-slate-400" />
                      Palika: {currentUser.palika_code === '00000' || currentUser.role === 'admin' ? 'Federal / All' : currentUser.palika_code}
                    </span>
                    <span className="flex items-center gap-0.5">
                      <Phone className="w-3 h-3 text-slate-400" />
                      {currentUser.phone}
                    </span>
                  </div>
                </div>
              </div>
            )}

            {/* Logout Button */}
            {currentUser && (
              <button
                type="button"
                onClick={logout}
                title={lang === 'ne' ? 'लगआउट गर्नुहोस्' : 'Logout'}
                className="flex items-center space-x-1 px-3 py-1.5 text-xs font-semibold text-red-700 hover:bg-red-50 border border-red-200 rounded-lg transition-colors cursor-pointer"
              >
                <LogOut className="w-3.5 h-3.5" />
                <span>{lang === 'ne' ? 'बाहिरिनुहोस्' : 'Sign Out'}</span>
              </button>
            )}
          </div>
        </div>
      </div>
    </header>
  );
};
