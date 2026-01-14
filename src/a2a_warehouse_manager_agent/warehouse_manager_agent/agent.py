# from a2a.server.agent_execution import AgentExecutor 
# from a2a.server.agent_execution.context import RequestContext 
# from a2a.server.events.event_queue import EventQueue 
# from a2a.utils import new_agent_text_message 
# from pydantic import BaseModel 


from google.adk.agents import LlmAgent 
from google.adk.models.lite_llm import LiteLlm  
import os 

from tools import check_warehouse_availability, reserve_warehouse_items 

class WarehouseManagerAgent(): 

    def __init__(self):
        self.model = LiteLlm( 
            model = "openai/gpt-4.1-mini", 
            temperature = 0.0,  
            api_key = os.getenv("OPENAI_API_KEY"), 
        )
        self.agent = LlmAgent(
            name = "warehouse_manager_agent",
            model = self.model,
            tools = [check_warehouse_availability, reserve_warehouse_items],
            description = "A agent that can check the availability of items in the warehouses and reserver them.",
            instruction = """You are a part of the shopping assistant that can manage available inventory in the warehouses.

            You will be given a conversation history and a list of tools, your task is to perform actions requested by the latest user query. Answer part of the query that you can answer with the available tools.

            Instructions:
            - You must always check the availability of the items in the warehouses before reserving them.
            - Only reserve items in warehouses if entire order can be reserved or the user has confirmed that they want a partial reservation.
            - If you cannot reserve any items, return an answer that the order cannot be reserved.
            - If you can reserve some items, return an answer that the order can be partially reserved and include the details.
            - If only partial quantity can be reserved in some warehouses, try to combinethe required quantity from different warehouses.
            - Try to reserve items from the closest warehouse to the user first if users location is provided.
            """
        )

    def get_agent(self) -> LlmAgent:
        return self.agent