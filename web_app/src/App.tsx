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
      <div className="min-h-screen bg-[#f7f9fb] flex items-center justify-center">
        <div className="text-center">
          <div className="w-10 h-10 border-4 border-[#a50c1f] border-t-transparent rounded-full animate-spin mx-auto mb-3"></div>
          <p className="text-xs font-semibold text-[#64748b]">
            NidanIQ Platform Loading...
          </p>
        </div>
      </div>
    );
  }

  if (!isAuthenticated || !currentUser) {
    return <LoginView />;
  }

  return (
    <div className="min-h-screen bg-[#f7f9fb] flex flex-col justify-between">
      <Header />

      <main className="flex-1 pb-12">
        {currentUser.role === 'admin' && <AdminDashboard />}
        {currentUser.role === 'municipality_admin' && <MunicipalityAdminDashboard />}
        {currentUser.role !== 'admin' && currentUser.role !== 'municipality_admin' && (
          <FieldVisitorDashboard />
        )}
      </main>

      <footer className="bg-[#191c1e] text-white text-xs py-4 px-6 border-t border-[#2d3133]">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row justify-between items-center gap-2 text-[#a0a4a8]">
          <div className="flex items-center space-x-2">
            <span className="font-bold text-white">Nidan<span className="text-[#ffb1ad]">IQ</span></span>
            <span>• Predictive Vector Surveillance & Outbreak Intelligence Platform</span>
          </div>
          <div>
            Digital Public Infrastructure
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
