from fastmcp import FastMCP

mcp = FastMCP(name="TodoApp")

@mcp.tool
def add_task(text: str) -> str:
    return f"Hello, {text}!"

if __name__ == "__main__":
    mcp.run()
