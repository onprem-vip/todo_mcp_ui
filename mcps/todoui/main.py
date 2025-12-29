import httpx
from fastmcp import FastMCP
from pydantic import Field
from datetime import date, datetime, timedelta

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
async def get_tasks() -> str:
    """Get all tasks from the TodoAppMCP application"""
    todos = await make_request("GET", "/tasks")
    todos = todos['data']
    todos_text = "\n".join([
        f"ID: {todo['id']} | {todo['text']} | {'✅' if todo['completed'] else '⏳'} | {todo.get('notes', '')}"
        for todo in todos
    ])
    return f"All Todos:\n{todos_text}"

@mcp.tool()
async def get_tasks_stats() -> str:
    """Get statistics about tasks (total, completed, pending)"""
    stats = await make_request("GET", "/tasks/stats")
    return f"Todo Statistics:\nTotal Tasks: {stats['totalTasks']}\nCompleted: {stats['completedTasks']}\nPending: {stats['activeTasks']}\nLast Updated Task: {stats['lastUpdatedTask']}\nCompletion Rate: {stats['completionPercentage']}%"

@mcp.tool(title="add_task")
async def add_task(
    text: str = Field("Text of the task to add"), 
    # notes: str = None, 
    # completed: bool = False
    ) -> str:
    """Add a new task to the list"""
    now = datetime.now()
    due_date = now + timedelta(days=7)
    todo_data = {
        "task": {
            "text": text,
            "priority": "medium",
            "due_date": due_date.date().isoformat(),
            "notes": "",
            "completed": False
        }
    }
    result = await make_request("POST", "/tasks", todo_data)
    result = result['data']
    return f"Created todo: {result['text']} (ID: {result['id']})"

@mcp.tool(title="update_task_<%= item_id %>")
async def update_task(
    task_id: int, 
    text: str = None, 
    priority: str = None,
    due_date: date = None,
    notes: str = None, 
    completed: bool = None
    ) -> str:
    """Update an existing task"""
    update_data = {"task": {}}
    if text is not None:
        update_data["task"]["text"] = text
    if priority is not None:
        update_data["task"]["priority"] = priority
    if due_date is not None:
        # if isinstance(due_date, (date)):
        update_data["task"]["due_date"] = due_date.isoformat()
        # else:
        #     update_data["task"]["due_date"] = due_date
    if notes is not None:
        update_data["task"]["notes"] = notes
    if completed is not None:
        update_data["task"]["completed"] = completed
    
    result = await make_request("PUT", f"/tasks/{task_id}", update_data)
    return f"Updated todo: {result['text']} (ID: {result['id']})"

@mcp.tool(title="complete_task_<%= item_id %>")
async def complete_task(
    task_id: int, 
    completed: bool = None
    ) -> str:
    """Mark task '<%= item_label %>' as complete"""
    update_data = {}
    # if text is not None:
    #     update_data["text"] = text
    # if notes is not None:
    #     update_data["notes"] = notes
    if completed is not None:
        update_data["completed"] = completed

    result = await make_request("PUT", f"/tasks/{task_id}", update_data)
    return f"Updated todo: {result['text']} (ID: {result['id']})"

@mcp.tool(title="remove_task_<%= item_id %>")
async def remove_task(task_id: int) -> str:
    """Remove task '<%= item_label %>' from the list"""
    result = await make_request("DELETE", f"/tasks/{task_id}")
    return result["message"]

@mcp.tool()
async def get_task_by_id(task_id: int) -> str:
    """Get a specific task by ID"""
    todo = await make_request("GET", f"/tasks/{task_id}")
    return f"Todo Details:\nID: {todo['id']}\nTitle: {todo['text']}\nDescription: {todo.get('notes', '')}\nStatus: {'✅ Completed' if todo['completed'] else '⏳ Pending'}\nCreated: {todo['inserted_at']}\nUpdated: {todo['updated_at']}"

if __name__ == "__main__":
    print("🔌 Starting TodoAppMCP Server with FastMCP...")
    
    # Run the MCP server
    mcp.run(transport="http", host="127.0.0.1", port=4002)
