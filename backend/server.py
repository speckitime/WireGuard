from fastapi import FastAPI, APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional
import uuid
from datetime import datetime, timezone, timedelta
import subprocess
import re
import jwt
from passlib.context import CryptContext
import qrcode
import io
import base64


ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB connection
mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

# Create the main app without a prefix
app = FastAPI()

# Create a router with the /api prefix
api_router = APIRouter(prefix="/api")

# Security
security = HTTPBearer()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
SECRET_KEY = os.environ.get("JWT_SECRET", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 43200  # 30 days

# WireGuard Configuration
WG_CONFIG_DIR = Path("/etc/wireguard")
WG_INTERFACE = "wg0"
SERVER_PUBLIC_IP = "43.251.160.244"
SERVER_DOMAIN = "vpn-dus.leonboldt.de"
SERVER_PORT = 51820
SERVER_NETWORK = "10.8.0.0/24"
SERVER_IP = "10.8.0.1"

# SSH Configuration (for remote management)
SSH_ENABLED = os.environ.get("SSH_ENABLED", "false").lower() == "true"
SSH_HOST = os.environ.get("SSH_HOST", "")
SSH_PORT = int(os.environ.get("SSH_PORT", "22"))
SSH_USER = os.environ.get("SSH_USER", "root")
SSH_KEY_PATH = os.environ.get("SSH_KEY_PATH", "")


# Helper Functions
def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(status_code=401, detail="Invalid authentication credentials")
        return username
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.JWTError:
        raise HTTPException(status_code=401, detail="Could not validate credentials")

def run_command(cmd: List[str]) -> tuple[str, str, int]:
    """Run a shell command locally or via SSH"""
    # Use full paths for system commands
    cmd_map = {
        "wg": "/usr/bin/wg",
        "wg-quick": "/usr/bin/wg-quick",
        "sudo": "/usr/bin/sudo"
    }
    
    if cmd[0] in cmd_map:
        cmd[0] = cmd_map[cmd[0]]
    
    try:
        if SSH_ENABLED and SSH_HOST:
            # Run command via SSH
            ssh_cmd = [
                "ssh",
                "-i", SSH_KEY_PATH,
                "-p", str(SSH_PORT),
                "-o", "StrictHostKeyChecking=no",
                f"{SSH_USER}@{SSH_HOST}",
                " ".join(cmd)
            ]
            result = subprocess.run(ssh_cmd, capture_output=True, text=True, timeout=10)
        else:
            # Run command locally
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        
        return result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        return "", "Command timed out", 1
    except Exception as e:
        return "", str(e), 1

def generate_keypair() -> tuple[str, str]:
    """Generate WireGuard private and public key pair"""
    private_key, _, _ = run_command(["wg", "genkey"])
    private_key = private_key.strip()
    
    echo_process = subprocess.Popen(["echo", private_key], stdout=subprocess.PIPE)
    public_key, _ = subprocess.communicate(echo_process.stdout, ["wg", "pubkey"])
    public_key = public_key.strip()
    
    return private_key, public_key

def subprocess_communicate(stdin_data: bytes, cmd: List[str]) -> str:
    """Helper to pipe data through command"""
    # Use full paths for system commands
    if cmd[0] == "wg":
        cmd[0] = "/usr/bin/wg"
    
    if SSH_ENABLED and SSH_HOST:
        # For SSH, we need to handle piping differently
        ssh_cmd = [
            "ssh",
            "-i", SSH_KEY_PATH,
            "-p", str(SSH_PORT),
            "-o", "StrictHostKeyChecking=no",
            f"{SSH_USER}@{SSH_HOST}",
            " ".join([str(c) for c in cmd])
        ]
        process = subprocess.Popen(ssh_cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, _ = process.communicate(input=stdin_data)
        return stdout.decode().strip()
    else:
        process = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, _ = process.communicate(input=stdin_data)
        return stdout.decode().strip()

def generate_wg_keys() -> tuple[str, str]:
    """Generate WireGuard key pair"""
    private_key = subprocess_communicate(b"", ["wg", "genkey"]).strip()
    public_key = subprocess_communicate(private_key.encode(), ["wg", "pubkey"]).strip()
    return private_key, public_key

def get_wg_status() -> dict:
    """Get WireGuard interface status"""
    stdout, stderr, code = run_command(["sudo", "wg", "show", WG_INTERFACE])
    
    if code != 0:
        return {"running": False, "peers": []}
    
    peers = []
    current_peer = None
    
    for line in stdout.split('\n'):
        if line.startswith('peer:'):
            if current_peer:
                peers.append(current_peer)
            current_peer = {"public_key": line.split(': ')[1].strip()}
        elif current_peer:
            if 'endpoint:' in line:
                current_peer['endpoint'] = line.split(': ')[1].strip()
            elif 'latest handshake:' in line:
                current_peer['latest_handshake'] = line.split(': ')[1].strip()
            elif 'transfer:' in line:
                transfer = line.split(': ')[1].strip()
                parts = transfer.split(', ')
                if len(parts) == 2:
                    current_peer['rx_bytes'] = parts[0].split()[0]
                    current_peer['tx_bytes'] = parts[1].split()[0]
            elif 'allowed ips:' in line:
                current_peer['allowed_ips'] = line.split(': ')[1].strip()
    
    if current_peer:
        peers.append(current_peer)
    
    return {"running": True, "peers": peers}

def parse_traffic(traffic_str: str) -> int:
    """Parse traffic string like '1.5 GiB' to bytes"""
    if not traffic_str or traffic_str == '0 B':
        return 0
    
    units = {'B': 1, 'KiB': 1024, 'MiB': 1024**2, 'GiB': 1024**3, 'TiB': 1024**4}
    
    parts = traffic_str.split()
    if len(parts) != 2:
        return 0
    
    try:
        value = float(parts[0])
        unit = parts[1]
        return int(value * units.get(unit, 1))
    except:
        return 0


# Models
class User(BaseModel):
    model_config = ConfigDict(extra="ignore")
    username: str
    hashed_password: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class UserRegister(BaseModel):
    username: str
    password: str

class UserLogin(BaseModel):
    username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

class WGClient(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: str
    public_key: str
    private_key: str
    ip_address: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    enabled: bool = True
    os_info: Optional[str] = None

class WGClientCreate(BaseModel):
    name: str
    os_info: Optional[str] = None

class WGServerConfig(BaseModel):
    private_key: str
    public_key: str
    address: str
    port: int
    initialized: bool
    created_at: datetime

class WGStats(BaseModel):
    active_clients: int
    total_clients: int
    server_running: bool
    clients: List[dict]


# Add your routes to the router instead of directly to app
@api_router.get("/")
@api_router.get("")
async def root():
    return {"message": "Hello World"}


# Auth Routes
@api_router.post("/auth/register", response_model=Token)
async def register(user: UserRegister):
    # Check if user exists
    existing_user = await db.users.find_one({"username": user.username})
    if existing_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    
    # Create user
    hashed_password = hash_password(user.password)
    user_doc = {
        "username": user.username,
        "hashed_password": hashed_password,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.users.insert_one(user_doc)
    
    # Create token
    access_token = create_access_token(
        data={"sub": user.username},
        expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    return {"access_token": access_token, "token_type": "bearer"}

@api_router.post("/auth/login", response_model=Token)
async def login(user: UserLogin):
    # Find user
    db_user = await db.users.find_one({"username": user.username})
    if not db_user or not verify_password(user.password, db_user["hashed_password"]):
        raise HTTPException(status_code=401, detail="Incorrect username or password")
    
    # Create token
    access_token = create_access_token(
        data={"sub": user.username},
        expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    return {"access_token": access_token, "token_type": "bearer"}


# WireGuard Server Routes
@api_router.post("/wg/server/init")
async def init_server(current_user: str = Depends(get_current_user)):
    """Initialize WireGuard server configuration"""
    # Check if already initialized
    existing_config = await db.server_config.find_one({})
    if existing_config:
        return {"message": "Server already initialized", "config": existing_config}
    
    # Generate server keys
    private_key, public_key = generate_wg_keys()
    
    # Create server config
    config_content = f"""[Interface]
PrivateKey = {private_key}
Address = {SERVER_IP}/24
ListenPort = {SERVER_PORT}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

"""
    
    # Save to MongoDB
    server_doc = {
        "private_key": private_key,
        "public_key": public_key,
        "address": SERVER_IP,
        "port": SERVER_PORT,
        "initialized": True,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.server_config.insert_one(server_doc)
    
    # Write config file
    try:
        if SSH_ENABLED and SSH_HOST:
            # Write config via SSH
            run_command(["sudo", "mkdir", "-p", str(WG_CONFIG_DIR)])
            # Create temp file locally then transfer
            with open("/tmp/wg0.conf", "w") as f:
                f.write(config_content)
            run_command(["scp", "-i", SSH_KEY_PATH, "/tmp/wg0.conf", f"{SSH_USER}@{SSH_HOST}:/tmp/wg0.conf"])
            run_command(["sudo", "cp", "/tmp/wg0.conf", f"{WG_CONFIG_DIR}/{WG_INTERFACE}.conf"])
            run_command(["sudo", "chmod", "600", f"{WG_CONFIG_DIR}/{WG_INTERFACE}.conf"])
        else:
            # Write config locally
            WG_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
            config_file = WG_CONFIG_DIR / f"{WG_INTERFACE}.conf"
            
            with open("/tmp/wg0.conf", "w") as f:
                f.write(config_content)
            
            run_command(["sudo", "cp", "/tmp/wg0.conf", str(config_file)])
            run_command(["sudo", "chmod", "600", str(config_file)])
        
        return {"message": "Server initialized successfully", "public_key": public_key}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to write config: {str(e)}")

@api_router.get("/wg/server/status")
async def get_server_status(current_user: str = Depends(get_current_user)):
    """Get WireGuard server status"""
    config = await db.server_config.find_one({}, {"_id": 0})
    
    if not config:
        return {"initialized": False, "running": False}
    
    wg_status = get_wg_status()
    
    return {
        "initialized": True,
        "running": wg_status["running"],
        "public_key": config["public_key"],
        "address": config["address"],
        "port": config["port"]
    }

@api_router.post("/wg/server/start")
async def start_server(current_user: str = Depends(get_current_user)):
    """Start WireGuard server"""
    stdout, stderr, code = run_command(["sudo", "wg-quick", "up", WG_INTERFACE])
    
    if code != 0 and "already exists" not in stderr:
        raise HTTPException(status_code=500, detail=f"Failed to start server: {stderr}")
    
    return {"message": "Server started successfully"}

@api_router.post("/wg/server/stop")
async def stop_server(current_user: str = Depends(get_current_user)):
    """Stop WireGuard server"""
    stdout, stderr, code = run_command(["sudo", "wg-quick", "down", WG_INTERFACE])
    
    if code != 0:
        raise HTTPException(status_code=500, detail=f"Failed to stop server: {stderr}")
    
    return {"message": "Server stopped successfully"}

@api_router.post("/wg/server/restart")
async def restart_server(current_user: str = Depends(get_current_user)):
    """Restart WireGuard server"""
    # Stop
    run_command(["sudo", "wg-quick", "down", WG_INTERFACE])
    
    # Start
    stdout, stderr, code = run_command(["sudo", "wg-quick", "up", WG_INTERFACE])
    
    if code != 0:
        raise HTTPException(status_code=500, detail=f"Failed to restart server: {stderr}")
    
    return {"message": "Server restarted successfully"}


# WireGuard Client Routes
@api_router.post("/wg/clients", response_model=WGClient)
async def create_client(client_data: WGClientCreate, current_user: str = Depends(get_current_user)):
    """Create a new WireGuard client"""
    # Get server config
    server_config = await db.server_config.find_one({})
    if not server_config:
        raise HTTPException(status_code=400, detail="Server not initialized")
    
    # Get next available IP
    existing_clients = await db.clients.find({}, {"_id": 0}).to_list(1000)
    used_ips = [c["ip_address"] for c in existing_clients]
    
    # Find next available IP (starting from 10.8.0.2)
    next_ip = None
    for i in range(2, 255):
        test_ip = f"10.8.0.{i}"
        if test_ip not in used_ips:
            next_ip = test_ip
            break
    
    if not next_ip:
        raise HTTPException(status_code=400, detail="No available IP addresses")
    
    # Generate client keys
    private_key, public_key = generate_wg_keys()
    
    # Create client document
    client_doc = {
        "id": str(uuid.uuid4()),
        "name": client_data.name,
        "public_key": public_key,
        "private_key": private_key,
        "ip_address": next_ip,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "enabled": True,
        "os_info": client_data.os_info
    }
    
    await db.clients.insert_one(client_doc)
    
    # Add peer to WireGuard config
    peer_config = f"\n[Peer]\nPublicKey = {public_key}\nAllowedIPs = {next_ip}/32\n"
    
    # Append to config file
    try:
        with open("/tmp/peer.conf", "w") as f:
            f.write(peer_config)
        
        if SSH_ENABLED and SSH_HOST:
            # Transfer and append via SSH
            run_command(["scp", "-i", SSH_KEY_PATH, "/tmp/peer.conf", f"{SSH_USER}@{SSH_HOST}:/tmp/peer.conf"])
            run_command(["sudo", "bash", "-c", f"cat /tmp/peer.conf >> {WG_CONFIG_DIR}/{WG_INTERFACE}.conf"])
        else:
            # Append locally
            run_command(["sudo", "bash", "-c", f"cat /tmp/peer.conf >> /etc/wireguard/{WG_INTERFACE}.conf"])
        
        # Reload if running
        wg_status = get_wg_status()
        if wg_status["running"]:
            run_command(["sudo", "wg", "syncconf", WG_INTERFACE, f"/etc/wireguard/{WG_INTERFACE}.conf"])
    except Exception as e:
        logging.error(f"Failed to add peer to config: {e}")
    
    client_doc.pop("_id", None)
    return client_doc

@api_router.get("/wg/clients", response_model=List[WGClient])
async def get_clients(current_user: str = Depends(get_current_user)):
    """Get all WireGuard clients"""
    clients = await db.clients.find({}, {"_id": 0}).to_list(1000)
    return clients

@api_router.delete("/wg/clients/{client_id}")
async def delete_client(client_id: str, current_user: str = Depends(get_current_user)):
    """Delete a WireGuard client"""
    client = await db.clients.find_one({"id": client_id})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    # Remove from database
    await db.clients.delete_one({"id": client_id})
    
    # Remove from WireGuard
    public_key = client["public_key"]
    run_command(["sudo", "wg", "set", WG_INTERFACE, "peer", public_key, "remove"])
    
    return {"message": "Client deleted successfully"}

@api_router.get("/wg/clients/{client_id}/config")
async def get_client_config(client_id: str, current_user: str = Depends(get_current_user)):
    """Get client configuration file content"""
    client = await db.clients.find_one({"id": client_id}, {"_id": 0})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    server_config = await db.server_config.find_one({}, {"_id": 0})
    if not server_config:
        raise HTTPException(status_code=400, detail="Server not initialized")
    
    # Generate client config
    config = f"""[Interface]
PrivateKey = {client['private_key']}
Address = {client['ip_address']}/24
DNS = 1.1.1.1

[Peer]
PublicKey = {server_config['public_key']}
Endpoint = {SERVER_DOMAIN}:{SERVER_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
"""
    
    return {"config": config, "filename": f"{client['name']}.conf"}

@api_router.get("/wg/clients/{client_id}/qrcode")
async def get_client_qrcode(client_id: str, current_user: str = Depends(get_current_user)):
    """Get client configuration as QR code"""
    client = await db.clients.find_one({"id": client_id}, {"_id": 0})
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    server_config = await db.server_config.find_one({}, {"_id": 0})
    if not server_config:
        raise HTTPException(status_code=400, detail="Server not initialized")
    
    # Generate client config
    config = f"""[Interface]
PrivateKey = {client['private_key']}
Address = {client['ip_address']}/24
DNS = 1.1.1.1

[Peer]
PublicKey = {server_config['public_key']}
Endpoint = {SERVER_DOMAIN}:{SERVER_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25"""
    
    # Generate QR code
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(config)
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    
    # Convert to base64
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    buf.seek(0)
    img_base64 = base64.b64encode(buf.read()).decode()
    
    return {"qrcode": f"data:image/png;base64,{img_base64}"}


# Statistics Route
@api_router.get("/wg/stats", response_model=WGStats)
async def get_stats(current_user: str = Depends(get_current_user)):
    """Get WireGuard statistics"""
    wg_status = get_wg_status()
    all_clients = await db.clients.find({}, {"_id": 0}).to_list(1000)
    
    # Match clients with active peers
    client_stats = []
    for client in all_clients:
        peer_data = None
        for peer in wg_status.get("peers", []):
            if peer["public_key"] == client["public_key"]:
                peer_data = peer
                break
        
        rx_bytes = 0
        tx_bytes = 0
        if peer_data:
            rx_bytes = parse_traffic(peer_data.get("rx_bytes", "0 B"))
            tx_bytes = parse_traffic(peer_data.get("tx_bytes", "0 B"))
        
        client_stats.append({
            "id": client["id"],
            "name": client["name"],
            "ip_address": client["ip_address"],
            "os_info": client.get("os_info"),
            "connected": peer_data is not None,
            "latest_handshake": peer_data.get("latest_handshake") if peer_data else None,
            "endpoint": peer_data.get("endpoint") if peer_data else None,
            "rx_bytes": rx_bytes,
            "tx_bytes": tx_bytes,
            "total_bytes": rx_bytes + tx_bytes
        })
    
    active_count = sum(1 for c in client_stats if c["connected"])
    
    return {
        "active_clients": active_count,
        "total_clients": len(all_clients),
        "server_running": wg_status["running"],
        "clients": client_stats
    }


# Include the router in the main app
app.include_router(api_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=os.environ.get('CORS_ORIGINS', '*').split(','),
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
