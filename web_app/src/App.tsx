import React from 'react';
import { AuthProvider, useAuth } from './context/AuthContext';
import { Header } from './components/Header';
import { LoginView } from './components/LoginView';
import { AdminDashboard } from './components/AdminDashboard';
import { MunicipalityAdminDashboard } from './components/MunicipalityAdminDashboard';
import { FieldVisitorDashboard } from './components/FieldVisitorDashboard';

const MainAppContent: React.FC = () => {
  const { currentUser, isAuthenticated, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="min-h-screen bg-[#F4F6F9] flex items-center justify-center">
        <div className="text-center">
          <div className="w-10 h-10 border-4 border-[#1B4D9B] border-t-transparent rounded-full animate-spin mx-auto mb-3"></div>
          <p className="text-xs font-semibold text-slate-600">
            NidanIQ Sovereign Platform Loading...
          </p>
        </div>
      </div>
    );
  }

  if (!isAuthenticated || !currentUser) {
    return <LoginView />;
  }

  return (
    <div className="min-h-screen bg-[#F4F6F9] flex flex-col justify-between">
      <Header />

      <main className="flex-1 pb-12">
        {currentUser.role === 'admin' && <AdminDashboard />}
        {currentUser.role === 'municipality_admin' && <MunicipalityAdminDashboard />}
        {currentUser.role !== 'admin' && currentUser.role !== 'municipality_admin' && (
          <FieldVisitorDashboard />
        )}
      </main>

      <footer className="bg-[#123770] text-white text-xs py-3.5 px-6 border-t border-slate-800">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row justify-between items-center gap-2 text-slate-300">
          <div>
            नेपाल सरकार • स्वास्थ्य तथा जनसंख्या मन्त्रालय • इपिडिमियोलोजी तथा रोग नियन्त्रण महाशाखा (EDCD Teku)
          </div>
          <div>
            Singhadurbar, Kathmandu, Nepal • IDMC Sovereign Cloud Infrastructure
          </div>
        </div>
      </footer>
    </div>
  );
};

export const App: React.FC = () => {
  return (
    <AuthProvider>
      <MainAppContent />
    </AuthProvider>
  );
};

export default App;
