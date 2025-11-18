#!/bin/bash
set -e

ENV_FILE=".env"

echo "Iniciando ambiente Elasticsearch + Kibana + Monitoring Stack"

# Função para gerar senha segura
generate_password() {
  openssl rand -base64 32 | tr -d "=+/" | cut -c1-24
}

# Função para definir ou atualizar uma variável no .env
set_env_var() {
  local key="$1"
  local value="$2"
  escaped_value=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')
  
  if [ -f "$ENV_FILE" ]; then
    if grep -q "^${key}=" "$ENV_FILE"; then
      sed -i "s/^${key}=.*$/${key}=${escaped_value}/" "$ENV_FILE"
    else
      echo "${key}=${value}" >> "$ENV_FILE"
    fi
  else
    echo "${key}=${value}" > "$ENV_FILE"
  fi
}

# Função para obter valor de uma variável no .env (só se existir e não for vazia)
get_env_value() {
  local key="$1"
  if [ -f "$ENV_FILE" ]; then
    local line
    line=$(grep "^${key}=" "$ENV_FILE" | head -n1)
    if [ -n "$line" ]; then
      local value="${line#*=}"
      if [ -n "$value" ]; then
        echo "$value"
      fi
    fi
  fi
}

# --- 1. ELASTIC_PASSWORD: respeita o .env ---
ELASTIC_PASSWORD=$(get_env_value "ELASTIC_PASSWORD")
if [ -z "$ELASTIC_PASSWORD" ]; then
  echo "Gerando ELASTIC_PASSWORD (não definida no .env)..."
  ELASTIC_PASSWORD=$(generate_password)
  set_env_var "ELASTIC_PASSWORD" "$ELASTIC_PASSWORD"
else
  echo "ELASTIC_PASSWORD carregada do .env."
fi
export ELASTIC_PASSWORD

# --- Corrigir permissões do volume do Elasticsearch ---
echo "Corrigindo permissões do volume do Elasticsearch..."
docker run --rm \
  -v elasticsearch:/usr/share/elasticsearch/data \
  --user root \
  docker.elastic.co/elasticsearch/elasticsearch:8.17.0 \
  chown -R 1000:1000 /usr/share/elasticsearch/data

# --- 2. Subir Elasticsearch ---
echo "Subindo Elasticsearch..."
docker compose --env-file "$ENV_FILE" up -d elasticsearch

echo "Aguardando Elasticsearch responder..."
for i in {1..30}; do
  if curl -s -u "elastic:$ELASTIC_PASSWORD" http://localhost:9200 >/dev/null; then
    echo "Elasticsearch está respondendo!"
    break
  fi
  sleep 2
done

if ! curl -s -u "elastic:$ELASTIC_PASSWORD" http://localhost:9200 >/dev/null; then
  echo "Elasticsearch não respondeu."
  exit 1
fi

# --- 3. Aguardar usuários internos ---
echo "Aguardando usuários internos..."
for i in {1..25}; do
  if docker exec elasticsearch bin/elasticsearch-users list 2>/dev/null | grep -q "kibana_system"; then
    echo " Usuários prontos."
    break
  fi
  sleep 2
done

# --- 4. KIBANA_SYSTEM_PASS: SEMPRE REGERAR ---
echo "Regenerando senha para 'kibana_system'..."
PASS_LINE=$(docker exec elasticsearch bin/elasticsearch-reset-password -u kibana_system -b 2>/dev/null | grep 'New value')
if [ -z "$PASS_LINE" ]; then
  echo " Falha ao gerar senha para kibana_system."
  exit 1
fi
KIBANA_SYSTEM_PASS=$(echo "$PASS_LINE" | tr -d '\r\n' | awk '{print $NF}')
set_env_var "KIBANA_SYSTEM_PASS" "$KIBANA_SYSTEM_PASS"
echo "Nova senha para kibana_system salva no .env."
export KIBANA_SYSTEM_PASS

# --- 5. APM_SECRET_TOKEN: respeita o .env ---
APM_SECRET_TOKEN=$(get_env_value "APM_SECRET_TOKEN")
if [ -z "$APM_SECRET_TOKEN" ]; then
  echo "Gerando APM_SECRET_TOKEN..."
  APM_SECRET_TOKEN=$(generate_password)
  set_env_var "APM_SECRET_TOKEN" "$APM_SECRET_TOKEN"
else
  echo "APM_SECRET_TOKEN carregado do .env."
fi
export APM_SECRET_TOKEN

# --- 5b. GF_SECURITY_ADMIN_PASSWORD: respeita o .env ---
GF_SECURITY_ADMIN_PASSWORD=$(get_env_value "GF_SECURITY_ADMIN_PASSWORD")
if [ -z "$GF_SECURITY_ADMIN_PASSWORD" ]; then
  echo "Gerando GF_SECURITY_ADMIN_PASSWORD..."
  GF_SECURITY_ADMIN_PASSWORD=$(generate_password)
  set_env_var "GF_SECURITY_ADMIN_PASSWORD" "$GF_SECURITY_ADMIN_PASSWORD"
else
  echo "GF_SECURITY_ADMIN_PASSWORD carregada do .env."
fi
export GF_SECURITY_ADMIN_PASSWORD

# --- 6. Recarregar .env para garantir que tudo esteja no ambiente ---
set -a
source "$ENV_FILE" > /dev/null 2>&1
set +a

# --- 7. Subir os demais serviços ---
echo "Subindo serviços restantes..."
docker compose --env-file "$ENV_FILE" up -d

# --- 8. Verificar APM Server ---
echo "Verificando APM Server..."
for i in {1..15}; do
  if curl -s -o /dev/null -w "%{http_code}" \
     -H "Authorization: Bearer $APM_SECRET_TOKEN" \
     http://localhost:8200 | grep -q "200"; then
    echo "APM Server está ativo!"
    break
  fi
  sleep 2
done


echo "Stack inicializada com sucesso!"
