import os
import time
from elasticapm import Client

token = "5DziqjmL9Gs505NkY0SujEEO"  
if not token:
    raise EnvironmentError("❌ APM_SECRET_TOKEN não definido!")

client = Client(
    service_name="lambda-apm-local",
    server_url="http://localhost:8200",
    environment="local",
    secret_token=token,
    capture_exceptions=True,
    debug=True,
)

def simulate_lambda():
    client.begin_transaction("request")
    client.capture_message("🚀 Lambda local começou o processamento")

    with client.capture_span("processamento_lento", "custom"):
        time.sleep(1.5)

    client.end_transaction("lambda_test", "success")

if __name__ == "__main__":
    print("📤 Enviando trace para o APM Server...")
    simulate_lambda()
    client.close()  # ⚠️ OBRIGATÓRIO!
    print("✅ Trace enviado com sucesso!")