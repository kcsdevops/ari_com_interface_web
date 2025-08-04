from flask import Flask, render_template, request, redirect, url_for, session, flash, jsonify
from flask_session import Session
import os
import json
import logging
from datetime import datetime, timedelta
import msal
import requests
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential
import asyncio
import sys
import subprocess
from pathlib import Path

# Add the parent directory to Python path to import ARI modules
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

try:
    from automation.ari_executor import ARIExecutor
    from cost_analysis.cost_collector import CostCollector
    from data_processing.data_transformer import DataTransformer
    from utils.config_manager import ConfigManager
    from utils.logger_config import setup_logging
except ImportError as e:
    print(f"Warning: Could not import ARI modules: {e}")
    # Create mock classes for development
    class ARIExecutor:
        async def execute_ari(self, *args, **kwargs):
            return {"status": "success", "message": "Mock ARI execution"}
    
    class CostCollector:
        async def collect_costs(self, *args, **kwargs):
            return {"status": "success", "message": "Mock cost collection"}

app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
app.config['SESSION_TYPE'] = 'filesystem'
app.config['SESSION_PERMANENT'] = False
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(hours=24)

# Initialize session
Session(app)

# Setup logging
setup_logging(level="INFO", console=True)
logger = logging.getLogger(__name__)

# Azure AD Configuration
AZURE_CLIENT_ID = os.environ.get('AZURE_CLIENT_ID')
AZURE_CLIENT_SECRET = os.environ.get('AZURE_CLIENT_SECRET')
AZURE_TENANT_ID = os.environ.get('AZURE_TENANT_ID')
AZURE_AUTHORITY = f"https://login.microsoftonline.com/{AZURE_TENANT_ID}"
AZURE_SCOPE = ["https://graph.microsoft.com/User.Read"]

# Storage Configuration
STORAGE_ACCOUNT_NAME = os.environ.get('AZURE_STORAGE_ACCOUNT_NAME')
STORAGE_CONNECTION_STRING = os.environ.get('AZURE_STORAGE_CONNECTION_STRING')

# Initialize MSAL
msal_app = msal.ConfidentialClientApplication(
    AZURE_CLIENT_ID,
    authority=AZURE_AUTHORITY,
    client_credential=AZURE_CLIENT_SECRET,
)

def get_user_info():
    """Get user information from session"""
    return session.get('user', {})

def is_authenticated():
    """Check if user is authenticated"""
    return 'user' in session and session.get('token_cache')

@app.route('/health')
def health():
    """Health check endpoint for Container Apps"""
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()}), 200

@app.route('/')
def index():
    """Home page"""
    if not is_authenticated():
        return redirect(url_for('login'))
    
    user = get_user_info()
    return render_template('index.html', user=user)

@app.route('/login')
def login():
    """Login page"""
    if is_authenticated():
        return redirect(url_for('index'))
    
    # Generate authentication URL
    auth_url = msal_app.get_authorization_request_url(
        AZURE_SCOPE,
        redirect_uri=url_for('auth_callback', _external=True)
    )
    
    return render_template('login.html', auth_url=auth_url)

@app.route('/auth/callback')
def auth_callback():
    """Azure AD authentication callback"""
    if request.args.get('error'):
        flash(f"Authentication error: {request.args.get('error_description', 'Unknown error')}", 'error')
        return redirect(url_for('login'))
    
    code = request.args.get('code')
    if not code:
        flash('Authorization code not received', 'error')
        return redirect(url_for('login'))
    
    try:
        # Exchange code for token
        result = msal_app.acquire_token_by_authorization_code(
            code,
            scopes=AZURE_SCOPE,
            redirect_uri=url_for('auth_callback', _external=True)
        )
        
        if 'error' in result:
            flash(f"Token acquisition error: {result.get('error_description', 'Unknown error')}", 'error')
            return redirect(url_for('login'))
        
        # Get user info from Microsoft Graph
        headers = {'Authorization': f"Bearer {result['access_token']}"}
        user_response = requests.get('https://graph.microsoft.com/v1.0/me', headers=headers)
        
        if user_response.status_code == 200:
            user_info = user_response.json()
            session['user'] = {
                'id': user_info.get('id'),
                'name': user_info.get('displayName'),
                'email': user_info.get('mail') or user_info.get('userPrincipalName'),
                'tenant_id': AZURE_TENANT_ID
            }
            session['token_cache'] = result
            flash(f"Welcome, {user_info.get('displayName')}!", 'success')
            return redirect(url_for('index'))
        else:
            flash('Failed to get user information', 'error')
            return redirect(url_for('login'))
            
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        flash('Authentication failed. Please try again.', 'error')
        return redirect(url_for('login'))

@app.route('/logout')
def logout():
    """Logout user"""
    session.clear()
    flash('You have been logged out successfully.', 'info')
    return redirect(url_for('login'))

@app.route('/ari-form')
def ari_form():
    """ARI execution form"""
    if not is_authenticated():
        return redirect(url_for('login'))
    
    user = get_user_info()
    return render_template('ari_form.html', user=user)

