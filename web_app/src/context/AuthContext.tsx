import React, { createContext, useContext, useEffect, useState } from 'react';
import { requestOtp, verifyOtp } from '../services/api';
import { UserProfile } from '../types';

interface AuthContextType {
  currentUser: UserProfile | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  sendOtp: (phone: string) => Promise<{ success: boolean; message: string; dev_otp?: string }>;
  confirmOtp: (phone: string, otp: string, pin?: string) => Promise<UserProfile>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [currentUser, setCurrentUser] = useState<UserProfile | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  useEffect(() => {
    // Restore authentication from localStorage on boot
    try {
      const storedToken = localStorage.getItem('nidaniq_token');
      const storedUser = localStorage.getItem('nidaniq_user');
      if (storedToken && storedUser) {
        let parsed = JSON.parse(storedUser);
        // Handle migration if stored under nested staff_profile from previous version
        if (parsed.staff_profile) {
          const sp = parsed.staff_profile;
          parsed = {
            id: sp.id || parsed.id || '',
            phone: sp.phone_number || parsed.phone || '',
            full_name: sp.full_name || 'Staff User',
            full_name_ne: sp.full_name_ne || '',
            designation: sp.designation || '',
            role: sp.role || 'field_visitor',
            province_code: sp.province_code ?? 3,
            district_code: sp.district_code ?? 27,
            palika_code: sp.palika_code ?? '30608',
            assigned_wards: sp.assigned_wards || [],
            bs_date: parsed.bs_date || '',
            bs_ad_official_label: parsed.bs_ad_official_label || '',
            token: storedToken,
          };
          localStorage.setItem('nidaniq_user', JSON.stringify(parsed));
        }
        // Ensure defaults for critical fields so rendering never throws
        parsed.full_name = parsed.full_name || 'Staff User';
        parsed.assigned_wards = Array.isArray(parsed.assigned_wards) ? parsed.assigned_wards : [];
        parsed.role = parsed.role || 'field_visitor';
        parsed.token = storedToken;
        setCurrentUser(parsed);
      }
    } catch (e) {
      console.error('Failed to restore auth from localStorage', e);
      localStorage.removeItem('nidaniq_token');
      localStorage.removeItem('nidaniq_user');
    } finally {
      setIsLoading(false);
    }
  }, []);

  const sendOtp = async (phone: string) => {
    return requestOtp(phone);
  };

  const confirmOtp = async (phone: string, otp: string, pin?: string) => {
    const profile = await verifyOtp(phone, otp, pin);
    setCurrentUser(profile);
    localStorage.setItem('nidaniq_token', profile.token);
    localStorage.setItem('nidaniq_user', JSON.stringify(profile));
    return profile;
  };

  const logout = () => {
    setCurrentUser(null);
    localStorage.removeItem('nidaniq_token');
    localStorage.removeItem('nidaniq_user');
  };

  return (
    <AuthContext.Provider
      value={{
        currentUser,
        isAuthenticated: !!currentUser,
        isLoading,
        sendOtp,
        confirmOtp,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
