import React from 'react';
import { useAuth } from '../context/AuthContext';
import { MapPin, Phone, Shield, CheckCircle2, Smartphone, Droplets, Compass } from 'lucide-react';

export const FieldVisitorDashboard: React.FC = () => {
  const { currentUser } = useAuth();
  const wardId = currentUser?.assigned_wards[0] || 'NP-P3-D27-30608-W17';

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      {/* Welcome Banner */}
      <div className="bg-linear-to-r from-blue-700 via-indigo-700 to-slate-800 rounded-2xl text-white p-6 sm:p-8 shadow-sm">
        <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-white/15 text-xs font-semibold tracking-wide mb-3">
          <Shield className="w-3.5 h-3.5 text-blue-300" />
          <span>Field Surveillance & Inspection Console</span>
        </div>
        <h2 className="text-2xl sm:text-3xl font-extrabold tracking-tight">
          Welcome, {currentUser?.full_name || 'Field Officer'}
        </h2>
        <p className="text-blue-100 text-xs sm:text-sm mt-1 max-w-2xl">
          Frontline vector surveillance station for household breeding habitat inspections, larval identification, and focal bio-larviciding.
        </p>
        <div className="flex flex-wrap items-center gap-4 text-xs text-blue-200 mt-4 pt-4 border-t border-white/10">
          <span className="flex items-center gap-1.5 bg-white/10 px-3 py-1 rounded-lg">
            <MapPin className="w-3.5 h-3.5 text-rose-300" />
            Assigned Ward: <strong className="text-white font-mono">{wardId}</strong>
          </span>
          <span className="flex items-center gap-1.5 bg-white/10 px-3 py-1 rounded-lg">
            <Phone className="w-3.5 h-3.5 text-emerald-300" />
            Contact Phone: <strong className="text-white font-mono">{currentUser?.phone}</strong>
          </span>
          <span className="flex items-center gap-1.5 bg-white/10 px-3 py-1 rounded-lg">
            <Compass className="w-3.5 h-3.5 text-amber-300" />
            Palika Code: <strong className="text-white font-mono">{currentUser?.palika_code}</strong>
          </span>
        </div>
      </div>

      {/* Metrics Row */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white rounded-xl border border-slate-200 p-5 shadow-2xs">
          <div className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Today's Inspection Target</div>
          <div className="text-2xl font-bold text-slate-900 mt-2">25 <span className="text-xs font-normal text-slate-400">households</span></div>
          <div className="text-xs text-emerald-600 font-medium mt-1">18 inspected • 7 remaining</div>
        </div>
        <div className="bg-white rounded-xl border border-slate-200 p-5 shadow-2xs">
          <div className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Active Breteau Index (BI)</div>
          <div className="text-2xl font-bold text-amber-600 mt-2">28.4 <span className="text-xs font-normal text-slate-400">/ 100</span></div>
          <div className="text-xs text-amber-700 font-medium mt-1">Moderate-to-High risk tier</div>
        </div>
        <div className="bg-white rounded-xl border border-slate-200 p-5 shadow-2xs">
          <div className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Sites Neutralized</div>
          <div className="text-2xl font-bold text-blue-600 mt-2">12 <span className="text-xs font-normal text-slate-400">habitats</span></div>
          <div className="text-xs text-slate-500 font-medium mt-1">Bti & Temephos treated</div>
        </div>
        <div className="bg-white rounded-xl border border-slate-200 p-5 shadow-2xs">
          <div className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Mobile Field Sync</div>
          <div className="text-2xl font-bold text-emerald-600 mt-2 flex items-center gap-1.5">
            <CheckCircle2 className="w-5 h-5 text-emerald-500" />
            <span>Online</span>
          </div>
          <div className="text-xs text-slate-500 font-medium mt-1">Encrypted local queue synced</div>
        </div>
      </div>

      {/* Main Content Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left 2 Cols: Field Protocols & Dosing Guide */}
        <div className="lg:col-span-2 space-y-6">
          {/* Chemical Dosing Standards */}
          <div className="bg-white rounded-xl border border-slate-200 p-6 shadow-2xs">
            <div className="flex items-center space-x-2.5 mb-4">
              <div className="w-8 h-8 rounded-lg bg-blue-50 text-blue-600 flex items-center justify-center">
                <Droplets className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-slate-900">Standard Chemical Dosing & Application Guide</h3>
                <p className="text-xs text-slate-500">Official technical guidelines for frontline vector control operations</p>
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-xs text-left">
                <thead className="bg-slate-50 text-slate-700 font-bold uppercase tracking-wider border-b border-slate-200">
                  <tr>
                    <th className="py-2.5 px-3">Larvicide Compound</th>
                    <th className="py-2.5 px-3">Target Container / Water Type</th>
                    <th className="py-2.5 px-3">Standard Dosing Rate</th>
                    <th className="py-2.5 px-3">Action Interval</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 text-slate-600">
                  <tr>
                    <td className="py-3 px-3 font-semibold text-slate-900">
                      Bti (Bacillus thuringiensis israelensis)
                    </td>
                    <td className="py-3 px-3">Open water tanks, shallow pools, unsealed drums</td>
                    <td className="py-3 px-3 font-mono text-blue-700 font-bold">0.5 g / m² surface</td>
                    <td className="py-3 px-3">Every 7 to 10 days</td>
                  </tr>
                  <tr>
                    <td className="py-3 px-3 font-semibold text-slate-900">
                      Temephos 50% EC
                    </td>
                    <td className="py-3 px-3">Domestic water reservoirs, non-potable storage cisterns</td>
                    <td className="py-3 px-3 font-mono text-blue-700 font-bold">1 ppm (2 ml per 1,000 L)</td>
                    <td className="py-3 px-3">Every 14 to 21 days</td>
                  </tr>
                  <tr>
                    <td className="py-3 px-3 font-semibold text-slate-900">
                      Source Reduction ("Search & Destroy")
                    </td>
                    <td className="py-3 px-3">Discarded tires, plastic trays, flowerpot saucers</td>
                    <td className="py-3 px-3 font-mono text-emerald-700 font-bold">Physical emptying & scrub</td>
                    <td className="py-3 px-3">Twice weekly</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          {/* Routine Field Protocol */}
          <div className="bg-white rounded-xl border border-slate-200 p-6 shadow-2xs">
            <h3 className="text-base font-bold text-slate-900 mb-3">Field Inspection Workflow</h3>
            <div className="space-y-3">
              <div className="p-3.5 bg-slate-50 border border-slate-200 rounded-xl flex items-start gap-3">
                <span className="w-6 h-6 rounded-full bg-blue-600 text-white flex items-center justify-center font-bold text-xs shrink-0">1</span>
                <div>
                  <h4 className="text-xs font-bold text-slate-900">Household Perimeter & Habitat Inspection</h4>
                  <p className="text-xs text-slate-600 mt-0.5">
                    Inspect domestic water containers, overhead tanks, discarded tires, and shaded pooling areas within 50 meters of dwellings.
                  </p>
                </div>
              </div>

              <div className="p-3.5 bg-slate-50 border border-slate-200 rounded-xl flex items-start gap-3">
                <span className="w-6 h-6 rounded-full bg-blue-600 text-white flex items-center justify-center font-bold text-xs shrink-0">2</span>
                <div>
                  <h4 className="text-xs font-bold text-slate-900">Larval Identification & Mobile AI Scan</h4>
                  <p className="text-xs text-slate-600 mt-0.5">
                    Use the NidanIQ Mobile App camera to scan larvae specimens for instar stage determination and automated Breteau Index calculations.
                  </p>
                </div>
              </div>

              <div className="p-3.5 bg-slate-50 border border-slate-200 rounded-xl flex items-start gap-3">
                <span className="w-6 h-6 rounded-full bg-blue-600 text-white flex items-center justify-center font-bold text-xs shrink-0">3</span>
                <div>
                  <h4 className="text-xs font-bold text-slate-900">Targeted Biological Larviciding</h4>
                  <p className="text-xs text-slate-600 mt-0.5">
                    Apply Bti bio-larvicide or Temephos in exact measured doses to positive stagnant pools and record treatment batch codes.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Right Col: Mobile App Station */}
        <div className="space-y-6">
          <div className="bg-white rounded-xl border border-slate-200 p-6 shadow-2xs text-center">
            <div className="w-12 h-12 rounded-2xl bg-blue-50 text-blue-600 flex items-center justify-center mx-auto mb-3">
              <Smartphone className="w-6 h-6" />
            </div>
            <h4 className="text-sm font-bold text-slate-900">NidanIQ Mobile Field App</h4>
            <p className="text-xs text-slate-500 mt-1 mb-4 leading-relaxed">
              Ground-level household inspections, GPS coordinates verification, and offline surveys must be logged using the official mobile application.
            </p>
            <div className="p-3 bg-slate-50 border border-slate-200 rounded-xl text-xs text-slate-700">
              Authorized Phone: <span className="font-mono font-bold text-blue-600">{currentUser?.phone}</span>
            </div>
          </div>

          <div className="bg-white rounded-xl border border-slate-200 p-6 shadow-2xs">
            <h4 className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-3">Emergency Contact Channels</h4>
            <div className="space-y-2.5 text-xs">
              <div className="flex justify-between items-center py-1.5 border-b border-slate-100">
                <span className="text-slate-600">Central Vector Control Desk</span>
                <span className="font-mono font-bold text-blue-600">01-5325551</span>
              </div>
              <div className="flex justify-between items-center py-1.5 border-b border-slate-100">
                <span className="text-slate-600">Emergency Health Helpline</span>
                <span className="font-mono font-bold text-rose-600">1115</span>
              </div>
              <div className="flex justify-between items-center py-1.5">
                <span className="text-slate-600">Municipal Operations Desk</span>
                <span className="font-mono font-bold text-slate-800">01-4256789</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
