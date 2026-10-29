import React, { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import {
  createFacility,
  createRrtUnit,
  createStaffUser,
  deleteFacility,
  deleteRrtUnit,
  deleteStaffUser,
  fetchFacilities,
  fetchRrtUnits,
  fetchSpatialHierarchy,
  fetchStaffUsers,
  fetchTickets,
  updateFacility,
  updateRrtUnit,
  updateTicketStatus,
} from '../services/api';
import {
  AdministrativeHierarchy,
  EscalationTicketItem,
  HealthFacilityItem,
  PalikaOption,
  RrtVehicleItem,
  StaffUserItem,
} from '../types';
import {
  AlertTriangle,
  Building2,
  CheckCircle,
  Filter,
  Pencil,
  Plus,
  RefreshCw,
  Trash2,
  Truck,
  Users,
  X,
} from 'lucide-react';

export const MunicipalityAdminDashboard: React.FC = () => {
  const { currentUser } = useAuth();
  const palikaCode = currentUser?.palika_code || '30608';

  const [activeTab, setActiveTab] = useState<'users' | 'facilities' | 'rrt' | 'tickets'>('users');
  const [hierarchy, setHierarchy] = useState<AdministrativeHierarchy | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Data States (All scoped to palikaCode)
  const [usersList, setUsersList] = useState<StaffUserItem[]>([]);
  const [facilitiesList, setFacilitiesList] = useState<HealthFacilityItem[]>([]);
  const [rrtList, setRrtList] = useState<RrtVehicleItem[]>([]);
  const [ticketsList, setTicketsList] = useState<EscalationTicketItem[]>([]);

  // Filter States
  const [filterWard, setFilterWard] = useState<string>('');
  const [filterStatus, setFilterStatus] = useState<string>('');

  // Modals
  const [showAddVisitorModal, setShowAddVisitorModal] = useState(false);
  const [showFacilityModal, setShowFacilityModal] = useState(false);
  const [editingFacility, setEditingFacility] = useState<HealthFacilityItem | null>(null);
  const [showRrtModal, setShowRrtModal] = useState(false);
  const [editingRrt, setEditingRrt] = useState<RrtVehicleItem | null>(null);

  // Field Visitor Form State (Strictly field_visitor role only)
  const [visitorName, setVisitorName] = useState('');
  const [visitorNameNe, setVisitorNameNe] = useState('');
  const [visitorPhone, setVisitorPhone] = useState('+919876543230');
  const [visitorDesignation, setVisitorDesignation] = useState('Frontline Vector Surveillance Visitor');
  const [visitorWard, setVisitorWard] = useState('');
  const [visitorPin, setVisitorPin] = useState('123456');

  // Facility Form State
  const [facFacilityId, setFacFacilityId] = useState('');
  const [facName, setFacName] = useState('');
  const [facNameNe, setFacNameNe] = useState('');
  const [facType, setFacType] = useState('Urban Health Promotion Center (UHPC)');
  const [facWard, setFacWard] = useState('');
  const [facTotalBeds, setFacTotalBeds] = useState(15);
  const [facDengueBeds, setFacDengueBeds] = useState(4);
  const [facNs1Kits, setFacNs1Kits] = useState(50);
  const [facEmergencyPhone, setFacEmergencyPhone] = useState('01-4256789');

  // RRT Form State
  const [rrtVehicleId, setRrtVehicleId] = useState('');
  const [rrtPlateNumber, setRrtPlateNumber] = useState('');
  const [rrtBaseWard, setRrtBaseWard] = useState('');
  const [rrtTeamLead, setRrtTeamLead] = useState('');
  const [rrtDriverPhone, setRrtDriverPhone] = useState('+919876543231');
  const [rrtBtiKg, setRrtBtiKg] = useState(40.0);
  const [rrtTemephosL, setRrtTemephosL] = useState(20.0);
  const [rrtUlvMounted, setRrtUlvMounted] = useState(true);
  const [rrtStatus, setRrtStatus] = useState<'AVAILABLE' | 'DISPATCHED' | 'MAINTENANCE'>('AVAILABLE');

  // Load Hierarchy on Mount
  useEffect(() => {
    fetchSpatialHierarchy()
      .then((data) => {
        setHierarchy(data);
        const pal = data?.palikas?.find((p) => p.palika_code === palikaCode);
        if (pal && pal.wards && pal.wards.length > 0) {
          setVisitorWard(pal.wards[0].composite_ward_id);
          setFacWard(pal.wards[0].composite_ward_id);
          setRrtBaseWard(pal.wards[0].composite_ward_id);
        }
      })
      .catch((e) => console.error(e));
  }, [palikaCode]);

  const currentPalikaObj: PalikaOption | undefined = hierarchy?.palikas?.find(
    (p) => p.palika_code === palikaCode
  );

  // Scoped Data Fetching
  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      if (activeTab === 'users') {
        const users = await fetchStaffUsers(palikaCode);
        setUsersList(users);
      } else if (activeTab === 'facilities') {
        const facs = await fetchFacilities(palikaCode);
        setFacilitiesList(facs);
      } else if (activeTab === 'rrt') {
        const vans = await fetchRrtUnits(palikaCode);
        setRrtList(vans);
      } else if (activeTab === 'tickets') {
        const tix = await fetchTickets({
          palika_code: palikaCode,
          composite_ward_id: filterWard || undefined,
          status: filterStatus || undefined,
        });
        setTicketsList(tix);
      }
    } catch (err: any) {
      setError(err.message || 'Failed to load municipality data');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [activeTab, palikaCode, filterWard, filterStatus]);

  // Handle Add Field Visitor (Municipality Admin can ONLY add field visitors)
  const handleCreateFieldVisitor = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    try {
      const pal = currentPalikaObj;
      const targetWard = visitorWard || (pal && pal.wards[0]?.composite_ward_id) || `NP-P3-D27-${palikaCode}-W01`;

      await createStaffUser({
        phone: visitorPhone,
        full_name: visitorName,
        full_name_ne: visitorNameNe || visitorName,
        designation: visitorDesignation,
        role: 'field_visitor', // Strictly locked to field_visitor
        province_code: pal?.province_code || 3,
        district_code: pal?.district_code || 27,
        palika_code: palikaCode,
        assigned_wards: [targetWard],
        pin: visitorPin,
      });

      setSuccessMsg('Field visitor successfully created!');
      setShowAddVisitorModal(false);
      setVisitorName('');
      setVisitorNameNe('');
      loadData();
      setTimeout(() => setSuccessMsg(null), 3000);
    } catch (err: any) {
      setError(err.message || 'Failed to create field visitor');
    }
  };

  // Facility Actions (Scoped to this municipality)
  const handleSaveFacility = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const pal = currentPalikaObj;
      if (editingFacility) {
        await updateFacility(editingFacility.id, {
          name: facName,
          name_ne: facNameNe,
          facility_type: facType,
          composite_ward_id: facWard,
          total_beds: Number(facTotalBeds),
          dengue_ward_beds: Number(facDengueBeds),
          ns1_rdt_kits_stock: Number(facNs1Kits),
          emergency_phone: facEmergencyPhone,
        });
        setSuccessMsg('Facility updated!');
      } else {
        await createFacility({
          facility_id: facFacilityId || `FAC-${Date.now().toString().slice(-6)}`,
          name: facName,
          name_ne: facNameNe || facName,
          facility_type: facType,
          palika_code: palikaCode, // Locked
          composite_ward_id: facWard,
          province_code: pal?.province_code || 3,
          district_code: pal?.district_code || 27,
          total_beds: Number(facTotalBeds),
          dengue_ward_beds: Number(facDengueBeds),
          ns1_rdt_kits_stock: Number(facNs1Kits),
          emergency_phone: facEmergencyPhone,
          hello_swasthya_hotline: '1115',
          status: 'OPERATIONAL',
        });
        setSuccessMsg('Health Facility created in your municipality!');
      }
      setShowFacilityModal(false);
      setEditingFacility(null);
      loadData();
      setTimeout(() => setSuccessMsg(null), 3000);
    } catch (err: any) {
      setError(err.message || 'Failed to save health facility');
    }
  };

  const handleDeleteFacility = async (id: string) => {
    if (!confirm('Are you sure you want to delete this facility?')) return;
    try {
      await deleteFacility(id);
      loadData();
    } catch (err: any) {
      setError(err.message || 'Failed to delete facility');
    }
  };

  // RRT Actions (Scoped to this municipality)
  const handleSaveRrt = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      if (editingRrt) {
        await updateRrtUnit(editingRrt.id, {
          team_lead_name: rrtTeamLead,
          driver_phone: rrtDriverPhone,
          bti_stock_kg: Number(rrtBtiKg),
          temephos_stock_liters: Number(rrtTemephosL),
          ulv_equipment_mounted: Boolean(rrtUlvMounted),
          status: rrtStatus,
        });
        setSuccessMsg('RRT Van updated!');
      } else {
        await createRrtUnit({
          vehicle_id: rrtVehicleId || `RRT-VAN-${Date.now().toString().slice(-4)}`,
          plate_number: rrtPlateNumber || 'BA-2-JHA-5555',
          palika_code: palikaCode, // Locked
          base_ward_id: rrtBaseWard,
          team_lead_name: rrtTeamLead,
          team_lead_name_ne: rrtTeamLead,
          driver_phone: rrtDriverPhone,
          bti_stock_kg: Number(rrtBtiKg),
          temephos_stock_liters: Number(rrtTemephosL),
          ulv_equipment_mounted: Boolean(rrtUlvMounted),
          status: rrtStatus,
        });
        setSuccessMsg('RRT Van created in your municipality!');
      }
      setShowRrtModal(false);
      setEditingRrt(null);
      loadData();
      setTimeout(() => setSuccessMsg(null), 3000);
    } catch (err: any) {
      setError(err.message || 'Failed to save RRT unit');
    }
  };

  const handleDeleteRrt = async (id: string) => {
    if (!confirm('Are you sure you want to delete this RRT unit?')) return;
    try {
      await deleteRrtUnit(id);
      loadData();
    } catch (err: any) {
      setError(err.message || 'Failed to delete RRT van');
    }
  };

  const handleUpdateTicket = async (ticketCode: string, status: 'OPEN' | 'ASSIGNED' | 'RESOLVED') => {
    try {
      await updateTicketStatus(ticketCode, status);
      setSuccessMsg(`Ticket ${ticketCode} updated to ${status}`);
      loadData();
      setTimeout(() => setSuccessMsg(null), 3000);
    } catch (err: any) {
      setError(err.message || 'Failed to update ticket');
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
      {/* Municipality Header Card */}
      <div className="bg-linear-to-r from-[#a50c1f] via-[#1657A2] to-[#7c0012] rounded-xl text-white p-6 shadow-md mb-6">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-white/20 text-xs font-bold uppercase tracking-wider mb-2">
              <Building2 className="w-3.5 h-3.5" />
              <span>{currentPalikaObj?.palika_type || 'Municipality'} • Code: {palikaCode}</span>
            </div>
            <h2 className="text-xl sm:text-2xl font-bold">
              {currentPalikaObj?.palika_name || 'Kathmandu Metropolitan City'}
              {currentPalikaObj?.palika_name_np && (
                <span className="text-sm font-normal text-slate-200 ml-2">
                  ({currentPalikaObj.palika_name_np})
                </span>
              )}
            </h2>
            <p className="text-xs sm:text-sm text-slate-200 mt-1 max-w-2xl">
              {'Dedicated municipal operations: field visitor recruitment, local health centers, van fleet, and ward tickets.'}
            </p>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={loadData}
              disabled={loading}
              className="bg-white/10 hover:bg-white/20 text-white px-3.5 py-2 rounded-lg text-xs font-semibold flex items-center gap-1.5 cursor-pointer transition-colors"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
              <span>{'Refresh'}</span>
            </button>
          </div>
        </div>

        {/* Municipality Metrics */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-6 pt-6 border-t border-white/10">
          <div className="bg-white/10 rounded-lg p-3">
            <div className="text-xs text-slate-300 font-medium">Municipality Wards</div>
            <div className="text-xl font-bold mt-0.5">{currentPalikaObj?.wards?.length || 32}</div>
          </div>
          <div className="bg-white/10 rounded-lg p-3">
            <div className="text-xs text-slate-300 font-medium">Municipal Field Staff</div>
            <div className="text-xl font-bold mt-0.5">{usersList.length}</div>
          </div>
          <div className="bg-white/10 rounded-lg p-3">
            <div className="text-xs text-slate-300 font-medium">Local Health Facilities</div>
            <div className="text-xl font-bold mt-0.5">{facilitiesList.length}</div>
          </div>
          <div className="bg-white/10 rounded-lg p-3">
            <div className="text-xs text-slate-300 font-medium">Local RRT Fleet</div>
            <div className="text-xl font-bold mt-0.5">{rrtList.length}</div>
          </div>
        </div>
      </div>

      {/* Notifications */}
      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-xs text-red-800 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <AlertTriangle className="w-4 h-4 text-red-600 shrink-0" />
            <span>{error}</span>
          </div>
          <button onClick={() => setError(null)} className="cursor-pointer text-slate-400 hover:text-slate-600">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {successMsg && (
        <div className="mb-4 p-3 bg-emerald-50 border border-emerald-300 rounded-lg text-xs text-emerald-800 flex items-center gap-2">
          <CheckCircle className="w-4 h-4 text-emerald-600 shrink-0" />
          <span>{successMsg}</span>
        </div>
      )}

      {/* Tabs */}
      <div className="flex border-b border-slate-200 mb-6 bg-white rounded-t-lg px-2 shadow-xs overflow-x-auto">
        <button
          onClick={() => setActiveTab('users')}
          className={`py-3 px-4 font-semibold text-xs sm:text-sm flex items-center gap-2 border-b-2 cursor-pointer transition-colors whitespace-nowrap ${
            activeTab === 'users'
              ? 'border-[#a50c1f] text-[#a50c1f]'
              : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          <Users className="w-4 h-4" />
          <span>{'Field Visitors Management'}</span>
        </button>

        <button
          onClick={() => setActiveTab('facilities')}
          className={`py-3 px-4 font-semibold text-xs sm:text-sm flex items-center gap-2 border-b-2 cursor-pointer transition-colors whitespace-nowrap ${
            activeTab === 'facilities'
              ? 'border-[#a50c1f] text-[#a50c1f]'
              : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          <Building2 className="w-4 h-4" />
          <span>{'Local Health Centers'}</span>
        </button>

        <button
          onClick={() => setActiveTab('rrt')}
          className={`py-3 px-4 font-semibold text-xs sm:text-sm flex items-center gap-2 border-b-2 cursor-pointer transition-colors whitespace-nowrap ${
            activeTab === 'rrt'
              ? 'border-[#a50c1f] text-[#a50c1f]'
              : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          <Truck className="w-4 h-4" />
          <span>{'Municipal RRT Fleet'}</span>
        </button>

        <button
          onClick={() => setActiveTab('tickets')}
          className={`py-3 px-4 font-semibold text-xs sm:text-sm flex items-center gap-2 border-b-2 cursor-pointer transition-colors whitespace-nowrap ${
            activeTab === 'tickets'
              ? 'border-[#a50c1f] text-[#a50c1f]'
              : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          <AlertTriangle className="w-4 h-4" />
          <span>{'Area Requests & Tickets'}</span>
        </button>
      </div>

      {/* Filter / Actions Bar */}
      <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-xs mb-6 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="text-xs font-semibold text-slate-600 flex items-center gap-1.5">
            <Filter className="w-4 h-4 text-[#a50c1f]" />
            <span>Scope: {currentPalikaObj?.palika_name}</span>
          </div>

          {/* Ward filter for this municipality */}
          {currentPalikaObj && currentPalikaObj.wards && currentPalikaObj.wards.length > 0 && (
            <select
              value={filterWard}
              onChange={(e) => setFilterWard(e.target.value)}
              className="text-xs border border-slate-300 rounded-lg px-2.5 py-1.5 bg-slate-50 font-medium"
            >
              <option value="">All Municipality Wards</option>
              {(currentPalikaObj.wards || []).map((w) => (
                <option key={w.composite_ward_id} value={w.composite_ward_id}>
                  Ward {w.ward_no} - {w.locality_name}
                </option>
              ))}
            </select>
          )}

          {activeTab === 'tickets' && (
            <select
              value={filterStatus}
              onChange={(e) => setFilterStatus(e.target.value)}
              className="text-xs border border-slate-300 rounded-lg px-2.5 py-1.5 bg-slate-50 font-medium"
            >
              <option value="">All Statuses</option>
              <option value="OPEN">Open</option>
              <option value="ASSIGNED">Assigned</option>
              <option value="RESOLVED">Resolved</option>
            </select>
          )}
        </div>

        <div>
          {activeTab === 'users' && (
            <button
              onClick={() => setShowAddVisitorModal(true)}
              className="bg-[#a50c1f] hover:bg-[#7c0012] text-white px-3.5 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 cursor-pointer shadow-xs"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>{'Add Field Visitor'}</span>
            </button>
          )}

          {activeTab === 'facilities' && (
            <button
              onClick={() => {
                setEditingFacility(null);
                setFacName('');
                setFacNameNe('');
                setFacFacilityId(`FAC-${palikaCode}-${Date.now().toString().slice(-4)}`);
                setShowFacilityModal(true);
              }}
              className="bg-[#a50c1f] hover:bg-[#7c0012] text-white px-3.5 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 cursor-pointer shadow-xs"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>{'Add Health Center'}</span>
            </button>
          )}

          {activeTab === 'rrt' && (
            <button
              onClick={() => {
                setEditingRrt(null);
                setRrtVehicleId(`RRT-${palikaCode}-${Date.now().toString().slice(-3)}`);
                setRrtPlateNumber('BA-2-JHA-');
                setRrtTeamLead('');
                setShowRrtModal(true);
              }}
              className="bg-[#a50c1f] hover:bg-[#7c0012] text-white px-3.5 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 cursor-pointer shadow-xs"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>{'Add RRT Van'}</span>
            </button>
          )}
        </div>
      </div>

      {/* TAB 1: Staff Users Table */}
      {activeTab === 'users' && (
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden shadow-xs">
          <div className="px-6 py-4 border-b border-slate-200 flex justify-between items-center bg-slate-50/50">
            <div>
              <h3 className="text-sm font-bold text-slate-800">
                {'Municipal Field Inspection Staff'}
              </h3>
              <p className="text-xs text-slate-500">
                {'Municipality admins are authorized to recruit and assign field visitors for this area.'}
              </p>
            </div>
            <span className="text-xs font-bold text-slate-600 bg-slate-200 px-2.5 py-1 rounded-full">
              {usersList.length} Active Staff
            </span>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-xs">
              <thead className="bg-slate-50 text-slate-700 font-bold uppercase tracking-wider text-[11px]">
                <tr>
                  <th className="px-6 py-3 text-left">Staff Name</th>
                  <th className="px-6 py-3 text-left">Phone (+977 / +91)</th>
                  <th className="px-6 py-3 text-left">Role</th>
                  <th className="px-6 py-3 text-left">Assigned Ward</th>
                  <th className="px-6 py-3 text-left">Status</th>
                  <th className="px-6 py-3 text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 bg-white">
                {usersList.map((user) => (
                  <tr key={user.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-6 py-3.5 whitespace-nowrap">
                      <div className="font-bold text-slate-900">{user.full_name}</div>
                      <div className="text-[11px] text-slate-500">{user.full_name_ne}</div>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap font-mono text-slate-700">
                      {user.phone}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap">
                      <span className="bg-emerald-100 text-emerald-800 text-[10px] font-bold px-2 py-0.5 rounded uppercase">
                        {user.role}
                      </span>
                      <div className="text-[11px] text-slate-500 mt-0.5">{user.designation}</div>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap font-mono text-slate-600">
                      {user.assigned_wards.join(', ')}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap">
                      <span className="inline-flex items-center gap-1 text-[11px] text-emerald-700 font-bold bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                        <CheckCircle className="w-3 h-3" /> Active
                      </span>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-right">
                      {user.role === 'field_visitor' && (
                        <button
                          onClick={async () => {
                            if (confirm('Delete this field visitor?')) {
                              await deleteStaffUser(user.id);
                              loadData();
                            }
                          }}
                          className="text-red-600 hover:text-red-800 p-1 cursor-pointer"
                          title="Delete Field Visitor"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 2: Facilities Table (Scoped to this municipality) */}
      {activeTab === 'facilities' && (
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden shadow-xs">
          <div className="px-6 py-4 border-b border-slate-200 flex justify-between items-center bg-slate-50/50">
            <div>
              <h3 className="text-sm font-bold text-slate-800">
                {'Health Facilities in Your Municipality'}
              </h3>
              <p className="text-xs text-slate-500">
                Manage beds, dengue units, and NS1 test kits across your municipal area.
              </p>
            </div>
            <span className="text-xs font-bold text-slate-600 bg-slate-200 px-2.5 py-1 rounded-full">
              {facilitiesList.length} Facilities
            </span>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-xs">
              <thead className="bg-slate-50 text-slate-700 font-bold uppercase tracking-wider text-[11px]">
                <tr>
                  <th className="px-6 py-3 text-left">Facility Name</th>
                  <th className="px-6 py-3 text-left">Facility Type</th>
                  <th className="px-6 py-3 text-left">Ward</th>
                  <th className="px-6 py-3 text-center">Total Beds</th>
                  <th className="px-6 py-3 text-center">Dengue Beds</th>
                  <th className="px-6 py-3 text-center">NS1 Kits</th>
                  <th className="px-6 py-3 text-left">Emergency Phone</th>
                  <th className="px-6 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 bg-white">
                {facilitiesList.map((fac) => (
                  <tr key={fac.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-6 py-3.5 whitespace-nowrap">
                      <div className="font-bold text-slate-900">{fac.name}</div>
                      <div className="text-[11px] text-slate-500">{fac.name_ne}</div>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-slate-600">
                      {fac.facility_type}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap font-mono text-slate-600">
                      {fac.composite_ward_id}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center font-bold text-slate-800">
                      {fac.total_beds}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center font-bold text-[#DC2626]">
                      {fac.dengue_ward_beds}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center font-bold text-emerald-700">
                      {fac.ns1_rdt_kits_stock}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap font-mono text-slate-600">
                      {fac.emergency_phone || '1115'}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-right space-x-2">
                      <button
                        onClick={() => {
                          setEditingFacility(fac);
                          setFacName(fac.name);
                          setFacNameNe(fac.name_ne);
                          setFacType(fac.facility_type);
                          setFacWard(fac.composite_ward_id);
                          setFacTotalBeds(fac.total_beds);
                          setFacDengueBeds(fac.dengue_ward_beds);
                          setFacNs1Kits(fac.ns1_rdt_kits_stock);
                          setFacEmergencyPhone(fac.emergency_phone);
                          setShowFacilityModal(true);
                        }}
                        className="text-[#a50c1f] hover:text-[#7c0012] p-1 cursor-pointer"
                        title="Edit Facility"
                      >
                        <Pencil className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleDeleteFacility(fac.id)}
                        className="text-red-600 hover:text-red-800 p-1 cursor-pointer"
                        title="Delete Facility"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 3: RRT Vans Table (Scoped to this municipality) */}
      {activeTab === 'rrt' && (
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden shadow-xs">
          <div className="px-6 py-4 border-b border-slate-200 flex justify-between items-center bg-slate-50/50">
            <div>
              <h3 className="text-sm font-bold text-slate-800">
                {'Municipal Rapid Response Fleet'}
              </h3>
              <p className="text-xs text-slate-500">
                Chemical stocks and rapid deployment units assigned to your municipality.
              </p>
            </div>
            <span className="text-xs font-bold text-slate-600 bg-slate-200 px-2.5 py-1 rounded-full">
              {rrtList.length} Vehicles
            </span>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-xs">
              <thead className="bg-slate-50 text-slate-700 font-bold uppercase tracking-wider text-[11px]">
                <tr>
                  <th className="px-6 py-3 text-left">Vehicle ID</th>
                  <th className="px-6 py-3 text-left">Plate</th>
                  <th className="px-6 py-3 text-left">Base Ward</th>
                  <th className="px-6 py-3 text-left">Team Lead</th>
                  <th className="px-6 py-3 text-center">Bti Stock</th>
                  <th className="px-6 py-3 text-center">Temephos Stock</th>
                  <th className="px-6 py-3 text-center">ULV</th>
                  <th className="px-6 py-3 text-center">Status</th>
                  <th className="px-6 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 bg-white">
                {rrtList.map((van) => (
                  <tr key={van.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-6 py-3.5 whitespace-nowrap font-bold text-slate-800">
                      {van.vehicle_id}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap font-mono font-bold text-slate-700">
                      <span className="bg-red-50 text-red-900 border border-red-200 px-2 py-0.5 rounded">
                        {van.plate_number}
                      </span>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap font-mono text-slate-600">
                      {van.base_ward_id}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap">
                      <div className="font-semibold text-slate-800">{van.team_lead_name}</div>
                      <div className="text-[11px] text-slate-500 font-mono">{van.driver_phone}</div>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center font-bold text-slate-800">
                      {van.bti_stock_kg} kg
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center font-bold text-slate-800">
                      {van.temephos_stock_liters} L
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center">
                      <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                        van.ulv_equipment_mounted ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-600'
                      }`}>
                        {van.ulv_equipment_mounted ? 'Mounted' : 'No'}
                      </span>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center">
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                        van.status === 'AVAILABLE' ? 'bg-emerald-100 text-emerald-800' : 'bg-amber-100 text-amber-800'
                      }`}>
                        {van.status}
                      </span>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-right space-x-2">
                      <button
                        onClick={() => {
                          setEditingRrt(van);
                          setRrtVehicleId(van.vehicle_id);
                          setRrtPlateNumber(van.plate_number);
                          setRrtBaseWard(van.base_ward_id);
                          setRrtTeamLead(van.team_lead_name);
                          setRrtDriverPhone(van.driver_phone);
                          setRrtBtiKg(van.bti_stock_kg);
                          setRrtTemephosL(van.temephos_stock_liters);
                          setRrtUlvMounted(van.ulv_equipment_mounted);
                          setRrtStatus(van.status);
                          setShowRrtModal(true);
                        }}
                        className="text-[#a50c1f] hover:text-[#7c0012] p-1 cursor-pointer"
                        title="Edit Van"
                      >
                        <Pencil className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleDeleteRrt(van.id)}
                        className="text-red-600 hover:text-red-800 p-1 cursor-pointer"
                        title="Delete Van"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 4: Support Tickets (Municipality Only) */}
      {activeTab === 'tickets' && (
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden shadow-xs">
          <div className="px-6 py-4 border-b border-slate-200 flex justify-between items-center bg-slate-50/50">
            <div>
              <h3 className="text-sm font-bold text-slate-800">
                {'Outbreak Tickets in Your Municipal Jurisdiction'}
              </h3>
              <p className="text-xs text-slate-500">
                You have exclusive jurisdiction over tickets filed inside this municipality.
              </p>
            </div>
            <span className="text-xs font-bold text-slate-600 bg-slate-200 px-2.5 py-1 rounded-full">
              {ticketsList.length} Tickets
            </span>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-xs">
              <thead className="bg-slate-50 text-slate-700 font-bold uppercase tracking-wider text-[11px]">
                <tr>
                  <th className="px-6 py-3 text-left">Ticket Code</th>
                  <th className="px-6 py-3 text-left">Ward</th>
                  <th className="px-6 py-3 text-left">Severity</th>
                  <th className="px-6 py-3 text-left">Category</th>
                  <th className="px-6 py-3 text-left">Summary</th>
                  <th className="px-6 py-3 text-center">Status</th>
                  <th className="px-6 py-3 text-right">Update Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 bg-white">
                {ticketsList.map((t) => (
                  <tr key={t.ticket_code} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-6 py-3.5 whitespace-nowrap font-mono font-bold text-[#a50c1f]">
                      {t.ticket_code}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap font-mono text-slate-600">
                      {t.composite_ward_id}
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap">
                      <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                        t.severity_tier === 'CRITICAL' ? 'bg-red-100 text-red-800' : 'bg-amber-100 text-amber-800'
                      }`}>
                        {t.severity_tier}
                      </span>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap font-semibold text-slate-800">
                      {t.category}
                    </td>
                    <td className="px-6 py-3.5 max-w-sm text-slate-700">
                      <div className="truncate">{t.summary}</div>
                      <div className="text-[11px] text-slate-400">{t.created_at_bs}</div>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-center">
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                        t.status === 'RESOLVED' ? 'bg-emerald-100 text-emerald-800' : 'bg-amber-100 text-amber-800'
                      }`}>
                        {t.status}
                      </span>
                    </td>
                    <td className="px-6 py-3.5 whitespace-nowrap text-right space-x-1.5">
                      {t.status !== 'ASSIGNED' && (
                        <button
                          onClick={() => handleUpdateTicket(t.ticket_code, 'ASSIGNED')}
                          className="px-2 py-1 text-[11px] font-semibold bg-[#fee2e2]/40 text-[#991b1b] border border-[#fca5a5] rounded hover:bg-blue-100 cursor-pointer"
                        >
                          Assign
                        </button>
                      )}
                      {t.status !== 'RESOLVED' && (
                        <button
                          onClick={() => handleUpdateTicket(t.ticket_code, 'RESOLVED')}
                          className="px-2 py-1 text-[11px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 rounded hover:bg-emerald-100 cursor-pointer"
                        >
                          Resolve
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* MODAL: Add Field Visitor (Municipality Admin ONLY allows field visitors) */}
      {showAddVisitorModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4 z-50 overflow-y-auto">
          <div className="bg-white rounded-xl max-w-lg w-full p-6 shadow-xl border border-slate-200 my-8">
            <div className="flex justify-between items-center pb-3 border-b border-slate-200">
              <h3 className="text-base font-bold text-slate-800 flex items-center gap-2">
                <Users className="w-5 h-5 text-[#a50c1f]" />
                <span>{'Add New Field Visitor'}</span>
              </h3>
              <button onClick={() => setShowAddVisitorModal(false)} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreateFieldVisitor} className="space-y-4 mt-4">
              <div className="p-2.5 bg-[#fee2e2]/40 border border-[#fca5a5] rounded-lg text-xs text-[#7c0012]">
                <strong>Authority Notice:</strong> Municipality Admins are authorized to register Frontline Field Visitors and FCHVs for <strong>{currentPalikaObj?.palika_name}</strong>.
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">
                  Assigned Ward
                </label>
                <select
                  value={visitorWard}
                  onChange={(e) => setVisitorWard(e.target.value)}
                  className="w-full text-xs border border-slate-300 rounded-lg p-2.5 bg-slate-50"
                  required
                >
                  {(currentPalikaObj?.wards || []).map((w) => (
                    <option key={w.composite_ward_id} value={w.composite_ward_id}>
                      Ward {w.ward_no} - {w.locality_name} ({w.composite_ward_id})
                    </option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Full Name (English)</label>
                  <input
                    type="text"
                    value={visitorName}
                    onChange={(e) => setVisitorName(e.target.value)}
                    placeholder="e.g. Sunil Basnet"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Secondary / Local Name</label>
                  <input
                    type="text"
                    value={visitorNameNe}
                    onChange={(e) => setVisitorNameNe(e.target.value)}
                    placeholder="e.g. Sunil Basnet"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Mobile Phone (+977 / +91)</label>
                  <input
                    type="text"
                    value={visitorPhone}
                    onChange={(e) => setVisitorPhone(e.target.value)}
                    placeholder="+91XXXXXXXXXX"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Initial PIN</label>
                  <input
                    type="password"
                    value={visitorPin}
                    onChange={(e) => setVisitorPin(e.target.value)}
                    placeholder="6 digits"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Designation</label>
                <input
                  type="text"
                  value={visitorDesignation}
                  onChange={(e) => setVisitorDesignation(e.target.value)}
                  className="w-full text-xs border border-slate-300 rounded-lg p-2.5"
                  required
                />
              </div>

              <div className="flex justify-end gap-2 pt-4 border-t border-slate-200">
                <button
                  type="button"
                  onClick={() => setShowAddVisitorModal(false)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-lg cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 text-xs font-bold bg-[#a50c1f] text-white rounded-lg hover:bg-[#7c0012] cursor-pointer shadow-xs"
                >
                  Create Field Visitor
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: Facility Modal (Add/Edit) */}
      {showFacilityModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4 z-50 overflow-y-auto">
          <div className="bg-white rounded-xl max-w-lg w-full p-6 shadow-xl border border-slate-200 my-8">
            <div className="flex justify-between items-center pb-3 border-b border-slate-200">
              <h3 className="text-base font-bold text-slate-800 flex items-center gap-2">
                <Building2 className="w-5 h-5 text-[#a50c1f]" />
                <span>{editingFacility ? 'Edit Health Center' : 'Add Health Center'}</span>
              </h3>
              <button onClick={() => setShowFacilityModal(false)} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveFacility} className="space-y-4 mt-4">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Facility Name</label>
                  <input
                    type="text"
                    value={facName}
                    onChange={(e) => setFacName(e.target.value)}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Ward</label>
                  <select
                    value={facWard}
                    onChange={(e) => setFacWard(e.target.value)}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 bg-slate-50"
                  >
                    {(currentPalikaObj?.wards || []).map((w) => (
                      <option key={w.composite_ward_id} value={w.composite_ward_id}>
                        Ward {w.ward_no} - {w.locality_name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-3 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Total Beds</label>
                  <input
                    type="number"
                    value={facTotalBeds}
                    onChange={(e) => setFacTotalBeds(Number(e.target.value))}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Dengue Beds</label>
                  <input
                    type="number"
                    value={facDengueBeds}
                    onChange={(e) => setFacDengueBeds(Number(e.target.value))}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">NS1 Test Kits</label>
                  <input
                    type="number"
                    value={facNs1Kits}
                    onChange={(e) => setFacNs1Kits(Number(e.target.value))}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Emergency Phone</label>
                <input
                  type="text"
                  value={facEmergencyPhone}
                  onChange={(e) => setFacEmergencyPhone(e.target.value)}
                  className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                />
              </div>

              <div className="flex justify-end gap-2 pt-4 border-t border-slate-200">
                <button
                  type="button"
                  onClick={() => setShowFacilityModal(false)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-lg cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 text-xs font-bold bg-[#a50c1f] text-white rounded-lg hover:bg-[#7c0012] cursor-pointer shadow-xs"
                >
                  Save Health Center
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: RRT Van Modal (Add/Edit) */}
      {showRrtModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4 z-50 overflow-y-auto">
          <div className="bg-white rounded-xl max-w-lg w-full p-6 shadow-xl border border-slate-200 my-8">
            <div className="flex justify-between items-center pb-3 border-b border-slate-200">
              <h3 className="text-base font-bold text-slate-800 flex items-center gap-2">
                <Truck className="w-5 h-5 text-[#a50c1f]" />
                <span>{editingRrt ? 'Edit RRT Van' : 'Add Rapid Response Van'}</span>
              </h3>
              <button onClick={() => setShowRrtModal(false)} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveRrt} className="space-y-4 mt-4">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Plate Number</label>
                  <input
                    type="text"
                    value={rrtPlateNumber}
                    onChange={(e) => setRrtPlateNumber(e.target.value)}
                    placeholder="BA-2-JHA-XXXX"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Base Ward</label>
                  <select
                    value={rrtBaseWard}
                    onChange={(e) => setRrtBaseWard(e.target.value)}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 bg-slate-50"
                  >
                    {(currentPalikaObj?.wards || []).map((w) => (
                      <option key={w.composite_ward_id} value={w.composite_ward_id}>
                        Ward {w.ward_no} - {w.locality_name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Team Lead</label>
                  <input
                    type="text"
                    value={rrtTeamLead}
                    onChange={(e) => setRrtTeamLead(e.target.value)}
                    placeholder="Lead name"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Driver Phone (+977 / +91)</label>
                  <input
                    type="text"
                    value={rrtDriverPhone}
                    onChange={(e) => setRrtDriverPhone(e.target.value)}
                    placeholder="+9198XXXXXXXX"
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Bti Stock (kg)</label>
                  <input
                    type="number"
                    step="0.1"
                    value={rrtBtiKg}
                    onChange={(e) => setRrtBtiKg(Number(e.target.value))}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Temephos Stock (L)</label>
                  <input
                    type="number"
                    step="0.1"
                    value={rrtTemephosL}
                    onChange={(e) => setRrtTemephosL(Number(e.target.value))}
                    className="w-full text-xs border border-slate-300 rounded-lg p-2.5 font-mono"
                    required
                  />
                </div>
              </div>

              <div className="flex justify-end gap-2 pt-4 border-t border-slate-200">
                <button
                  type="button"
                  onClick={() => setShowRrtModal(false)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-lg cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 text-xs font-bold bg-[#a50c1f] text-white rounded-lg hover:bg-[#7c0012] cursor-pointer shadow-xs"
                >
                  Save RRT Van
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
