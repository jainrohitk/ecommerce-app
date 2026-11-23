import logging
import sys

sys.path.insert(0, "/usr/src/app")

from locustfile import WebsiteUser

WebsiteUser.tasks = [
    task for task in WebsiteUser.tasks if task.__name__ != "ask_agent"
]
logging.info("Shopping-only traffic: the undeployed AI-agent task is disabled")
