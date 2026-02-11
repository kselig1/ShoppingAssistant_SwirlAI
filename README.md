# Shopping Assistant - AI-Powered E-Commerce Assistant - built with SwirlAI 

Example deployment: https://shoppingassistantai.dev

An intelligent multi-agent shopping assistant built with LangGraph that helps users discover products, manage shopping carts, and check warehouse availability through natural language conversations.

## 🎯 Overview

This project is an AI-powered e-commerce shopping assistant that uses a multi-agent architecture to handle complex shopping workflows. The system can answer product questions, manage shopping carts, check warehouse inventory, and reserve items across multiple warehouses.

## ✨ Features

- **Product Search & Recommendations**: Hybrid search using vector embeddings (OpenAI) and BM25 for finding relevant products
- **Shopping Cart Management**: Add, remove, and view items in shopping carts with persistent storage
- **Warehouse Inventory Management**: Check availability and reserve items across multiple warehouses
- **Multi-Turn Conversations**: Maintains conversation context using persistent state management
- **User Reviews**: Retrieve and summarize product reviews to help with purchase decisions
- **Streaming Responses**: Real-time streaming of agent responses via Server-Sent Events (SSE)
- **Observability**: Integrated with LangSmith for tracing and monitoring

## 🏗️ Architecture

### Multi-Agent System

The application uses a **coordinator pattern** with specialized agents:

1. **Coordinator Agent**: Orchestrates the workflow and delegates tasks to appropriate agents
2. **Product QA Agent**: Answers questions about products, specifications, and provides recommendations
3. **Shopping Cart Agent**: Manages shopping cart operations (add, remove, view items)
4. **Warehouse Manager Agent**: Checks inventory availability and reserves items in warehouses

### Technology Stack

- **Backend Framework**: FastAPI
- **Frontend**: Streamlit
- **Agent Orchestration**: LangGraph
- **Vector Database**: Qdrant (Cloud) with hybrid search (BM25 + embeddings)
- **State Persistence**: Supabase (PostgreSQL) for:
  - Shopping cart data
  - Warehouse inventory
  - Conversation thread state (LangGraph checkpoints)
- **LLM Providers**: OpenAI (GPT-4.1), Groq (Llama 3.3)
- **Structured Outputs**: Instructor
- **Observability**: LangSmith
- **Deployment**: Docker & Docker Compose

## 📁 Project Structure

```
ShoppingAssistant_SwirlAI/
├── src/
│   ├── api/                    # FastAPI backend
│   │   ├── agent/              # Agent implementations
│   │   │   ├── agents.py       # Agent node definitions
│   │   │   ├── graph.py        # LangGraph workflow
│   │   │   ├── tools.py        # Tool functions (RAG, cart, warehouse)
│   │   │   └── prompts/        # Agent prompts (YAML)
│   │   ├── api/                # API endpoints
│   │   └── core/               # Configuration
│   ├── chatbot_ui/             # Streamlit frontend
│   ├── items_mcp_server/       # MCP server for items
│   └── reviews_mcp_server/     # MCP server for reviews
├── notebooks/                  # Jupyter notebooks (week-by-week development)
│   ├── week1-week8/            # Progressive development notebooks
├── sql/                        # Database schema files
├── evals/                      # Evaluation scripts
├── scripts/                    # Utility scripts
├── docker-compose.yml          # Docker services configuration
├── Dockerfile.*                # Docker images
├── pyproject.toml              # Python dependencies
└── .env                        # Environment variables (not in repo)
```

## 🚀 Getting Started

### Prerequisites

- Python 3.12+
- Docker & Docker Compose
- uv package manager
- API Keys:
  - OpenAI API key
  - Groq API key (optional, for fallback)
  - Qdrant Cloud API key and URL
  - Supabase password

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ShoppingAssistant_SwirlAI
   ```

2. **Install dependencies**
   ```bash
   uv sync
   ```

3. **Set up environment variables**
   
   Create a `.env` file in the root directory:
   ```env
   OPENAI_API_KEY=''
   GROQ_API_KEY=''
   CO_API_KEY =''
   QDRANT_API_KEY=''
   QDRANT_URL=''
   LANGSMITH_API_KEY=''
   LANGSMITH_TRACING = true 
   LANGSMITH_ENDPOINT = "https://api.smith.langchain.com"
   LANGSMITH_PROJECT = "rag-tracing" 
   SUPABASE_PASSWORD=''
   ```

4. **Set up databases**
   
   - **Qdrant**: Ensure your Qdrant collection `Amazon-items-collection-01-hybrid-search` is set up with hybrid search enabled
   - **Supabase**: Run the SQL scripts in `sql/` to create:
     - Shopping cart tables
     - Warehouse management tables
     - LangGraph checkpoint tables (via `PostgresSaver.setup()`)

5. **Run with Docker Compose**
   ```bash
   make run-docker-compose
   ```
   
   Or manually:
   ```bash
   docker compose up --build
   ```

6. **Access the application**
   - Streamlit UI: http://localhost:8501
   - FastAPI: http://localhost:8000
   - API Docs: http://localhost:8000/docs

## 🔧 Development

### Running Evaluations

```bash
# Evaluate retriever
make run-evals-retriever

# Evaluate coordinator agent
make run-evals-coordinator-agent
```

### Notebooks

The project includes week-by-week development notebooks in `notebooks/` that demonstrate the progressive development of the system:
- Week 1-4: Basic agent setup and RAG
- Week 5: Multi-turn conversations and state persistence
- Week 6: Multi-agent coordination
- Week 7: Warehouse management integration
- Week 8: Cloud deployment (Qdrant Cloud, Supabase)

## 📊 Key Components

### Tools

- **`get_formatted_item_context`**: Retrieves product information using hybrid search
- **`get_formatted_reviews_context`**: Retrieves and formats user reviews
- **`add_to_shopping_cart`**: Adds items to the shopping cart
- **`remove_from_cart`**: Removes items from the cart
- **`get_shopping_cart`**: Retrieves current cart contents
- **`check_warehouse_availability`**: Checks item availability across warehouses
- **`reserve_warehouse_items`**: Reserves items in warehouses

### State Management

The system uses LangGraph's checkpoint system with Supabase for persistent state:
- Conversation threads are persisted across sessions
- Shopping cart state is stored in PostgreSQL
- Warehouse inventory is managed in PostgreSQL

### Hybrid Search

The product search uses a hybrid approach:
- **Dense vectors**: OpenAI `text-embedding-3-small` embeddings
- **Sparse vectors**: BM25 for keyword matching
- **Fusion**: Reciprocal Rank Fusion (RRF) to combine results

## 🧪 Testing

Evaluation scripts are available in the `evals/` directory:
- Retriever evaluation
- Coordinator agent evaluation

## 🙏 Acknowledgments

Built as part of the AI End-to-end Engineering Bootcamp, demonstrating modern AI agent architectures, RAG systems, and cloud deployment practices.
