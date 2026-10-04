FROM registry.datadoghq.com/agent:7

WORKDIR /app

COPY requirements.txt ./
RUN /opt/datadog-agent/embedded/bin/python3 -m pip install --no-cache-dir --trusted-host pypi.org --trusted-host files.pythonhosted.org -r requirements.txt

COPY app ./app

ENV PYTHONPATH=/app
EXPOSE 8084

ENTRYPOINT ["/opt/datadog-agent/embedded/bin/python3", "-m", "app.server"]
