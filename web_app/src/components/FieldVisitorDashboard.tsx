import React from 'react';
import { useAuth } from '../context/AuthContext';
import { MapPin, Phone, Shield, CheckCircle, FileText, Smartphone } from 'lucide-react';

export const FieldVisitorDashboard: React.FC = () => {
  const { currentUser, lang } = useAuth();
  const wardId = currentUser?.assigned_wards[0] || 'NP-P3-D27-30608-W17';

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Welcome Card */}
      <div className="bg-linear-to-r from-[#1B4D9B] to-[#123770] rounded-xl text-white p-6 shadow-md mb-6">
        <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-white/20 text-xs font-bold uppercase tracking-wider mb-2">
          <Shield className="w-3.5 h-3.5" />
          <span>{lang === 'ne' ? 'फिल्ड भिजिटर ड्यासबोर्ड' : 'Field Surveillance Dashboard'}</span>
        </div>
        <h2 className="text-xl sm:text-2xl font-bold">
          {lang === 'ne' ? 'नमस्ते' : 'Welcome'}, {currentUser?.full_name || 'Field Officer'}
        </h2>
        <div className="flex flex-wrap items-center gap-4 text-xs text-slate-200 mt-2">
          <span className="flex items-center gap-1">
            <MapPin className="w-3.5 h-3.5 text-red-300" />
            Assigned Ward: <strong className="text-white font-mono">{wardId}</strong>
          </span>
          <span>•</span>
          <span className="flex items-center gap-1">
            <Phone className="w-3.5 h-3.5 text-emerald-300" />
            Phone: <strong className="text-white font-mono">{currentUser?.phone}</strong>
          </span>
          <span>•</span>
          <span>Palika: <strong className="text-white">{currentUser?.palika_code}</strong></span>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Left 2 Cols: Field Task Advisory */}
        <div className="md:col-span-2 space-y-6">
          <div className="bg-white rounded-xl border border-slate-200 p-6 shadow-xs">
            <h3 className="text-base font-bold text-slate-800 flex items-center gap-2 mb-3">
              <FileText className="w-5 h-5 text-[#1B4D9B]" />
              <span>{lang === 'ne' ? 'आजको दैनिक कार्यनिर्देशन (Today’s Protocol)' : 'Daily Inspection Protocol'}</span>
            </h3>
            <p className="text-xs text-slate-600 leading-relaxed mb-4">
              {lang === 'ne'
                ? 'तपाईंलाई तोकिएको वडामा "खोज र नष्ट गर" अभियान अन्तर्गत कम्तिमा २५ घरधुरी तथा पानी जमेका भाँडाहरूको अनुगमन गर्नुहोस्।'
                : 'Inspect at least 25 designated households, plastic drums, and water containers in your assigned ward.'}
            </p>

            <div className="space-y-3">
              <div className="p-3 bg-slate-50 border border-slate-200 rounded-lg flex items-start gap-3 text-xs">
                <CheckCircle className="w-4 h-4 text-[#107C41] shrink-0 mt-0.5" />
                <div>
                  <div className="font-bold text-slate-800">१. खुला पानीका ड्रम तथा कन्टेनर जाँच (Drum Inspection)</div>
                  <div className="text-slate-500">KUKL खानेपानी ड्रम, पुरानो टायर तथा गमलाका प्लेटहरूमा लामखुट्टेको लार्भा खोजी गर्नुहोस्।</div>
                </div>
              </div>

              <div className="p-3 bg-slate-50 border border-slate-200 rounded-lg flex items-start gap-3 text-xs">
                <CheckCircle className="w-4 h-4 text-[#107C41] shrink-0 mt-0.5" />
                <div>
                  <div className="font-bold text-slate-800">२. Bti जैविक विषादी प्रयोग (Biological Larvicide)</div>
                  <div className="text-slate-500">लार्भा भेटिएमा निर्धारित मात्रामा Bti वा टेमिफोस प्रयोग गरी नष्ट गर्नुहोस्।</div>
                </div>
              </div>

              <div className="p-3 bg-slate-50 border border-slate-200 rounded-lg flex items-start gap-3 text-xs">
                <CheckCircle className="w-4 h-4 text-[#107C41] shrink-0 mt-0.5" />
                <div>
                  <div className="font-bold text-slate-800">३. मोबाइल एपमार्फत तथ्याङ्क प्रविष्टि (Mobile Entry)</div>
                  <div className="text-slate-500">निरीक्षण गरिएका तथ्याङ्कहरू सिधै NidanIQ Sovereign मोबाइल एपमा प्रविष्ट गर्नुहोस्।</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Right Col: Mobile App QR & Hotline */}
        <div className="space-y-6">
          <div className="bg-white rounded-xl border border-slate-200 p-6 shadow-xs text-center">
            <Smartphone className="w-8 h-8 text-[#1B4D9B] mx-auto mb-2" />
            <h4 className="text-sm font-bold text-slate-800">
              {lang === 'ne' ? 'NidanIQ मोबाइल एप' : 'NidanIQ Mobile App'}
            </h4>
            <p className="text-xs text-slate-500 mt-1 mb-4">
              {lang === 'ne'
                ? 'अन-फिल्ड निरीक्षण प्रतिवेदन पठाउन आफ्नो एन्ड्रोइड वा आईओएस डिभाइसमा NidanIQ एप प्रयोग गर्नुहोस्।'
                : 'Field inspections, GPS household anchors, and AI larvae scans are performed via the mobile field app.'}
            </p>
            <div className="p-3 bg-blue-50 border border-blue-200 rounded-lg text-xs font-semibold text-[#1B4D9B]">
              Login on Mobile using <span className="font-mono font-bold">{currentUser?.phone}</span>
            </div>
          </div>

          <div className="bg-white rounded-xl border border-slate-200 p-6 shadow-xs">
            <h4 className="text-xs font-bold text-slate-700 uppercase tracking-wider mb-3">
              Emergency Hotlines
            </h4>
            <div className="space-y-2 text-xs">
              <div className="flex justify-between items-center py-1 border-b border-slate-100">
                <span className="text-slate-600">EDCD Teku Vector Section:</span>
                <span className="font-mono font-bold text-[#1B4D9B]">01-5325551</span>
              </div>
              <div className="flex justify-between items-center py-1 border-b border-slate-100">
                <span className="text-slate-600">Hello Swasthya Helpline:</span>
                <span className="font-mono font-bold text-[#C8102E]">1115</span>
              </div>
              <div className="flex justify-between items-center py-1">
                <span className="text-slate-600">Municipal IT Desk:</span>
                <span className="font-mono font-bold text-slate-800">01-4256789</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
