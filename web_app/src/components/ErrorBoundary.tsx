import { Component, ErrorInfo, ReactNode } from 'react';
import { AlertTriangle, RefreshCw } from 'lucide-react';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
    error: null,
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('NidanIQ Uncaught UI Error:', error, errorInfo);
  }

  private handleReset = () => {
    localStorage.removeItem('nidaniq_token');
    localStorage.removeItem('nidaniq_user');
    sessionStorage.clear();
    window.location.href = '/';
  };

  public render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-[#f7f9fb] flex items-center justify-center p-4">
          <div className="max-w-md w-full bg-white rounded-2xl border border-red-200 p-6 shadow-lg text-center">
            <div className="w-12 h-12 rounded-2xl bg-red-100 text-[#a50c1f] flex items-center justify-center mx-auto mb-4">
              <AlertTriangle className="w-6 h-6" />
            </div>
            <h2 className="text-lg font-bold text-slate-900 mb-1">
              Application Error
            </h2>
            <p className="text-xs text-slate-600 mb-4">
              An unexpected error occurred while rendering the dashboard.
            </p>
            <div className="bg-slate-50 border border-slate-200 rounded-lg p-3 text-left font-mono text-[11px] text-red-700 overflow-x-auto mb-5 max-h-32">
              {this.state.error?.message || 'Unknown render error'}
            </div>
            <button
              onClick={this.handleReset}
              className="w-full inline-flex items-center justify-center gap-2 py-2.5 px-4 rounded-xl bg-[#a50c1f] hover:bg-[#7c0012] text-white text-xs font-semibold shadow-sm transition-colors cursor-pointer"
            >
              <RefreshCw className="w-3.5 h-3.5" />
              <span>Reset Session & Return to Login</span>
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
