import {
  AdministrativeHierarchy,
  EscalationTicketItem,
  HealthFacilityItem,
  RrtVehicleItem,
  StaffUserItem,
  UserProfile,
} from '../types';

const API_BASE = '/api/v1';

function getAuthHeader(): Record<string, string> {
  const token = localStorage.getItem('nidaniq_token');
  return token ? { Authorization: `Bearer ${token}` } : {};
}

export async function requestOtp(phoneNumber: string): Promise<{ success: boolean; message: string; dev_otp?: string }> {
  const res = await fetch(`${API_BASE}/auth/request-otp`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone_number: phoneNumber }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to send OTP' }));
    throw new Error(err.detail || 'Failed to send OTP');
  }
  return res.json();
}

export async function verifyOtp(phoneNumber: string, otpCode: string, pin?: string): Promise<UserProfile> {
  const res = await fetch(`${API_BASE}/auth/verify-otp`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      phone_number: phoneNumber,
      otp_code: otpCode,
      pin: pin || '999999',
    }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Invalid OTP or authorization failed' }));
    throw new Error(err.detail || 'Verification failed');
  }
  const data = await res.json();
  const sp = data.staff_profile || {};
  const profile: UserProfile = {
    id: sp.id || data.staff_id || '',
    phone: phoneNumber,
    full_name: sp.full_name || data.full_name || 'Staff User',
    full_name_ne: sp.full_name_ne || data.full_name_ne || '',
    designation: sp.designation || data.designation || '',
    role: (sp.role || data.role || 'field_visitor') as UserProfile['role'],
    province_code: sp.province_code ?? data.province_code ?? 3,
    district_code: sp.district_code ?? data.district_code ?? 27,
    palika_code: sp.palika_code ?? data.palika_code ?? '30608',
    assigned_wards: sp.assigned_wards || data.assigned_wards || [],
    bs_date: data.bs_date || '',
    bs_ad_official_label: data.bs_ad_official_label || '',
    token: data.access_token || '',
  };
  return profile;
}

export async function fetchSpatialHierarchy(): Promise<AdministrativeHierarchy> {
  const res = await fetch(`${API_BASE}/spatial/hierarchy`);
  if (!res.ok) {
    throw new Error('Failed to load administrative hierarchy');
  }
  return res.json();
}

// Staff Users CRUD
export async function fetchStaffUsers(palikaCode?: string): Promise<StaffUserItem[]> {
  const url = palikaCode
    ? `${API_BASE}/users?palika_code=${encodeURIComponent(palikaCode)}`
    : `${API_BASE}/users`;
  const res = await fetch(url, {
    headers: { ...getAuthHeader() },
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to fetch users' }));
    throw new Error(err.detail || 'Failed to fetch users');
  }
  const data = await res.json();
  return Array.isArray(data) ? data : (data.users || []);
}

export async function createStaffUser(data: {
  phone: string;
  full_name: string;
  full_name_ne?: string;
  designation: string;
  role: string;
  province_code: number;
  district_code: number;
  palika_code: string;
  assigned_wards: string[];
  pin: string;
}): Promise<StaffUserItem> {
  const res = await fetch(`${API_BASE}/users`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeader(),
    },
    body: JSON.stringify(data),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to create user' }));
    throw new Error(err.detail || 'Failed to create user');
  }
  return res.json();
}

