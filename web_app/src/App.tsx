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
      <div className="min-h-screen bg-slate-50 flex items-center justify-center">
        <div className="text-center">
          <div className="w-10 h-10 border-4 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto mb-3"></div>
          <p className="text-xs font-semibold text-slate-600">
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
    <div className="min-h-screen bg-slate-50 flex flex-col justify-between">
      <Header />

      <main className="flex-1 pb-12">
        {currentUser.role === 'admin' && <AdminDashboard />}
        {currentUser.role === 'municipality_admin' && <MunicipalityAdminDashboard />}
        {currentUser.role !== 'admin' && currentUser.role !== 'municipality_admin' && (
          <FieldVisitorDashboard />
        )}
      </main>

      <footer className="bg-slate-900 text-white text-xs py-4 px-6 border-t border-slate-800">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row justify-between items-center gap-2 text-slate-400">
          <div className="flex items-center space-x-2">
            <span className="font-bold text-white">NidanIQ</span>
            <span>• Predictive Vector Surveillance & Outbreak Intelligence Platform</span>
          </div>
          <div>
            Open Public Health Digital Infrastructure
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
