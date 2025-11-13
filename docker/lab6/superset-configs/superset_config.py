# Apache Superset Configuration for MOEX Data Pipeline
# Lab 6: Visualization

import os

# Flask App Builder configuration
ROW_LIMIT = 5000

# Flask-WTF flag for CSRF
WTF_CSRF_ENABLED = True

# Add endpoints that need to be exempt from CSRF protection
WTF_CSRF_EXEMPT_LIST = []

# Security
SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY', 'moex_superset_secret_key_change_in_production')

# Database connection for metadata
SQLALCHEMY_DATABASE_URI = 'postgresql+psycopg2://superset:superset@superset-db:5432/superset'

# Superset specific config
SUPERSET_WEBSERVER_PORT = 8088

# Set the authentication type
AUTH_TYPE = 1  # AUTH_DB

# Allow embedding
ENABLE_PROXY_FIX = True

# Cache configuration
CACHE_CONFIG = {
    'CACHE_TYPE': 'SimpleCache',
    'CACHE_DEFAULT_TIMEOUT': 300,
}

# Enable scheduled queries
SCHEDULED_QUERIES = {
    'SCHEDULE_QUERIES': True,
}

# Feature flags
FEATURE_FLAGS = {
    'ENABLE_TEMPLATE_PROCESSING': True,
    'DASHBOARD_NATIVE_FILTERS': True,
    'DASHBOARD_CROSS_FILTERS': True,
    'DASHBOARD_NATIVE_FILTERS_SET': True,
    'VERSIONED_EXPORT': True,
}

# Async query configuration
SQLLAB_ASYNC_TIME_LIMIT_SEC = 300

# Results backend
RESULTS_BACKEND = None

# Celery configuration (disabled for simple deployment)
class CeleryConfig:
    broker_url = 'redis://localhost:6379/0'
    imports = ('superset.sql_lab',)
    result_backend = 'redis://localhost:6379/0'
    worker_prefetch_multiplier = 1
    task_acks_late = False

# CELERY_CONFIG = CeleryConfig

# Mapbox API key (optional, for map visualizations)
MAPBOX_API_KEY = os.environ.get('MAPBOX_API_KEY', '')
