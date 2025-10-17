from fastapi import FastAPI
from datetime import datetime, timezone
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Liatrio Demo API",
    version="1.0.0",
    description="DevOps demonstration API"
)

def get_current_timestamp() -> int:
    """Get current Unix timestamp in UTC"""
    return int(datetime.now(timezone.utc).timestamp())

@app.get("/")
async def read_root():
    """Main endpoint returning message and timestamp"""
    return {
        "message": "Automate all the things!",
        "timestamp": get_current_timestamp()
    }

@app.get("/health")
async def health_check():
    """Health check endpoint for Kubernetes probes"""
    return {
        "status": "healthy",
        "timestamp": get_current_timestamp()
    }

@app.on_event("startup")
async def startup_event():
    logger.info("Application started successfully")

@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Application shutting down gracefully")
