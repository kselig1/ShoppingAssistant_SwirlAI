import logging 
import os 

import uvicorn
from a2a.server.apps import A2AStarletteApplication 
from a2a.server.request_handlers import DefaultRequestHandler 
from a2a.server.tasks import InMemoryTaskStore 
from a2a.types import (
    AgentCapabilities, 
    AgentCard, 
    AgentSkill,
) 

from agent import WarehouseManagerAgent  
from agent_executor import WarehouseManagerAgentExecutor  
from dotenv import load_dotenv 
from google.adk.artifacts import InMemoryArtifactService 
from google.adk.memory.in_memory_memory_service import InMemoryMemoryService 
from google.adk.runners import Runner 
from google.adk.sessions import InMemorySessionService  

HOST = "localhost" 
PORT = 10001 

load_dotenv()  

logging.basicConfig(level=logging.INFO)  
logger = logging.getLogger(__name__)   

def main(): 
    """Starts the Agent server.""" 

    capabilities = AgentCapabilities(streaming=True) 
    skill_availability = AgentSkill(
        id="ABC",
        name="Check Availability", 
        description="Check the availability of items in the warehouses", 
        tags=["warehouse", "availability"], 
        examples=["What is the availability of the item 123?"]
    )
    skill_reservation = AgentSkill( 
        id="DEF", 
        name="Reserve Items", 
        description="Reserve items in the warehouses",  
        tags=["warehouse", "reservation"],  
        examples=["Reserve 10 items of the item 123."]
    ) 

    agent_card = AgentCard(
        name="Warehouse Manager Agent",
        description="An agent that can check the availability of items in the warehouses and reserve them.",
        url=f"http://{HOST}:{PORT}/",
        version="1.0.0",
        defaultInputModes=["text"],
        defaultOutputModes=["text"],
        capabilities=capabilities,
        skills=[skill_availability, skill_reservation],
    )

    adk_agent = WarehouseManagerAgent().get_agent()

    runner = Runner(
        app_name=agent_card.name,
        agent=adk_agent,
        artifact_service=InMemoryArtifactService(),
        session_service=InMemorySessionService(),
        memory_service=InMemoryMemoryService(),
    )

    agent_executor = WarehouseManagerAgentExecutor(runner)

    request_handler = DefaultRequestHandler(
        agent_executor=agent_executor,
        task_store=InMemoryTaskStore(),
    )

    server = A2AStarletteApplication(
        agent_card=agent_card,
        http_handler=request_handler,
    )

    uvicorn.run(
        server.build(),
        host=HOST,
        port=PORT,
    )


if __name__ == "__main__":
    main()

