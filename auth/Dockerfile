FROM python:3.12-slim
WORKDIR /app
COPY auth/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY auth/app.py .
COPY auth/game_features.py .
EXPOSE 8080
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
