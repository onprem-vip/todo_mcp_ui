import httpx
from fastmcp import FastMCP

# Initialize the FastMCP server
mcp = FastMCP("TodoAppMCP", streamable_http_path='/mcp')

# FastAPI server URL
FASTAPI_URL = "http://localhost:4000"

async def make_request(method: str, endpoint: str, data: dict = None) -> dict:
    """Make HTTP request to FastAPI server"""
    url = f"{FASTAPI_URL}/api{endpoint}"
    
    try:
        async with httpx.AsyncClient() as client:
            if method == "GET":
                response = await client.get(url)
            elif method == "POST":
                response = await client.post(url, json=data)
            elif method == "PUT":
                response = await client.put(url, json=data)
            elif method == "DELETE":
                response = await client.delete(url)
            else:
                raise ValueError(f"Unsupported HTTP method: {method}")
            
            response.raise_for_status()
            return response.json()
    except httpx.ConnectError:
        raise Exception("Cannot connect to FastAPI server. Make sure it's running on http://localhost:4000")
    except httpx.HTTPStatusError as e:
        raise Exception(f"HTTP error: {e.response.status_code} - {e.response.text}")

@mcp.tool()
async def get_todos() -> str:
    """Get all todos from the FastAPI application"""
    todos = await make_request("GET", "/tasks")
    todos_text = "\n".join([
        f"ID: {todo['id']} | {todo['text']} | {'✅' if todo['completed'] else '⏳'} | {todo.get('notes', '')}"
        for todo in todos
    ])
    return f"All Todos:\n{todos_text}"

@mcp.tool()
async def get_todo_stats() -> str:
    """Get statistics about todos (total, completed, pending)"""
    stats = await make_request("GET", "/tasks/stats")
    return f"Todo Statistics:\nTotal Tasks: {stats['totalTasks']}\nCompleted: {stats['completedTasks']}\nPending: {stats['activeTasks']}\nLast Updated Task: {stats['lastUpdatedTask']}\nCompletion Rate: {stats['completionPercentage']}%"

@mcp.tool()
async def create_todo(text: str, notes: str = None, completed: bool = False) -> str:
    """Create a new todo item"""
    todo_data = {
        "text": text,
        "notes": notes,
        "completed": completed
    }
    result = await make_request("POST", "/tasks", todo_data)
    return f"Created todo: {result['text']} (ID: {result['id']})"

@mcp.tool()
async def update_todo(task_id: int, text: str = None, notes: str = None, completed: bool = None) -> str:
    """Update an existing todo"""
    update_data = {}
    if text is not None:
        update_data["text"] = text
    if notes is not None:
        update_data["notes"] = notes
    if completed is not None:
        update_data["completed"] = completed
    
    result = await make_request("PUT", f"/tasks/{task_id}", update_data)
    return f"Updated todo: {result['text']} (ID: {result['id']})"

@mcp.tool()
async def delete_todo(task_id: int) -> str:
    """Delete a todo by ID"""
    result = await make_request("DELETE", f"/tasks/{task_id}")
    return result["message"]

@mcp.tool()
async def get_todo_by_id(task_id: int) -> str:
    """Get a specific todo by ID"""
    todo = await make_request("GET", f"/tasks/{task_id}")
    return f"Todo Details:\nID: {todo['id']}\nTitle: {todo['text']}\nDescription: {todo.get('notes', '')}\nStatus: {'✅ Completed' if todo['completed'] else '⏳ Pending'}\nCreated: {todo['inserted_at']}\nUpdated: {todo['updated_at']}"

if __name__ == "__main__":
    print("🔌 Starting Todo MCP Server with FastMCP...")
    
    # Run the MCP server
    mcp.run(transport="http", host="127.0.0.1", port=4002)
