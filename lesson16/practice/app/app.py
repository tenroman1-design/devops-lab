"""Учебное HTTP-приложение. Логи пишем в stdout в формате JSON."""
import json
import time
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        started = time.monotonic()
        request_id = str(uuid.uuid4())
        status = 200
        level = "INFO"
        message = "Запрос выполнен"

        if self.path == "/fail":
            status, level, message = 500, "ERROR", "Ошибка обработки заказа: тестовый сбой базы данных"
        elif self.path == "/slow":
            time.sleep(0.8)
            message = "Запрос выполнен медленно"
        elif self.path not in ("/", "/health"):
            status, level, message = 404, "WARN", "Страница не найдена"

        body = json.dumps({"status": status, "request_id": request_id}, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        print(json.dumps({
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "service": "demo-app",
            "level": level,
            "path": self.path,
            "status": status,
            "duration_ms": round((time.monotonic() - started) * 1000),
            "request_id": request_id,
            "message": message,
        }, ensure_ascii=False), flush=True)

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    print("Учебное приложение слушает порт 8080", flush=True)
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
