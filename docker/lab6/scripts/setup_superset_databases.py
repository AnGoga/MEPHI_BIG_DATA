#!/usr/bin/env python3
"""
Script to configure Superset database connections for Lab 6
This script must be run inside the Superset container
"""

import sys
import time
from superset import db, app
from superset.models.core import Database

def add_database(name, uri, description=""):
    """Add a database connection to Superset"""
    with app.app_context():
        # Check if database already exists
        existing = db.session.query(Database).filter_by(database_name=name).first()

        if existing:
            print(f"ℹ️  Database '{name}' already exists (id={existing.id})")
            # Update URI in case it changed
            existing.sqlalchemy_uri = uri
            db.session.commit()
            print(f"✅ Updated '{name}' connection")
            return existing

        # Create new database connection
        database = Database(
            database_name=name,
            sqlalchemy_uri=uri,
            expose_in_sqllab=True,
            allow_run_async=True,
            allow_ctas=False,
            allow_cvas=False,
            allow_dml=False
        )

        db.session.add(database)
        db.session.commit()
        print(f"✅ Created database '{name}' (id={database.id})")
        return database

def main():
    print("=" * 60)
    print("🔗 Configuring Superset Database Connections")
    print("=" * 60)
    print()

    try:
        # Add Apache Hive connection for batch data
        print("1️⃣  Adding Apache Hive (Batch Data)...")
        # Try different hostnames that Hive might be available at
        hive_hostnames = ['hive-server', 'hive', 'hiveserver2']
        hive_uri = 'hive://hive-server:10000/moex_data'

        hive_db = add_database(
            name='Apache Hive (Batch Data)',
            uri=hive_uri,
            description='Batch data from HDFS via Hive - trades and hourly volumes'
        )
        print(f"   URI: {hive_uri}")
        print(f"   ⚠️  Note: Hive may take 2-3 minutes to start after container launch")
        print()

        # Add Apache Pinot connection for streaming data
        print("2️⃣  Adding Apache Pinot (Streaming Data)...")
        pinot_db = add_database(
            name='Apache Pinot (Streaming Data)',
            uri='pinot://pinot-broker:8099/query?controller=http://pinot-controller:9001/',
            description='Real-time streaming data from Kafka - current prices'
        )
        print(f"   URI: pinot://pinot-broker:8099/query")
        print()

        # List all databases
        print("=" * 60)
        print("📊 All Configured Databases:")
        print("=" * 60)
        with app.app_context():
            all_dbs = db.session.query(Database).all()
            for database in all_dbs:
                print(f"  • {database.database_name} (id={database.id})")
                print(f"    {database.sqlalchemy_uri}")
        print()

        print("✅ Database configuration completed successfully!")
        print()
        print("🌐 Next steps:")
        print("   1. Open Superset: http://localhost:8089")
        print("   2. Login with admin / admin")
        print("   3. Go to SQL Lab → select a database")
        print("   4. Try queries like:")
        print("      - Hive: SELECT * FROM trades LIMIT 10")
        print("      - Pinot: SELECT * FROM current_prices LIMIT 10")

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
