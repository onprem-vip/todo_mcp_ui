import httpx
import html
from fastmcp import FastMCP
from pydantic import Field
from datetime import date, datetime, timedelta

from mcp_ui_server import create_ui_resource, UIMetadataKey
from mcp.types import TextResourceContents 
from mcp_ui_server.core import UIResource

# Initialize the FastMCP server
mcp = FastMCP("TodoAppMCP")

# API server URL
API_URL = "http://localhost:4000"

async def make_request(method: str, endpoint: str, data: dict = None) -> dict:
    """Make HTTP request to API server"""
    url = f"{API_URL}/api{endpoint}"
    
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
            if response.status_code != 204:
                return response.json()
            return None
    except httpx.ConnectError:
        raise Exception("Cannot connect to API server. Make sure it's running on http://localhost:4000")
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
    return f"All Tasks:\n{todos_text}"

@mcp.tool()
async def get_tasks_stats() -> str:
    """Get statistics about tasks (total, completed, pending)"""
    stats = await make_request("GET", "/tasks/stats")
    return f"TodoApp Statistics:\nTotal Tasks: {stats['totalTasks']}\nCompleted: {stats['completedTasks']}\nPending: {stats['activeTasks']}\nLast Updated Task: {stats['lastUpdatedTask']}\nCompletion Rate: {stats['completionPercentage']}%"

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
    return f"Created task: {result['text']} (ID: {result['id']})"

@mcp.tool(title="update_task_<%= item_id %>")
async def update_task(
    id: int, 
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
    
    result = await make_request("PUT", f"/tasks/{id}", update_data)
    return f"Updated task: {result['text']} (ID: {result['id']})"

@mcp.tool(title="complete_task_<%= item_id %>")
async def complete_task(
    id: int, 
    completed: bool = None
    ) -> str:
    """Mark task '<%= item_label %>' as complete or incomplete"""
    update_data = {"task": {}}
    # if text is not None:
    #     update_data["text"] = text
    # if notes is not None:
    #     update_data["notes"] = notes
    if completed is not None:
        update_data["task"]["completed"] = completed

    result = await make_request("PUT", f"/tasks/{id}", update_data)
    result = result['data']
    return f"Updated task: {result['text']} (ID: {result['id']})"

@mcp.tool(title="remove_task_<%= item_id %>")
async def remove_task(id: int) -> str:
    """Remove task '<%= item_label %>' from the list"""
    # result = await make_request("DELETE", f"/tasks/{id}")
    await make_request("DELETE", f"/tasks/{id}")
    return f"Deleted task with ID: {id}"
    # return result["message"]

@mcp.tool()
async def get_task_by_id(id: int) -> str:
    """Get a specific task by ID"""
    todo = await make_request("GET", f"/tasks/{id}")
    return f"Task Details:\nID: {todo['id']}\nTitle: {todo['text']}\nDescription: {todo.get('notes', '')}\nStatus: {'✅ Completed' if todo['completed'] else '⏳ Pending'}\nCreated: {todo['inserted_at']}\nUpdated: {todo['updated_at']}"

@mcp.tool(title="show_update_task_form_<%= item_id %>")
def show_update_task_form(id: int) -> list[UIResource]:
    """Show update task '<%= item_label %>' form"""
    interactive_js = """
    JS.patch("/tasks/%d/edit")
    """ % (id,)

    text_resource = TextResourceContents(
        text=interactive_js.strip(),
        mimeType="application/vnd.ex-voix.command+javascript; framework=liveviewjs",
        uri="ui://todo-app-demo/show-update-task-form"
    )
    ui_resource = UIResource(resource=text_resource)

    return [ui_resource]

@mcp.tool(title="close_any_forms")
def close_any_forms() -> list[UIResource]:
    """Close any opened forms"""
    interactive_js = """
    JS.patch("/tasks")
    """

    text_resource = TextResourceContents(
        text=interactive_js.strip(),
        mimeType="application/vnd.ex-voix.command+javascript; framework=liveviewjs",
        uri="ui://todo-app-demo/close-update-task-form"
    )
    ui_resource = UIResource(resource=text_resource)

    return [ui_resource]

@mcp.tool(title="show_stats_window")
async def show_stats_window() -> list[UIResource]:
    """Show Todo MCP-UI stats window"""
    # get stats from API
    todo_stats = await make_request("GET", f"/tasks-stats")
    stats_text = "</tr>".join([f"<tr><td align='left'>{k}</td><td>{todo_stats[k]}</td>" for k in todo_stats])
    stats_text = html.escape(f"<table>{stats_text}</table>")

    wc_script = """
        // Create a state variable to track the current logo
        let isDarkMode = false;

        // Create the main container stack with centered alignment
        const stack = document.createElement('ui-stack');
        stack.setAttribute('direction', 'vertical');
        stack.setAttribute('spacing', '20');
        stack.setAttribute('align', 'center');

        // Create the title text
        const title = document.createElement('ui-text');
        title.setAttribute('content', 'Todo MCP-UI Statistics');

        // Create a centered container for the logo
        const logoContainer = document.createElement('ui-stack');
        logoContainer.setAttribute('direction', 'vertical');
        logoContainer.setAttribute('spacing', '0');
        logoContainer.setAttribute('align', 'center');

        // Create the logo image (starts with light theme)
        const logo = document.createElement('ui-image');
        logo.setAttribute('src', 'https://block.github.io/goose/img/logo_light.png');
        logo.setAttribute('alt', 'Goose Logo');
        logo.setAttribute('width', '200');

        // Create the stats text
        const stats = document.createElement('ui-text');
        stats.setAttribute('content', '%s');

        // Create the toggle button
        const toggleButton = document.createElement('ui-button');
        toggleButton.setAttribute('label', '🌙 Switch to Dark Mode');

        // Add the toggle functionality
        toggleButton.addEventListener('press', () => {
            isDarkMode = !isDarkMode;
            
            if (isDarkMode) {
                // Switch to dark mode
                logo.setAttribute('src', 'https://block.github.io/goose/img/logo_dark.png');
                logo.setAttribute('alt', 'Goose Logo (Dark Mode)');
                toggleButton.setAttribute('label', '☀️ Switch to Light Mode');
            } else {
                // Switch to light mode
                logo.setAttribute('src', 'https://block.github.io/goose/img/logo_light.png');
                logo.setAttribute('alt', 'Goose Logo (Light Mode)');
                toggleButton.setAttribute('label', '🌙 Switch to Dark Mode');
            }
            
            console.log('Logo toggled to:', isDarkMode ? 'dark' : 'light', 'mode');
        });

        // Assemble the UI
        logoContainer.appendChild(logo);
        stack.appendChild(title);
        stack.appendChild(stats);
        stack.appendChild(logoContainer);
        stack.appendChild(toggleButton);
        root.appendChild(stack);
    """ % (stats_text,)

    ui_resource = create_ui_resource({
        "uri": "ui://todo-app-demo/show-stats-window",
        "content": {"type": "remoteDom", "script": wc_script.strip(), "framework": "webcomponents"},
        "encoding": "text",
    })

    return [ui_resource]

if __name__ == "__main__":
    print("🔌 Starting TodoAppMCP Server with FastMCP...")
    
    # Run the MCP server
    mcp.run(transport="http", host="127.0.0.1", path='/mcp', port=4002)
