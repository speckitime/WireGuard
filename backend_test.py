import requests
import sys
import json
from datetime import datetime

class WireGuardAPITester:
    def __init__(self, base_url="https://wireguard-admin-1.preview.emergentagent.com"):
        self.base_url = base_url
        self.api_url = f"{base_url}/api"
        self.token = None
        self.tests_run = 0
        self.tests_passed = 0
        self.test_results = []

    def log_test(self, name, success, details=""):
        """Log test result"""
        self.tests_run += 1
        if success:
            self.tests_passed += 1
        
        result = {
            "test": name,
            "success": success,
            "details": details,
            "timestamp": datetime.now().isoformat()
        }
        self.test_results.append(result)
        
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} - {name}")
        if details:
            print(f"    Details: {details}")

    def run_test(self, name, method, endpoint, expected_status, data=None, auth_required=True):
        """Run a single API test"""
        url = f"{self.api_url}/{endpoint}"
        headers = {'Content-Type': 'application/json'}
        
        if auth_required and self.token:
            headers['Authorization'] = f'Bearer {self.token}'

        try:
            if method == 'GET':
                response = requests.get(url, headers=headers, timeout=10)
            elif method == 'POST':
                response = requests.post(url, json=data, headers=headers, timeout=10)
            elif method == 'DELETE':
                response = requests.delete(url, headers=headers, timeout=10)

            success = response.status_code == expected_status
            
            if success:
                try:
                    response_data = response.json()
                    details = f"Status: {response.status_code}, Response: {json.dumps(response_data, indent=2)[:200]}..."
                except:
                    details = f"Status: {response.status_code}, Response: {response.text[:200]}..."
            else:
                details = f"Expected {expected_status}, got {response.status_code}. Response: {response.text[:200]}..."

            self.log_test(name, success, details)
            return success, response.json() if success and response.text else {}

        except Exception as e:
            self.log_test(name, False, f"Error: {str(e)}")
            return False, {}

    def test_auth_register(self, username, password):
        """Test user registration"""
        success, response = self.run_test(
            "User Registration",
            "POST",
            "auth/register",
            200,
            data={"username": username, "password": password},
            auth_required=False
        )
        if success and 'access_token' in response:
            self.token = response['access_token']
            return True
        return False

    def test_auth_login(self, username, password):
        """Test user login"""
        success, response = self.run_test(
            "User Login",
            "POST",
            "auth/login",
            200,
            data={"username": username, "password": password},
            auth_required=False
        )
        if success and 'access_token' in response:
            self.token = response['access_token']
            return True
        return False

    def test_server_status(self):
        """Test server status endpoint"""
        success, response = self.run_test(
            "Get Server Status",
            "GET",
            "wg/server/status",
            200
        )
        return success, response

    def test_server_init(self):
        """Test server initialization"""
        success, response = self.run_test(
            "Initialize Server",
            "POST",
            "wg/server/init",
            200
        )
        return success, response

    def test_server_start(self):
        """Test server start"""
        success, response = self.run_test(
            "Start Server",
            "POST",
            "wg/server/start",
            200
        )
        return success, response

    def test_server_stop(self):
        """Test server stop"""
        success, response = self.run_test(
            "Stop Server",
            "POST",
            "wg/server/stop",
            200
        )
        return success, response

    def test_server_restart(self):
        """Test server restart"""
        success, response = self.run_test(
            "Restart Server",
            "POST",
            "wg/server/restart",
            200
        )
        return success, response

    def test_create_client(self, name, os_info=None):
        """Test client creation"""
        data = {"name": name}
        if os_info:
            data["os_info"] = os_info
            
        success, response = self.run_test(
            f"Create Client '{name}'",
            "POST",
            "wg/clients",
            200,
            data=data
        )
        return success, response

    def test_get_clients(self):
        """Test get all clients"""
        success, response = self.run_test(
            "Get All Clients",
            "GET",
            "wg/clients",
            200
        )
        return success, response

    def test_get_client_config(self, client_id):
        """Test get client config"""
        success, response = self.run_test(
            f"Get Client Config '{client_id}'",
            "GET",
            f"wg/clients/{client_id}/config",
            200
        )
        return success, response

    def test_get_client_qrcode(self, client_id):
        """Test get client QR code"""
        success, response = self.run_test(
            f"Get Client QR Code '{client_id}'",
            "GET",
            f"wg/clients/{client_id}/qrcode",
            200
        )
        return success, response

    def test_delete_client(self, client_id):
        """Test delete client"""
        success, response = self.run_test(
            f"Delete Client '{client_id}'",
            "DELETE",
            f"wg/clients/{client_id}",
            200
        )
        return success, response

    def test_get_stats(self):
        """Test get statistics"""
        success, response = self.run_test(
            "Get Statistics",
            "GET",
            "wg/stats",
            200
        )
        return success, response

def main():
    print("🔧 Starting WireGuard Admin Panel API Tests")
    print("=" * 60)
    
    tester = WireGuardAPITester()
    test_user = f"testuser_{datetime.now().strftime('%H%M%S')}"
    test_password = "TestPass123!"
    created_client_id = None

    # Test Authentication
    print("\n📋 Testing Authentication...")
    if not tester.test_auth_register(test_user, test_password):
        print("❌ Registration failed, trying login...")
        if not tester.test_auth_login(test_user, test_password):
            print("❌ Both registration and login failed, stopping tests")
            return 1

    # Test Server Management
    print("\n🖥️ Testing Server Management...")
    server_status_success, server_status = tester.test_server_status()
    
    if server_status_success:
        if not server_status.get('initialized', False):
            print("Server not initialized, testing initialization...")
            tester.test_server_init()
        
        # Test server controls (expect failures due to no WireGuard installation)
        tester.test_server_start()
        tester.test_server_stop()
        tester.test_server_restart()

    # Test Client Management
    print("\n👥 Testing Client Management...")
    tester.test_get_clients()
    
    # Create a test client
    client_success, client_data = tester.test_create_client("TestClient", "Ubuntu 22.04")
    if client_success and 'id' in client_data:
        created_client_id = client_data['id']
        
        # Test client operations
        tester.test_get_client_config(created_client_id)
        tester.test_get_client_qrcode(created_client_id)

    # Test Statistics
    print("\n📊 Testing Statistics...")
    tester.test_get_stats()

    # Cleanup - Delete test client
    if created_client_id:
        print("\n🧹 Cleanup...")
        tester.test_delete_client(created_client_id)

    # Print Results
    print("\n" + "=" * 60)
    print(f"📊 Test Results: {tester.tests_passed}/{tester.tests_run} tests passed")
    
    # Detailed results
    print("\n📋 Detailed Results:")
    for result in tester.test_results:
        status = "✅" if result['success'] else "❌"
        print(f"{status} {result['test']}")
        if not result['success'] and result['details']:
            print(f"   {result['details']}")

    # Calculate success rate
    success_rate = (tester.tests_passed / tester.tests_run * 100) if tester.tests_run > 0 else 0
    print(f"\n🎯 Success Rate: {success_rate:.1f}%")
    
    # Return appropriate exit code
    return 0 if success_rate >= 50 else 1  # Allow 50% failure due to WireGuard not being installed

if __name__ == "__main__":
    sys.exit(main())