import { useState, useEffect } from 'react';
import axios from 'axios';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from './ui/dialog';
import { toast } from 'sonner';
import { QrCode } from 'lucide-react';

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

const QRCodeModal = ({ client, onClose }) => {
  const [qrCode, setQrCode] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchQRCode = async () => {
      try {
        const response = await axios.get(`${API}/wg/clients/${client.id}/qrcode`);
        setQrCode(response.data.qrcode);
      } catch (error) {
        toast.error('Fehler beim Laden des QR-Codes');
      } finally {
        setLoading(false);
      }
    };

    fetchQRCode();
  }, [client.id]);

  return (
    <Dialog open={true} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-md" data-testid="qrcode-modal">
        <DialogHeader>
          <DialogTitle className="flex items-center text-xl">
            <QrCode className="w-5 h-5 mr-2 text-blue-600" />
            QR-Code für {client.name}
          </DialogTitle>
          <DialogDescription>
            Scannen Sie diesen QR-Code mit Ihrer WireGuard App
          </DialogDescription>
        </DialogHeader>

        <div className="flex flex-col items-center justify-center py-6">
          {loading ? (
            <div className="spinner" />
          ) : qrCode ? (
            <img
              src={qrCode}
              alt="WireGuard QR Code"
              data-testid="qrcode-image"
              className="w-full max-w-sm border-4 border-gray-200 rounded-lg shadow-lg"
            />
          ) : (
            <p className="text-gray-500">QR-Code konnte nicht geladen werden</p>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default QRCodeModal;
