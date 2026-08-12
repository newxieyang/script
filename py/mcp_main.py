import asyncio
from fastmcp import Client
from fastmcp.client.transports import StdioTransport


async def main():

    transport = StdioTransport(
        command="python",
        args=[
            "py/mcp_server.py"
        ]
    )

    client = Client(transport)

    async with client:

        tools = await client.list_tools()

        print(
            "可用工具:",
            [t.name for t in tools]
        )

        result = await client.call_tool(
            "check_env_all",
            {}
        )

        print("\n环境检测结果:")
        print(result.content)


if __name__ == "__main__":
    asyncio.run(main())