export async function deleteStaffUser(userId: string): Promise<void> {
  const res = await fetch(`${API_BASE}/users/${encodeURIComponent(userId)}`, {
    method: 'DELETE',
    headers: { ...getAuthHeader() },
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to delete user' }));
    throw new Error(err.detail || 'Failed to delete user');
  }
}

// Facilities CRUD
export async function fetchFacilities(palikaCode?: string): Promise<HealthFacilityItem[]> {
  const url = palikaCode
    ? `${API_BASE}/facilities?palika_code=${encodeURIComponent(palikaCode)}`
    : `${API_BASE}/facilities`;
  const res = await fetch(url, {
    headers: { ...getAuthHeader() },
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to fetch facilities' }));
    throw new Error(err.detail || 'Failed to fetch facilities');
  }
  const data = await res.json();
  return Array.isArray(data) ? data : (data.facilities || []);
}

export async function createFacility(data: Partial<HealthFacilityItem>): Promise<HealthFacilityItem> {
  const res = await fetch(`${API_BASE}/facilities`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeader(),
    },
    body: JSON.stringify(data),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to create facility' }));
    throw new Error(err.detail || 'Failed to create facility');
  }
  return res.json();
}

export async function updateFacility(id: string, data: Partial<HealthFacilityItem>): Promise<HealthFacilityItem> {
  const res = await fetch(`${API_BASE}/facilities/${encodeURIComponent(id)}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeader(),
    },
    body: JSON.stringify(data),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to update facility' }));
    throw new Error(err.detail || 'Failed to update facility');
  }
  return res.json();
}

export async function deleteFacility(id: string): Promise<void> {
  const res = await fetch(`${API_BASE}/facilities/${encodeURIComponent(id)}`, {
    method: 'DELETE',
    headers: { ...getAuthHeader() },
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to delete facility' }));
    throw new Error(err.detail || 'Failed to delete facility');
  }
}

// RRT Fleet CRUD
export async function fetchRrtUnits(palikaCode?: string): Promise<RrtVehicleItem[]> {
  const url = palikaCode
    ? `${API_BASE}/rrt/units?palika_code=${encodeURIComponent(palikaCode)}`
    : `${API_BASE}/rrt/units`;
  const res = await fetch(url, {
    headers: { ...getAuthHeader() },
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to fetch RRT units' }));
    throw new Error(err.detail || 'Failed to fetch RRT units');
  }
  const data = await res.json();
  return Array.isArray(data) ? data : (data.units || []);
}

export async function createRrtUnit(data: Partial<RrtVehicleItem>): Promise<RrtVehicleItem> {
  const res = await fetch(`${API_BASE}/rrt/units`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeader(),
    },
    body: JSON.stringify(data),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to create RRT unit' }));
    throw new Error(err.detail || 'Failed to create RRT unit');
  }
  return res.json();
}

export async function updateRrtUnit(id: string, data: Partial<RrtVehicleItem>): Promise<RrtVehicleItem> {
  const res = await fetch(`${API_BASE}/rrt/units/${encodeURIComponent(id)}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeader(),
    },
    body: JSON.stringify(data),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to update RRT unit' }));
    throw new Error(err.detail || 'Failed to update RRT unit');
  }
  return res.json();
}

export async function deleteRrtUnit(id: string): Promise<void> {
  const res = await fetch(`${API_BASE}/rrt/units/${encodeURIComponent(id)}`, {
    method: 'DELETE',
    headers: { ...getAuthHeader() },
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to delete RRT unit' }));
    throw new Error(err.detail || 'Failed to delete RRT unit');
  }
}

// Support Tickets / Requests
export async function fetchTickets(params?: {
  palika_code?: string;
  composite_ward_id?: string;
  status?: string;
}): Promise<EscalationTicketItem[]> {
  const query = new URLSearchParams();
  if (params?.palika_code) query.set('palika_code', params.palika_code);
  if (params?.composite_ward_id) query.set('composite_ward_id', params.composite_ward_id);
  if (params?.status) query.set('status', params.status);

  const res = await fetch(`${API_BASE}/escalations?${query.toString()}`, {
    headers: { ...getAuthHeader() },
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to fetch tickets' }));
    throw new Error(err.detail || 'Failed to fetch tickets');
  }
  const data = await res.json();
  return Array.isArray(data) ? data : (data.tickets || []);
}

export async function updateTicketStatus(ticketCode: string, status: 'OPEN' | 'ASSIGNED' | 'RESOLVED'): Promise<void> {
  const res = await fetch(`${API_BASE}/escalations/${encodeURIComponent(ticketCode)}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeader(),
    },
    body: JSON.stringify({ status }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to update ticket status' }));
    throw new Error(err.detail || 'Failed to update ticket status');
  }
}