@app.route('/execute-ari', methods=['POST'])
def execute_ari():
    """Execute ARI automation"""
    if not is_authenticated():
        return jsonify({'error': 'Not authenticated'}), 401
    
    try:
        # Get form data
        tenant_id = request.form.get('tenant_id', '').strip()
        subscription_ids = request.form.get('subscription_ids', '').strip()
        include_costs = request.form.get('include_costs') == 'on'
        generate_powerbi = request.form.get('generate_powerbi') == 'on'
        
        # Validate inputs
        if not tenant_id:
            return jsonify({'error': 'Tenant ID is required'}), 400
        
        # Parse subscription IDs
        subscription_list = []
        if subscription_ids:
            subscription_list = [s.strip() for s in subscription_ids.replace('\n', ',').split(',') if s.strip()]
        
        # Log the execution request
        user = get_user_info()
        logger.info(f"ARI execution requested by {user.get('email')} for tenant {tenant_id}")
        
        # Create execution parameters
        execution_params = {
            'tenant_id': tenant_id,
            'subscription_ids': subscription_list,
            'include_costs': include_costs,
            'generate_powerbi': generate_powerbi,
            'requested_by': user.get('email'),
            'request_time': datetime.utcnow().isoformat()
        }
        
        # For now, return success with mock data
        # In production, this would trigger the actual ARI execution
        result = {
            'status': 'success',
            'message': 'ARI execution started successfully',
            'execution_id': f"ari-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}",
            'parameters': execution_params
        }
        
        # Store execution in session for tracking
        if 'executions' not in session:
            session['executions'] = []
        session['executions'].append(result)
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"ARI execution error: {e}")
        return jsonify({'error': f'Execution failed: {str(e)}'}), 500

@app.route('/executions')
def executions():
    """View execution history"""
    if not is_authenticated():
        return redirect(url_for('login'))
    
    user = get_user_info()
    user_executions = session.get('executions', [])
    
    return render_template('executions.html', user=user, executions=user_executions)

@app.route('/api/subscriptions/<tenant_id>')
def get_subscriptions(tenant_id):
    """Get subscriptions for a tenant (API endpoint)"""
    if not is_authenticated():
        return jsonify({'error': 'Not authenticated'}), 401
    
    try:
        # Mock subscription data - in production, this would query Azure
        mock_subscriptions = [
            {
                'id': 'sub-12345678-1234-1234-1234-123456789012',
                'name': 'Production Subscription',
                'state': 'Enabled'
            },
            {
                'id': 'sub-87654321-4321-4321-4321-210987654321',
                'name': 'Development Subscription',
                'state': 'Enabled'
            },
            {
                'id': 'sub-11111111-2222-3333-4444-555555555555',
                'name': 'Testing Subscription',
                'state': 'Enabled'
            }
        ]
        
        return jsonify({
            'tenant_id': tenant_id,
            'subscriptions': mock_subscriptions
        })
        
    except Exception as e:
        logger.error(f"Error getting subscriptions: {e}")
        return jsonify({'error': 'Failed to get subscriptions'}), 500

@app.route('/api/run-ari', methods=['POST'])
def api_run_ari():
    """API endpoint to execute the run_ari.ps1 PowerShell script"""
    if not is_authenticated():
        return jsonify({'error': 'Not authenticated'}), 401
    
    try:
        # Get request data
        data = request.json or {}
        tenant_id = data.get('tenant_id', '')
        subscription_ids = data.get('subscription_ids', [])
        include_costs = data.get('include_costs', True)
        include_tags = data.get('include_tags', True)
        
        # Log the execution request
        user = get_user_info()
        logger.info(f"ARI execution requested by {user.get('email')} for tenant {tenant_id}")
        
        # Create execution ID
        execution_id = f"ari-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}"
        
        # Path to PowerShell script
        script_path = Path(__file__).parent.parent / "run_ari.ps1"
        
        # Add parameters to PowerShell command
        command = [
            "pwsh", 
            "-File", 
            str(script_path)
        ]
        
        if tenant_id:
            command.extend(["-TenantID", tenant_id])
        
        if subscription_ids:
            sub_ids_str = ",".join(subscription_ids)
            command.extend(["-SubscriptionIDs", sub_ids_str])
        
        # Start the process asynchronously
        logger.info(f"Starting ARI execution process: {' '.join(command)}")
        
        # In a real implementation, you would use a task queue or background worker
        # For this example, we'll use subprocess with Popen to avoid blocking
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        # Store execution info
        execution_info = {
            'execution_id': execution_id,
            'status': 'running',
            'start_time': datetime.utcnow().isoformat(),
            'requested_by': user.get('email'),
            'command': ' '.join(command),
            'tenant_id': tenant_id,
            'subscription_ids': subscription_ids,
            'include_costs': include_costs,
            'include_tags': include_tags
        }
        
        # Store in session for tracking
        if 'executions' not in session:
            session['executions'] = []
        session['executions'].append(execution_info)
        
        return jsonify({
            'status': 'success',
            'message': 'ARI execution started successfully',
            'execution_id': execution_id,
            'details': execution_info
        })
        
    except Exception as e:
        logger.error(f"API run ARI error: {e}")
        return jsonify({'error': f'Execution failed: {str(e)}'}), 500

@app.route('/run-ari')
def run_ari_page():
    """Page to run ARI directly"""
    if not is_authenticated():
        return redirect(url_for('login'))
    
    user = get_user_info()
    return render_template('run_ari.html', user=user)

@app.errorhandler(404)
def not_found(error):
    return render_template('error.html', error_code=404, error_message="Page not found"), 404

@app.errorhandler(500)
def internal_error(error):
    return render_template('error.html', error_code=500, error_message="Internal server error"), 500

if __name__ == '__main__':
    # Development server
    app.run(debug=True, host='0.0.0.0', port=8000)
