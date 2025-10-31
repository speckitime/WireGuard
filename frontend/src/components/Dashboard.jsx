import { useState, useEffect } from 'react';
import axios from 'axios';
import { Button } from './ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
import { toast } from 'sonner';
import {
  Shield,
  Power,
  Users,
  Activity,
  Plus,
  Download,
  QrCode,
  Trash2,
  LogOut,
  RefreshCw,
  Server,
  Wifi,
  TrendingUp,
  TrendingDown,
  Globe,
} from 'lucide-react';
import AddClientModal from './AddClientModal';
import QRCodeModal from './QRCodeModal';

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

const formatBytes = (bytes) => {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i];
};

const Dashboard = ({ onLogout }) => {
  const [serverStatus, setServerStatus] = useState(null);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [showAddClient, setShowAddClient] = useState(false);
  const [selectedClient, setSelectedClient] = useState(null);
  const [showQRCode, setShowQRCode] = useState(false);

  const fetchData = async () => {
    try {
      const [statusRes, statsRes] = await Promise.all([
        axios.get(`${API}/wg/server/status`),
        axios.get(`${API}/wg/stats`),
      ]);

      setServerStatus(statusRes.data);
      setStats(statsRes.data);
    } catch (error) {
      console.error('Error fetching data:', error);
      if (error.response?.status === 401) {
        toast.error('Sitzung abgelaufen. Bitte melden Sie sich erneut an.');
        onLogout();
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 5000); // Refresh every 5 seconds
    return () => clearInterval(interval);
  }, []);

  const handleInitServer = async () => {
    setActionLoading(true);
    try {
      await axios.post(`${API}/wg/server/init`);
      toast.success('Server erfolgreich initialisiert!');
      fetchData();
    } catch (error) {
      toast.error(error.response?.data?.detail || 'Fehler beim Initialisieren des Servers');
    } finally {
      setActionLoading(false);
    }
  };

  const handleStartServer = async () => {
    setActionLoading(true);
    try {
      await axios.post(`${API}/wg/server/start`);
      toast.success('Server gestartet!');
      fetchData();
    } catch (error) {
      toast.error(error.response?.data?.detail || 'Fehler beim Starten des Servers');
    } finally {
      setActionLoading(false);
    }
  };

  const handleStopServer = async () => {
    setActionLoading(true);
    try {
      await axios.post(`${API}/wg/server/stop`);
      toast.success('Server gestoppt!');
      fetchData();
    } catch (error) {
      toast.error(error.response?.data?.detail || 'Fehler beim Stoppen des Servers');
    } finally {
      setActionLoading(false);
    }
  };

  const handleRestartServer = async () => {
    setActionLoading(true);
    try {
      await axios.post(`${API}/wg/server/restart`);
      toast.success('Server neu gestartet!');
      fetchData();
    } catch (error) {
      toast.error(error.response?.data?.detail || 'Fehler beim Neustarten des Servers');
    } finally {
      setActionLoading(false);
    }
  };

  const handleDownloadConfig = async (client) => {
    try {
      const response = await axios.get(`${API}/wg/clients/${client.id}/config`);
      const { config, filename } = response.data;

      const blob = new Blob([config], { type: 'text/plain' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);

      toast.success('Konfiguration heruntergeladen!');
    } catch (error) {
      toast.error('Fehler beim Herunterladen der Konfiguration');
    }
  };

  const handleShowQRCode = async (client) => {
    setSelectedClient(client);
    setShowQRCode(true);
  };

  const handleDeleteClient = async (client) => {
    if (!window.confirm(`Client "${client.name}" wirklich löschen?`)) {
      return;
    }

    try {
      await axios.delete(`${API}/wg/clients/${client.id}`);
      toast.success('Client gelöscht!');
      fetchData();
    } catch (error) {
      toast.error('Fehler beim Löschen des Clients');
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gradient-to-br from-slate-50 via-blue-50 to-cyan-50">
        <div className="spinner" />
      </div>
    );
  }

  const totalTraffic = stats?.clients?.reduce((acc, c) => acc + (c.total_bytes || 0), 0) || 0;

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 via-blue-50 to-cyan-50 p-6">
      {/* Header */}
      <div className="max-w-7xl mx-auto mb-8">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <div className="w-12 h-12 bg-gradient-to-br from-blue-500 to-cyan-500 rounded-xl flex items-center justify-center shadow-lg">
              <Shield className="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 className="text-3xl font-bold text-gray-800" data-testid="dashboard-title">WireGuard Admin</h1>
              <p className="text-sm text-gray-500">VPN Server Verwaltung</p>
            </div>
          </div>
          <div className="flex items-center space-x-3">
            <Button
              variant="outline"
              onClick={fetchData}
              data-testid="refresh-button"
              className="h-10 px-4 border-gray-200 hover:border-blue-400 hover:bg-blue-50 transition-all"
            >
              <RefreshCw className="w-4 h-4 mr-2" />
              Aktualisieren
            </Button>
            <Button
              variant="outline"
              onClick={onLogout}
              data-testid="logout-button"
              className="h-10 px-4 border-gray-200 hover:border-red-400 hover:bg-red-50 transition-all"
            >
              <LogOut className="w-4 h-4 mr-2" />
              Abmelden
            </Button>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto space-y-6">
        {/* Server Status Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <Card className="border-0 shadow-md card-hover glass" data-testid="server-status-card">
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500 font-medium">Server Status</p>
                  <p className={`text-2xl font-bold mt-1 ${serverStatus?.running ? 'text-green-600' : 'text-red-600'}`} data-testid="server-status-text">
                    {serverStatus?.running ? 'Online' : 'Offline'}
                  </p>
                </div>
                <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${serverStatus?.running ? 'bg-green-100' : 'bg-red-100'}`}>
                  <Server className={`w-6 h-6 ${serverStatus?.running ? 'text-green-600' : 'text-red-600'}`} />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="border-0 shadow-md card-hover glass" data-testid="active-clients-card">
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500 font-medium">Aktive Clients</p>
                  <p className="text-2xl font-bold mt-1 text-blue-600" data-testid="active-clients-count">
                    {stats?.active_clients || 0}
                  </p>
                </div>
                <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
                  <Wifi className="w-6 h-6 text-blue-600" />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="border-0 shadow-md card-hover glass" data-testid="total-clients-card">
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500 font-medium">Gesamt Clients</p>
                  <p className="text-2xl font-bold mt-1 text-cyan-600" data-testid="total-clients-count">
                    {stats?.total_clients || 0}
                  </p>
                </div>
                <div className="w-12 h-12 bg-cyan-100 rounded-xl flex items-center justify-center">
                  <Users className="w-6 h-6 text-cyan-600" />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="border-0 shadow-md card-hover glass" data-testid="total-traffic-card">
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500 font-medium">Gesamt Traffic</p>
                  <p className="text-2xl font-bold mt-1 text-purple-600" data-testid="total-traffic-text">
                    {formatBytes(totalTraffic)}
                  </p>
                </div>
                <div className="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center">
                  <Activity className="w-6 h-6 text-purple-600" />
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Server Controls */}
        <Card className="border-0 shadow-lg glass" data-testid="server-controls-card">
          <CardHeader>
            <CardTitle className="text-xl flex items-center">
              <Power className="w-5 h-5 mr-2 text-blue-600" />
              Server Steuerung
            </CardTitle>
            <CardDescription>WireGuard Server verwalten</CardDescription>
          </CardHeader>
          <CardContent>
            {!serverStatus?.initialized ? (
              <div className="text-center py-6">
                <Globe className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                <p className="text-gray-600 mb-4">Server noch nicht initialisiert</p>
                <Button
                  onClick={handleInitServer}
                  data-testid="init-server-button"
                  disabled={actionLoading}
                  className="bg-gradient-to-r from-blue-500 to-cyan-500 hover:from-blue-600 hover:to-cyan-600 text-white h-11 px-6 shadow-lg hover:shadow-xl transition-all"
                >
                  Server initialisieren
                </Button>
              </div>
            ) : (
              <div className="flex flex-wrap gap-3">
                {!serverStatus?.running ? (
                  <Button
                    onClick={handleStartServer}
                    data-testid="start-server-button"
                    disabled={actionLoading}
                    className="bg-gradient-to-r from-green-500 to-emerald-500 hover:from-green-600 hover:to-emerald-600 text-white h-10 px-5 shadow-md"
                  >
                    <Power className="w-4 h-4 mr-2" />
                    Server starten
                  </Button>
                ) : (
                  <Button
                    onClick={handleStopServer}
                    data-testid="stop-server-button"
                    disabled={actionLoading}
                    variant="outline"
                    className="border-red-300 text-red-600 hover:bg-red-50 h-10 px-5"
                  >
                    <Power className="w-4 h-4 mr-2" />
                    Server stoppen
                  </Button>
                )}
                <Button
                  onClick={handleRestartServer}
                  data-testid="restart-server-button"
                  disabled={actionLoading || !serverStatus?.running}
                  variant="outline"
                  className="border-blue-300 text-blue-600 hover:bg-blue-50 h-10 px-5"
                >
                  <RefreshCw className="w-4 h-4 mr-2" />
                  Neu starten
                </Button>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Clients */}
        {serverStatus?.initialized && (
          <Card className="border-0 shadow-lg glass" data-testid="clients-card">
            <CardHeader>
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle className="text-xl flex items-center">
                    <Users className="w-5 h-5 mr-2 text-blue-600" />
                    Client Verwaltung
                  </CardTitle>
                  <CardDescription>VPN Clients verwalten und überwachen</CardDescription>
                </div>
                <Button
                  onClick={() => setShowAddClient(true)}
                  data-testid="add-client-button"
                  className="bg-gradient-to-r from-blue-500 to-cyan-500 hover:from-blue-600 hover:to-cyan-600 text-white h-10 px-5 shadow-lg"
                >
                  <Plus className="w-4 h-4 mr-2" />
                  Client hinzufügen
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              {stats?.clients?.length === 0 ? (
                <div className="text-center py-12">
                  <Users className="w-16 h-16 text-gray-300 mx-auto mb-4" />
                  <p className="text-gray-500">Noch keine Clients vorhanden</p>
                </div>
              ) : (
                <div className="space-y-3">
                  {stats?.clients?.map((client) => (
                    <div
                      key={client.id}
                      data-testid={`client-${client.id}`}
                      className="flex items-center justify-between p-4 bg-white rounded-xl border border-gray-100 hover:border-blue-200 hover:shadow-md transition-all"
                    >
                      <div className="flex items-center space-x-4 flex-1">
                        <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${client.connected ? 'bg-green-100' : 'bg-gray-100'}`}>
                          <Wifi className={`w-5 h-5 ${client.connected ? 'text-green-600' : 'text-gray-400'}`} />
                        </div>
                        <div className="flex-1">
                          <div className="flex items-center space-x-2">
                            <h3 className="font-semibold text-gray-800" data-testid={`client-name-${client.id}`}>{client.name}</h3>
                            {client.connected && (
                              <span className="px-2 py-0.5 bg-green-100 text-green-700 text-xs font-medium rounded-full" data-testid={`client-status-${client.id}`}>
                                Verbunden
                              </span>
                            )}
                          </div>
                          <div className="flex items-center space-x-4 mt-1 text-sm text-gray-500">
                            <span data-testid={`client-ip-${client.id}`}>IP: {client.ip_address}</span>
                            {client.os_info && (
                              <span data-testid={`client-os-${client.id}`}>OS: {client.os_info}</span>
                            )}
                            {client.connected && client.latest_handshake && (
                              <span data-testid={`client-handshake-${client.id}`}>Letzter Handshake: {client.latest_handshake}</span>
                            )}
                          </div>
                          {client.connected && (
                            <div className="flex items-center space-x-4 mt-2 text-xs">
                              <span className="flex items-center text-green-600" data-testid={`client-download-${client.id}`}>
                                <TrendingDown className="w-3 h-3 mr-1" />
                                {formatBytes(client.rx_bytes || 0)}
                              </span>
                              <span className="flex items-center text-blue-600" data-testid={`client-upload-${client.id}`}>
                                <TrendingUp className="w-3 h-3 mr-1" />
                                {formatBytes(client.tx_bytes || 0)}
                              </span>
                            </div>
                          )}
                        </div>
                      </div>
                      <div className="flex items-center space-x-2">
                        <Button
                          variant="outline"
                          size="sm"
                          data-testid={`download-config-${client.id}`}
                          onClick={() => handleDownloadConfig(client)}
                          className="h-9 px-3 border-gray-200 hover:border-blue-400 hover:bg-blue-50"
                        >
                          <Download className="w-4 h-4" />
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          data-testid={`show-qrcode-${client.id}`}
                          onClick={() => handleShowQRCode(client)}
                          className="h-9 px-3 border-gray-200 hover:border-blue-400 hover:bg-blue-50"
                        >
                          <QrCode className="w-4 h-4" />
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          data-testid={`delete-client-${client.id}`}
                          onClick={() => handleDeleteClient(client)}
                          className="h-9 px-3 border-gray-200 hover:border-red-400 hover:bg-red-50 hover:text-red-600"
                        >
                          <Trash2 className="w-4 h-4" />
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        )}
      </div>

      {/* Modals */}
      {showAddClient && (
        <AddClientModal
          onClose={() => setShowAddClient(false)}
          onSuccess={() => {
            setShowAddClient(false);
            fetchData();
          }}
        />
      )}

      {showQRCode && selectedClient && (
        <QRCodeModal
          client={selectedClient}
          onClose={() => {
            setShowQRCode(false);
            setSelectedClient(null);
          }}
        />
      )}
    </div>
  );
};

export default Dashboard;
