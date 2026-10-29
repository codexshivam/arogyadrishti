import React, { createContext, useContext, useEffect, useState } from 'react';
import { requestOtp, verifyOtp } from '../services/api';
import { UserProfile } from '../types';

interface AuthContextType {
  currentUser: UserProfile | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  lang: 'en' | 'ne';
  toggleLang: () => void;
  sendOtp: (phone: string) => Promise<{ success: boolean; message: string; dev_otp?: string }>;
  confirmOtp: (phone: string, otp: string, pin?: string) => Promise<UserProfile>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [currentUser, setCurrentUser] = useState<UserProfile | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [lang, setLang] = useState<'en' | 'ne'>('ne');

  useEffect(() => {
    // Restore authentication from localStorage on boot
    try {
      const storedToken = localStorage.getItem('nidaniq_token');
      const storedUser = localStorage.getItem('nidaniq_user');
      const storedLang = localStorage.getItem('nidaniq_lang') as 'en' | 'ne' | null;
      if (storedLang) {
        setLang(storedLang);
      }
      if (storedToken && storedUser) {
        const parsed = JSON.parse(storedUser);
        setCurrentUser({ ...parsed, token: storedToken });
      }
    } catch (e) {
      console.error('Failed to restore auth from localStorage', e);
      localStorage.removeItem('nidaniq_token');
      localStorage.removeItem('nidaniq_user');
    } finally {
      setIsLoading(false);
    }
  }, []);

  const toggleLang = () => {
    const next = lang === 'en' ? 'ne' : 'en';
    setLang(next);
    localStorage.setItem('nidaniq_lang', next);
  };

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
        lang,
        toggleLang,
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
