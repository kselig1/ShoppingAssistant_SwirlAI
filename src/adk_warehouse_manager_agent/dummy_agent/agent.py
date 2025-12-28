from google.adk.agents import Agent 
from google.adk.models.lite_llm import LiteLlm  
import os 

from warehouse_manager_agent.tools import check_warehouse_availability, reserve_warehouse_items 


model = LiteLlm( 
    model = "openai/gpt-4.1-mini", 
    temperature = 0.0,  
    api_key = os.getenv("OPENAI_API_KEY"), 
) 

root_agent = Agent(  
    name = "dummy_agent", 
    model = model,  
    tools = [check_warehouse_availability, reserve_warehouse_items], 
    description="A agent that can check the availability of items in the warehouses and reserver them.", 
    instruction="""You are a part of the shopping assistant that can manage available inventory in the warehouses.

    You will be given a conversation history and a list of tools, your task is to perform actions requested by the latest user query. Answer part of the query that you can answer with the available tools.

    Instructions:
    - Use names specificly provided in the available tools. Don't add any additional text to the names.
    - You can run multipple tools at once.
    - Once you get the tool results back, you might choose to performa additional tool calls.
    - Once your suggested tool calls are done, set final_answer to True.
    - Never set final_answer to True if you are suggesting tool_calls.
    - As the final answer you should return an answer to the users query in a form of actions performed.
    - You must always check the availability of the items in the warehouses before reserving them.
    - Only reserve items in warehouses if entire order can be reserved or the user has confirmed that they want a partial reservation.
    - If you cannot reserve any items, return an answer that the order cannot be reserved.
    - If you can reserve some items, return an answer that the order can be partially reserved and include the details.
    - If only partial quantity can be reserved in some warehouses, try to combinethe required quantity from different warehouses.
    - Try to reserve items from the closest warehouse to the user first if users location is provided.
    """
)