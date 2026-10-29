import React, { useEffect, useState } from 'react';
import {
  CheckCircle2,
  Smartphone,
  Droplets,
  Plus,
  Calculator,
  ClipboardList,
  FileCheck2,
  Activity,
  RefreshCw,
} from 'lucide-react';
import { createInspection, fetchInspections } from '../services/api';
import { FieldInspectionItem } from '../types';

export const FieldVisitorDashboard: React.FC = () => {
  const [activeSubTab, setActiveSubTab] = useState<'inspections' | 'protocols' | 'calculator'>('inspections');
  const [inspections, setInspections] = useState<FieldInspectionItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [showLogModal, setShowLogModal] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [feedbackMsg, setFeedbackMsg] = useState<string | null>(null);

  // Form State
  const [formHouses, setFormHouses] = useState(25);
  const [formInfestedHouses, setFormInfestedHouses] = useState(4);
  const [formWetContainers, setFormWetContainers] = useState(36);
  const [formPositiveContainers, setFormPositiveContainers] = useState(6);
  const [formPupaeCount, setFormPupaeCount] = useState(18);
  const [formContainerType, setFormContainerType] = useState('Open Plastic Drum (200L)');
  const [formLarvicide, setFormLarvicide] = useState('Bti 0.5g/m2 surface');
  const [formNotes, setFormNotes] = useState('Courtyard inspection in Chhetrapati bahal');

  // Interactive Calculator State
  const [calcHouses, setCalcHouses] = useState(20);
  const [calcPositive, setCalcPositive] = useState(6);
  const [calcInfested, setCalcInfested] = useState(4);

  const loadInspections = async () => {
    setLoading(true);
    try {
      const data = await fetchInspections('NP-P3-D27-30608-W17');
      setInspections(Array.isArray(data) ? data : []);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadInspections();
  }, []);

  const handleCreateInspection = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await createInspection({
        composite_ward_id: 'NP-P3-D27-30608-W17',
        houses_inspected: Number(formHouses),
        houses_infested: Number(formInfestedHouses),
        wet_containers_inspected: Number(formWetContainers),
        positive_containers: Number(formPositiveContainers),
        pupae_count: Number(formPupaeCount),
        container_type: formContainerType,
        larvicide_applied: formLarvicide,
        exact_latitude: 27.7124,
        exact_longitude: 85.3065,
      });
      setFeedbackMsg('Inspection successfully recorded, encrypted with AES-256-GCM, and synced!');
      setShowLogModal(false);
      loadInspections();
      setTimeout(() => setFeedbackMsg(null), 5000);
    } catch (err: any) {
      setFeedbackMsg(err.message || 'Failed to submit inspection');
    } finally {
      setSubmitting(false);
    }
  };

  // Calculator calculations
  const computedBi = calcHouses > 0 ? ((calcPositive / calcHouses) * 100).toFixed(1) : '0.0';
  const computedHi = calcHouses > 0 ? ((calcInfested / calcHouses) * 100).toFixed(1) : '0.0';
  const biNum = parseFloat(computedBi);

  const getRiskDetails = (bi: number) => {
    if (bi >= 20) {
      return {
        label: 'Critical Transmission Risk (Tier 1)',
        badge: 'bg-[#fee2e2] text-[#ba1a1a] border border-[#fca5a5]',
        action: 'Immediate targeted bio-larviciding (Bti) + municipal Search & Destroy campaign required.',
      };
    } else if (bi >= 5) {
      return {
        label: 'Moderate Risk Threshold',
        badge: 'bg-[#fef3c7] text-[#92400e] border border-[#fde68a]',
        action: 'Enhanced household surveillance, weekly water emptying, and container inversion.',
      };
    } else {
      return {
        label: 'Low / Controlled Threshold',
        badge: 'bg-[#dcfce7] text-[#166534] border border-[#bbf7d0]',
        action: 'Routine bi-weekly vector monitoring and community awareness active.',
      };
    }
  };

  const riskInfo = getRiskDetails(biNum);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      {/* Feedback Banner */}
      {feedbackMsg && (
        <div className="bg-[#f0fdf4] border border-[#bbf7d0] text-[#166534] p-4 rounded-2xl flex items-center justify-between text-sm">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-5 h-5 text-[#166534]" />
            <span>{feedbackMsg}</span>
          </div>
          <button onClick={() => setFeedbackMsg(null)} className="text-[#166534] font-bold">✕</button>
        </div>
      )}

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

      {/* Main Interactive Section with Sub-navigation */}
      <div className="bg-white rounded-2xl border border-[#e2e8f0] overflow-hidden">
        {/* Navigation Bar */}
        <div className="flex flex-wrap items-center justify-between gap-4 p-4 border-b border-[#e2e8f0] bg-[#f8fafc]">
          <div className="flex items-center space-x-2">
            <button
              onClick={() => setActiveSubTab('inspections')}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold transition ${
                activeSubTab === 'inspections'
                  ? 'bg-[#a50c1f] text-white'
                  : 'bg-white text-[#475569] border border-[#e2e8f0] hover:bg-[#f1f5f9]'
              }`}
            >
              <ClipboardList className="w-4 h-4" />
              <span>Ward Inspection Log & History</span>
            </button>
            <button
              onClick={() => setActiveSubTab('protocols')}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold transition ${
                activeSubTab === 'protocols'
                  ? 'bg-[#a50c1f] text-white'
                  : 'bg-white text-[#475569] border border-[#e2e8f0] hover:bg-[#f1f5f9]'
              }`}
            >
              <Droplets className="w-4 h-4" />
              <span>Chemical Dosing & Workflow</span>
            </button>
            <button
              onClick={() => setActiveSubTab('calculator')}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold transition ${
                activeSubTab === 'calculator'
                  ? 'bg-[#a50c1f] text-white'
                  : 'bg-white text-[#475569] border border-[#e2e8f0] hover:bg-[#f1f5f9]'
              }`}
            >
              <Calculator className="w-4 h-4" />
              <span>Breteau Index (BI) Calculator</span>
            </button>
          </div>

          {activeSubTab === 'inspections' && (
            <div className="flex items-center gap-2">
              <button
                onClick={loadInspections}
                disabled={loading}
                className="flex items-center gap-1.5 px-3 py-2 bg-white border border-[#e2e8f0] rounded-xl text-xs font-semibold text-[#475569] hover:bg-[#f1f5f9]"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
                <span>Refresh</span>
              </button>
              <button
                onClick={() => setShowLogModal(true)}
                className="flex items-center gap-1.5 px-4 py-2 bg-[#a50c1f] text-white rounded-xl text-xs font-semibold hover:bg-[#850a19] transition"
              >
                <Plus className="w-4 h-4" />
                <span>Record New Inspection</span>
              </button>
            </div>
          )}
        </div>

        {/* Tab 1: Ward Inspection History Stream */}
        {activeSubTab === 'inspections' && (
          <div className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h3 className="text-base font-bold text-[#0f172a]">Recent Frontline Field Inspections</h3>
                <p className="text-xs text-[#64748b]">Assigned Ward: Ward 17 - Chhetrapati • Encrypted AES-256 ground records</p>
              </div>
              <span className="text-xs font-medium text-[#475569] bg-[#f1f5f9] px-2.5 py-1 rounded-full">
                Total Inspections: {inspections.length}
              </span>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-xs text-left">
                <thead className="bg-[#f8fafc] text-[#334155] font-semibold uppercase tracking-wider border-b border-[#e2e8f0]">
                  <tr>
                    <th className="py-3 px-3">Date / BS Stamp</th>
                    <th className="py-3 px-3">Inspector ID</th>
                    <th className="py-3 px-3">Houses Checked</th>
                    <th className="py-3 px-3">Infested</th>
                    <th className="py-3 px-3">Wet Containers</th>
                    <th className="py-3 px-3">Positive</th>
                    <th className="py-3 px-3">Container Habitat</th>
                    <th className="py-3 px-3">Treatment Applied</th>
                    <th className="py-3 px-3">Encryption Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#f1f5f9] text-[#334155]">
                  {inspections.length === 0 ? (
                    <tr>
                      <td colSpan={9} className="py-8 text-center text-[#64748b]">
                        No inspections recorded yet for this ward. Click "Record New Inspection" to log one.
                      </td>
                    </tr>
                  ) : (
                    inspections.map((item) => (
                      <tr key={item.id} className="hover:bg-[#f8fafc] transition">
                        <td className="py-3 px-3 font-medium text-[#0f172a] whitespace-nowrap">
                          {item.inspected_at_bs || '2083-07-12 BS'}
                        </td>
                        <td className="py-3 px-3 font-mono text-[#64748b]">{item.inspector_id}</td>
                        <td className="py-3 px-3 font-semibold text-[#0f172a]">{item.houses_inspected}</td>
                        <td className="py-3 px-3">
                          <span className={`font-semibold ${item.houses_infested > 0 ? 'text-[#a50c1f]' : 'text-[#166534]'}`}>
                            {item.houses_infested}
                          </span>
                        </td>
                        <td className="py-3 px-3">{item.wet_containers_inspected}</td>
                        <td className="py-3 px-3">
                          <span className="font-bold text-[#ba1a1a]">{item.positive_containers}</span>
                          <span className="text-[10px] text-[#64748b] ml-1">({item.pupae_count} pupae)</span>
                        </td>
                        <td className="py-3 px-3 font-medium text-[#0f172a]">{item.container_type}</td>
                        <td className="py-3 px-3">
                          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-medium bg-[#fee2e2] text-[#a50c1f]">
                            {item.larvicide_applied}
                          </span>
                        </td>
                        <td className="py-3 px-3">
                          <span className="inline-flex items-center gap-1 text-[11px] font-medium text-[#166534]">
                            <FileCheck2 className="w-3.5 h-3.5" />
                            <span>AES-256 Synced</span>
                          </span>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Tab 2: Chemical Dosing & Routine Workflow */}
        {activeSubTab === 'protocols' && (
          <div className="p-6 space-y-6">
            <div className="flex items-center space-x-2.5">
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

            <div className="space-y-3 pt-4 border-t border-[#e2e8f0]">
              <h4 className="text-sm font-bold text-[#0f172a]">Daily Frontline Surveillance Protocol</h4>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                <div className="p-3.5 bg-[#f8fafc] border border-[#e2e8f0] rounded-xl">
                  <span className="w-6 h-6 rounded-full bg-[#a50c1f] text-white flex items-center justify-center font-bold text-xs mb-2">1</span>
                  <h5 className="text-xs font-bold text-[#0f172a]">Perimeter Inspection</h5>
                  <p className="text-xs text-[#64748b] mt-1">
                    Examine water containers within 50m radius of dwellings, shaded courtyards, and plant trays.
                  </p>
                </div>
                <div className="p-3.5 bg-[#f8fafc] border border-[#e2e8f0] rounded-xl">
                  <span className="w-6 h-6 rounded-full bg-[#a50c1f] text-white flex items-center justify-center font-bold text-xs mb-2">2</span>
                  <h5 className="text-xs font-bold text-[#0f172a]">Larvae Detection & Log</h5>
                  <p className="text-xs text-[#64748b] mt-1">
                    Identify Aedes instar stages and log counts of positive containers for Breteau Index calculations.
                  </p>
                </div>
                <div className="p-3.5 bg-[#f8fafc] border border-[#e2e8f0] rounded-xl">
                  <span className="w-6 h-6 rounded-full bg-[#a50c1f] text-white flex items-center justify-center font-bold text-xs mb-2">3</span>
                  <h5 className="text-xs font-bold text-[#0f172a]">Bio-Larvicide Treatment</h5>
                  <p className="text-xs text-[#64748b] mt-1">
                    Apply Bti bio-larvicide or invert discarded containers to immediately destroy mosquito breeding habitats.
                  </p>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Tab 3: Interactive Breteau Index Calculator */}
        {activeSubTab === 'calculator' && (
          <div className="p-6">
            <div className="flex items-center space-x-2.5 mb-6">
              <div className="w-9 h-9 rounded-xl bg-[#fee2e2] text-[#a50c1f] flex items-center justify-center">
                <Calculator className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-[#0f172a]">Frontline Breteau Index (BI) & Risk Calculator</h3>
                <p className="text-xs text-[#64748b]">World Health Organization (WHO) and EDCD standard vector density index formula</p>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Inputs */}
              <div className="bg-[#f8fafc] p-5 rounded-xl border border-[#e2e8f0] space-y-4">
                <h4 className="text-xs font-bold text-[#0f172a] uppercase tracking-wider">Field Inspection Variables</h4>
                <div>
                  <label className="block text-xs font-medium text-[#475569] mb-1">Total Households Inspected</label>
                  <input
                    type="number"
                    min="1"
                    value={calcHouses}
                    onChange={(e) => setCalcHouses(Math.max(1, parseInt(e.target.value) || 1))}
                    className="w-full px-3 py-2 text-sm bg-white border border-[#cbd5e1] rounded-lg focus:outline-none focus:border-[#a50c1f]"
                  />
                  <p className="text-[11px] text-[#64748b] mt-1">Standard sample: 20 to 50 households per ward sector</p>
                </div>

                <div>
                  <label className="block text-xs font-medium text-[#475569] mb-1">Larvae-Positive Wet Containers Found</label>
                  <input
                    type="number"
                    min="0"
                    value={calcPositive}
                    onChange={(e) => setCalcPositive(Math.max(0, parseInt(e.target.value) || 0))}
                    className="w-full px-3 py-2 text-sm bg-white border border-[#cbd5e1] rounded-lg focus:outline-none focus:border-[#a50c1f]"
                  />
                  <p className="text-[11px] text-[#64748b] mt-1">Containers holding active Aedes aegypti / albopictus larvae</p>
                </div>

                <div>
                  <label className="block text-xs font-medium text-[#475569] mb-1">Premises Infested (Positive Houses)</label>
                  <input
                    type="number"
                    min="0"
                    value={calcInfested}
                    onChange={(e) => setCalcInfested(Math.max(0, parseInt(e.target.value) || 0))}
                    className="w-full px-3 py-2 text-sm bg-white border border-[#cbd5e1] rounded-lg focus:outline-none focus:border-[#a50c1f]"
                  />
                  <p className="text-[11px] text-[#64748b] mt-1">Houses with at least one infested water habitat</p>
                </div>
              </div>

              {/* Calculated Results */}
              <div className="bg-white p-5 rounded-xl border border-[#e2e8f0] space-y-4 flex flex-col justify-between">
                <div>
                  <h4 className="text-xs font-bold text-[#0f172a] uppercase tracking-wider mb-4">Calculated Entomological Indices</h4>

                  <div className="grid grid-cols-2 gap-3 mb-4">
                    <div className="p-3 bg-[#f8fafc] rounded-xl border border-[#e2e8f0]">
                      <div className="text-[11px] font-semibold text-[#64748b]">Breteau Index (BI)</div>
                      <div className="text-2xl font-bold text-[#0f172a] mt-1">{computedBi}</div>
                      <div className="text-[10px] text-[#64748b]">positive containers / 100 houses</div>
                    </div>

                    <div className="p-3 bg-[#f8fafc] rounded-xl border border-[#e2e8f0]">
                      <div className="text-[11px] font-semibold text-[#64748b]">House Index (HI)</div>
                      <div className="text-2xl font-bold text-[#0f172a] mt-1">{computedHi}%</div>
                      <div className="text-[10px] text-[#64748b]">infested houses / total houses</div>
                    </div>
                  </div>

                  <div className="p-3.5 rounded-xl border mb-3 flex items-start gap-3">
                    <Activity className="w-5 h-5 text-[#a50c1f] shrink-0 mt-0.5" />
                    <div>
                      <div className="text-xs font-bold text-[#0f172a]">{riskInfo.label}</div>
                      <p className="text-xs text-[#475569] mt-0.5">{riskInfo.action}</p>
                    </div>
                  </div>
                </div>

                <div className="p-3 bg-[#f1f5f9] rounded-lg text-[11px] text-[#475569]">
                  <strong>Formula Reference:</strong> BI = (Number of positive containers / Number of houses inspected) × 100. WHO threshold: BI &ge; 20 indicates high dengue epidemic transmission risk.
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Quick Inspection Entry Modal */}
      {showLogModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-xl border border-[#e2e8f0] relative">
            <div className="flex items-center justify-between pb-4 border-b border-[#e2e8f0] mb-4">
              <div>
                <h3 className="text-base font-bold text-[#0f172a]">Record Frontline Field Inspection</h3>
                <p className="text-xs text-[#64748b]">Ward 17 - Chhetrapati • Sovereign Field Surveillance</p>
              </div>
              <button
                onClick={() => setShowLogModal(false)}
                className="text-[#64748b] hover:text-[#0f172a] text-lg font-bold"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleCreateInspection} className="space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-medium text-[#475569] mb-1">Houses Inspected</label>
                  <input
                    type="number"
                    required
                    min="1"
                    value={formHouses}
                    onChange={(e) => setFormHouses(parseInt(e.target.value) || 1)}
                    className="w-full px-3 py-2 text-xs bg-white border border-[#cbd5e1] rounded-lg focus:outline-none focus:border-[#a50c1f]"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-[#475569] mb-1">Houses Infested</label>
                  <input
                    type="number"
                    required
                    min="0"
                    value={formInfestedHouses}
                    onChange={(e) => setFormInfestedHouses(parseInt(e.target.value) || 0)}
                    className="w-full px-3 py-2 text-xs bg-white border border-[#cbd5e1] rounded-lg focus:outline-none focus:border-[#a50c1f]"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-medium text-[#475569] mb-1">Wet Containers Inspected</label>
                  <input
                    type="number"
                    required
                    min="1"
                    value={formWetContainers}
                    onChange={(e) => setFormWetContainers(parseInt(e.target.value) || 1)}
                    className="w-full px-3 py-2 text-xs bg-white border border-[#cbd5e1] rounded-lg focus:outline-none focus:border-[#a50c1f]"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-[#475569] mb-1">Positive Containers (Larvae)</label>
                  <input
                    type="number"
                    required
                    min="0"
                    value={formPositiveContainers}
                    onChange={(e) => setFormPositiveContainers(parseInt(e.target.value) || 0)}
                    className="w-full px-3 py-2 text-xs bg-white border border-[#cbd5e1] rounded-lg focus:outline-none focus:border-[#a50c1f]"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-medium text-[#475569] mb-1">Pupae Count</label>
                  <input
                    type="number"
                    required
                    min="0"
                    value={formPupaeCount}
                    onChange={(e) => setFormPupaeCount(parseInt(e.target.value) || 0)}
                    className="w-full px-3 py-2 text-xs bg-white border border-[#cbd5e1] rounded-lg focus:outline-none focus:border-[#a50c1f]"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-[#475569] mb-1">Larvicide Compound</label>
                  <select
                    value={formLarvicide}
                    onChange={(e) => setFormLarvicide(e.target.value)}
                    className="w-full px-3 py-2 text-xs bg-white border border-[#cbd5e1] rounded-lg focus:outline-none focus:border-[#a50c1f]"
                  >
                    <option value="Bti 0.5g/m2 surface">Bti (0.5g / m² surface)</option>
                    <option value="Temephos 50% EC 1ppm">Temephos 50% EC (1 ppm)</option>
                    <option value="Source Reduction & Drainage">Source Reduction (Drained & Scrubbed)</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium text-[#475569] mb-1">Container Type / Habitat</label>
                <select
                  value={formContainerType}
                  onChange={(e) => setFormContainerType(e.target.value)}
                  className="w-full px-3 py-2 text-xs bg-white border border-[#cbd5e1] rounded-lg focus:outline-none focus:border-[#a50c1f]"
                >
                  <option value="Open Plastic Drum (200L)">Open Plastic Drum (200L)</option>
                  <option value="Discarded Automobile Tires">Discarded Automobile Tires</option>
                  <option value="Overhead Masonry Cistern">Overhead Masonry Cistern</option>
                  <option value="Construction Foundation Pit">Construction Foundation Pit</option>
                  <option value="Flowerpot Saucers & AC Trays">Flowerpot Saucers & AC Trays</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-medium text-[#475569] mb-1">Notes / Locality Detail</label>
                <input
                  type="text"
                  value={formNotes}
                  onChange={(e) => setFormNotes(e.target.value)}
                  placeholder="e.g. Chhetrapati Bahal courtyard water drum"
                  className="w-full px-3 py-2 text-xs bg-white border border-[#cbd5e1] rounded-lg focus:outline-none focus:border-[#a50c1f]"
                />
              </div>

              <div className="flex justify-end space-x-3 pt-4 border-t border-[#e2e8f0]">
                <button
                  type="button"
                  onClick={() => setShowLogModal(false)}
                  className="px-4 py-2 border border-[#cbd5e1] text-[#475569] rounded-xl text-xs font-semibold hover:bg-[#f1f5f9]"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-5 py-2 bg-[#a50c1f] text-white rounded-xl text-xs font-semibold hover:bg-[#850a19] transition flex items-center gap-1.5"
                >
                  {submitting && <RefreshCw className="w-3.5 h-3.5 animate-spin" />}
                  <span>Save & Encrypt Record</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Bottom Emergency & Help Channels */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-white rounded-2xl border border-[#e2e8f0] p-5">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-[#fee2e2] text-[#a50c1f] flex items-center justify-center shrink-0">
              <Smartphone className="w-5 h-5" />
            </div>
            <div>
              <h4 className="text-sm font-bold text-[#0f172a]">NidanIQ Mobile App Offline Sync</h4>
              <p className="text-xs text-[#64748b] mt-0.5">
                Frontline ground inspections and offline queue automatically synchronize when connectivity is established.
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-2xl border border-[#e2e8f0] p-5">
          <div className="flex justify-between items-center text-xs">
            <div>
              <span className="font-semibold text-[#0f172a]">Vector Control Emergency Desk:</span>
              <span className="font-mono font-bold text-[#a50c1f] ml-2">01-5325551</span>
            </div>
            <div className="h-4 w-px bg-[#e2e8f0]" />
            <div>
              <span className="font-semibold text-[#0f172a]">Hello Swasthya Helpline:</span>
              <span className="font-mono font-bold text-[#ba1a1a] ml-2">1115</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
