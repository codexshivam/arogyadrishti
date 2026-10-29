import React from 'react';
import { useAuth } from '../context/AuthContext';
import { CheckCircle2, Smartphone, Droplets } from 'lucide-react';

export const FieldVisitorDashboard: React.FC = () => {
  const { currentUser } = useAuth();

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      {/* Metrics Row */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white rounded-2xl border border-[#e2e8f0] p-5">
          <div className="text-xs font-semibold text-[#64748b] uppercase tracking-wider">Today's Inspection Target</div>
          <div className="text-2xl font-bold text-[#0f172a] mt-2">25 <span className="text-xs font-normal text-[#64748b]">households</span></div>
          <div className="text-xs text-[#166534] font-medium mt-1">18 inspected • 7 remaining</div>
        </div>
        <div className="bg-white rounded-2xl border border-[#e2e8f0] p-5">
          <div className="text-xs font-semibold text-[#64748b] uppercase tracking-wider">Active Breteau Index (BI)</div>
          <div className="text-2xl font-bold text-[#b45309] mt-2">28.4 <span className="text-xs font-normal text-[#64748b]">/ 100</span></div>
          <div className="text-xs text-[#92400e] font-medium mt-1">Moderate risk threshold</div>
        </div>
        <div className="bg-white rounded-2xl border border-[#e2e8f0] p-5">
          <div className="text-xs font-semibold text-[#64748b] uppercase tracking-wider">Sites Neutralized</div>
          <div className="text-2xl font-bold text-[#a50c1f] mt-2">12 <span className="text-xs font-normal text-[#64748b]">habitats</span></div>
          <div className="text-xs text-[#64748b] font-medium mt-1">Bti & Temephos treated</div>
        </div>
        <div className="bg-white rounded-2xl border border-[#e2e8f0] p-5">
          <div className="text-xs font-semibold text-[#64748b] uppercase tracking-wider">Mobile Field Sync</div>
          <div className="text-2xl font-bold text-[#166534] mt-2 flex items-center gap-1.5">
            <CheckCircle2 className="w-5 h-5 text-[#166534]" />
            <span>Online</span>
          </div>
          <div className="text-xs text-[#64748b] font-medium mt-1">Encrypted local queue synced</div>
        </div>
      </div>

      {/* Main Content Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left 2 Cols: Field Protocols & Dosing Guide */}
        <div className="lg:col-span-2 space-y-6">
          {/* Chemical Dosing Standards */}
          <div className="bg-white rounded-2xl border border-[#e2e8f0] p-6">
            <div className="flex items-center space-x-2.5 mb-4">
              <div className="w-9 h-9 rounded-xl bg-[#fee2e2] text-[#a50c1f] flex items-center justify-center">
                <Droplets className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-[#0f172a]">Standard Chemical Dosing & Application Guide</h3>
                <p className="text-xs text-[#64748b]">Official technical guidelines for frontline vector control operations</p>
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-xs text-left">
                <thead className="bg-[#f8fafc] text-[#334155] font-semibold uppercase tracking-wider border-b border-[#e2e8f0]">
                  <tr>
                    <th className="py-2.5 px-3">Larvicide Compound</th>
                    <th className="py-2.5 px-3">Target Container / Water Type</th>
                    <th className="py-2.5 px-3">Standard Dosing Rate</th>
                    <th className="py-2.5 px-3">Action Interval</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#f1f5f9] text-[#334155]">
                  <tr>
                    <td className="py-3 px-3 font-semibold text-[#0f172a]">
                      Bti (Bacillus thuringiensis israelensis)
                    </td>
                    <td className="py-3 px-3">Open water tanks, shallow pools, unsealed drums</td>
                    <td className="py-3 px-3 font-mono text-[#a50c1f] font-bold">0.5 g / m² surface</td>
                    <td className="py-3 px-3">Every 7 to 10 days</td>
                  </tr>
                  <tr>
                    <td className="py-3 px-3 font-semibold text-[#0f172a]">
                      Temephos 50% EC
                    </td>
                    <td className="py-3 px-3">Domestic water reservoirs, non-potable storage cisterns</td>
                    <td className="py-3 px-3 font-mono text-[#a50c1f] font-bold">1 ppm (2 ml per 1,000 L)</td>
                    <td className="py-3 px-3">Every 14 to 21 days</td>
                  </tr>
                  <tr>
                    <td className="py-3 px-3 font-semibold text-[#0f172a]">
                      Source Reduction ("Search & Destroy")
                    </td>
                    <td className="py-3 px-3">Discarded tires, plastic trays, flowerpot saucers</td>
                    <td className="py-3 px-3 font-mono text-[#166534] font-bold">Physical emptying & scrub</td>
                    <td className="py-3 px-3">Twice weekly</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          {/* Routine Field Protocol */}
          <div className="bg-white rounded-2xl border border-[#e2e8f0] p-6">
            <h3 className="text-base font-bold text-[#0f172a] mb-3">Field Inspection Workflow</h3>
            <div className="space-y-3">
              <div className="p-3.5 bg-[#f8fafc] border border-[#e2e8f0] rounded-xl flex items-start gap-3">
                <span className="w-6 h-6 rounded-full bg-[#a50c1f] text-white flex items-center justify-center font-bold text-xs shrink-0">1</span>
                <div>
                  <h4 className="text-xs font-bold text-[#0f172a]">Household Perimeter & Habitat Inspection</h4>
                  <p className="text-xs text-[#475569] mt-0.5">
                    Inspect domestic water containers, overhead tanks, discarded tires, and shaded pooling areas within 50 meters of dwellings.
                  </p>
                </div>
              </div>

              <div className="p-3.5 bg-[#f8fafc] border border-[#e2e8f0] rounded-xl flex items-start gap-3">
                <span className="w-6 h-6 rounded-full bg-[#a50c1f] text-white flex items-center justify-center font-bold text-xs shrink-0">2</span>
                <div>
                  <h4 className="text-xs font-bold text-[#0f172a]">Larval Identification & Mobile AI Scan</h4>
                  <p className="text-xs text-[#475569] mt-0.5">
                    Use the NidanIQ Mobile App camera to scan larvae specimens for instar stage determination and automated Breteau Index calculations.
                  </p>
                </div>
              </div>

              <div className="p-3.5 bg-[#f8fafc] border border-[#e2e8f0] rounded-xl flex items-start gap-3">
                <span className="w-6 h-6 rounded-full bg-[#a50c1f] text-white flex items-center justify-center font-bold text-xs shrink-0">3</span>
                <div>
                  <h4 className="text-xs font-bold text-[#0f172a]">Targeted Biological Larviciding</h4>
                  <p className="text-xs text-[#475569] mt-0.5">
                    Apply Bti bio-larvicide or Temephos in exact measured doses to positive stagnant pools and record treatment batch codes.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Right Col: Mobile App Station */}
        <div className="space-y-6">
          <div className="bg-white rounded-2xl border border-[#e2e8f0] p-6 text-center">
            <div className="w-12 h-12 rounded-2xl bg-[#fee2e2] text-[#a50c1f] flex items-center justify-center mx-auto mb-3">
              <Smartphone className="w-6 h-6" />
            </div>
            <h4 className="text-sm font-bold text-[#0f172a]">NidanIQ Mobile Field App</h4>
            <p className="text-xs text-[#64748b] mt-1 mb-4 leading-relaxed">
              Ground-level household inspections, GPS coordinates verification, and offline surveys must be logged using the official mobile application.
            </p>
            <div className="p-3 bg-[#f8fafc] border border-[#cbd5e1] rounded-xl text-xs text-[#334155]">
              Authorized Phone: <span className="font-mono font-bold text-[#a50c1f]">{currentUser?.phone}</span>
            </div>
          </div>

          <div className="bg-white rounded-2xl border border-[#e2e8f0] p-6">
            <h4 className="text-xs font-bold text-[#64748b] uppercase tracking-wider mb-3">Emergency Contact Channels</h4>
            <div className="space-y-2.5 text-xs">
              <div className="flex justify-between items-center py-1.5 border-b border-[#f1f5f9]">
                <span className="text-[#475569]">Vector Control Desk</span>
                <span className="font-mono font-bold text-[#a50c1f]">01-5325551</span>
              </div>
              <div className="flex justify-between items-center py-1.5 border-b border-[#f1f5f9]">
                <span className="text-[#475569]">Emergency Health Helpline</span>
                <span className="font-mono font-bold text-[#ba1a1a]">1115</span>
              </div>
              <div className="flex justify-between items-center py-1.5">
                <span className="text-[#475569]">Municipal Operations Desk</span>
                <span className="font-mono font-bold text-[#0f172a]">01-4256789</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
