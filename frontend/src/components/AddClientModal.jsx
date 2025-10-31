import { useState } from 'react';
import axios from 'axios';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from './ui/dialog';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { toast } from 'sonner';
import { UserPlus } from 'lucide-react';

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

const AddClientModal = ({ onClose, onSuccess }) => {
  const [name, setName] = useState('');
  const [osInfo, setOsInfo] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);

    try {
      await axios.post(`${API}/wg/clients`, {
        name,
        os_info: osInfo || null,
      });

      toast.success('Client erfolgreich erstellt!');
      onSuccess();
    } catch (error) {
      toast.error(error.response?.data?.detail || 'Fehler beim Erstellen des Clients');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog open={true} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-md" data-testid="add-client-modal">
        <DialogHeader>
          <DialogTitle className="flex items-center text-xl">
            <UserPlus className="w-5 h-5 mr-2 text-blue-600" />
            Neuen Client hinzufügen
          </DialogTitle>
          <DialogDescription>
            Erstellen Sie ein neues VPN Client-Profil
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4 mt-4" data-testid="add-client-form">
          <div className="space-y-2">
            <Label htmlFor="name">Client Name *</Label>
            <Input
              id="name"
              data-testid="client-name-input"
              type="text"
              placeholder="z.B. Laptop-John oder iPhone-Sarah"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              className="h-10"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="osInfo">Betriebssystem (Optional)</Label>
            <Input
              id="osInfo"
              data-testid="client-os-input"
              type="text"
              placeholder="z.B. Windows 11, macOS, iOS, Android"
              value={osInfo}
              onChange={(e) => setOsInfo(e.target.value)}
              className="h-10"
            />
          </div>

          <div className="flex justify-end space-x-2 pt-4">
            <Button
              type="button"
              variant="outline"
              onClick={onClose}
              data-testid="cancel-button"
              disabled={loading}
              className="h-10 px-5"
            >
              Abbrechen
            </Button>
            <Button
              type="submit"
              data-testid="create-client-button"
              disabled={loading}
              className="bg-gradient-to-r from-blue-500 to-cyan-500 hover:from-blue-600 hover:to-cyan-600 text-white h-10 px-5"
            >
              {loading ? 'Erstellt...' : 'Client erstellen'}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
};

export default AddClientModal;
