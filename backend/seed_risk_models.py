"""
Seed script to create default risk models in MongoDB
"""
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from datetime import datetime
import os
from dotenv import load_dotenv

load_dotenv()

MONGODB_URI = os.getenv("MONGODB_URI")
DB_NAME = os.getenv("DB_NAME", "fsi-threatsight360")

async def seed_risk_models():
    """Create default risk models"""
    client = AsyncIOMotorClient(MONGODB_URI)
    db = client[DB_NAME]
    risk_models = db["risk_models"]
    
    # Check if models already exist
    existing_count = await risk_models.count_documents({})
    if existing_count > 0:
        print(f"✓ {existing_count} risk models already exist. Skipping seed.")
        return
    
    # Default risk model
    default_model = {
        "modelId": "default-risk-model",
        "version": 1,
        "status": "active",
        "createdAt": datetime.now(),
        "updatedAt": datetime.now(),
        "description": "Default risk scoring model with balanced weights",
        "thresholds": {
            "flag": 60,
            "block": 85
        },
        "weights": {
            "amount_anomaly_high": 30,
            "amount_anomaly_medium": 15,
            "location_anomaly": 25,
            "merchant_category_anomaly": 10,
            "unknown_device": 35,
            "velocity_anomaly": 20
        },
        "riskFactors": [
            {
                "id": "amount_anomaly_high",
                "description": "Transaction amount significantly higher than customer average",
                "threshold": 3.0,
                "active": True
            },
            {
                "id": "amount_anomaly_medium",
                "description": "Transaction amount moderately higher than customer average",
                "threshold": 2.0,
                "active": True
            },
            {
                "id": "location_anomaly",
                "description": "Transaction from unusual location",
                "distanceThreshold": 100,
                "active": True
            },
            {
                "id": "merchant_category_anomaly",
                "description": "Transaction in unusual merchant category",
                "active": True
            },
            {
                "id": "unknown_device",
                "description": "Transaction from unknown device",
                "active": True
            },
            {
                "id": "velocity_anomaly",
                "description": "Multiple transactions in short timeframe",
                "threshold": 5,
                "active": True
            }
        ],
        "performance": {
            "falsePositiveRate": None,
            "falseNegativeRate": None,
            "avgProcessingTime": None
        }
    }
    
    # Behavioral risk model
    behavioral_model = {
        "modelId": "behavioral-risk-model",
        "version": 1,
        "status": "inactive",
        "createdAt": datetime.now(),
        "updatedAt": datetime.now(),
        "description": "Behavioral analysis model focusing on pattern detection",
        "thresholds": {
            "flag": 55,
            "block": 80
        },
        "weights": {
            "amount_anomaly_high": 25,
            "amount_anomaly_medium": 12,
            "location_anomaly": 30,
            "merchant_category_anomaly": 15,
            "unknown_device": 30,
            "velocity_anomaly": 25
        },
        "riskFactors": [
            {
                "id": "amount_anomaly_high",
                "description": "Transaction amount significantly higher than customer average",
                "threshold": 2.5,
                "active": True
            },
            {
                "id": "amount_anomaly_medium",
                "description": "Transaction amount moderately higher than customer average",
                "threshold": 1.8,
                "active": True
            },
            {
                "id": "location_anomaly",
                "description": "Transaction from unusual location",
                "distanceThreshold": 80,
                "active": True
            },
            {
                "id": "merchant_category_anomaly",
                "description": "Transaction in unusual merchant category",
                "active": True
            },
            {
                "id": "unknown_device",
                "description": "Transaction from unknown device",
                "active": True
            },
            {
                "id": "velocity_anomaly",
                "description": "Multiple transactions in short timeframe",
                "threshold": 4,
                "active": True
            }
        ],
        "performance": {
            "falsePositiveRate": None,
            "falseNegativeRate": None,
            "avgProcessingTime": None
        }
    }
    
    # Insert models
    await risk_models.insert_many([default_model, behavioral_model])
    print(f"✓ Created 2 default risk models")
    print(f"  - {default_model['modelId']} (active)")
    print(f"  - {behavioral_model['modelId']} (inactive)")

if __name__ == "__main__":
    asyncio.run(seed_risk_models())
