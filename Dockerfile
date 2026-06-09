FROM python:3.11-slim

WORKDIR /app

# Install dependencies first to leverage Docker layer caching.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application source.
COPY . .

# Default to HTTP transport so the container works as a long-running service.
# Bind to 0.0.0.0 so the server is reachable from outside the container.
# For stdio (e.g. Claude Desktop), override the command — see the README.
EXPOSE 8000
ENTRYPOINT ["fastmcp", "run", "server.py:mcp"]
CMD ["--transport", "http", "--host", "0.0.0.0", "--port", "8000"]
