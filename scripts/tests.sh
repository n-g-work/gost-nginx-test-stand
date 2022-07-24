#!/usr/bin/env bash
set -o errtrace
trap 'echo "error occurred on line $LINENO ";exit 1' ERR

curl_verbose="" # -v for verbose curl output, empty - for non-verbose

log_file_path="/vagrant/$(date -Is | tr '+:' '-').log"

log(){
    message=$(echo "$1" | tr '#' '\n')
    echo "[$(date -Ins)]: ${message}" >> "${log_file_path}"
}

run_test(){
    name=$1; command=$2
    log "Test: ${name}"
    /bin/bash -c "${command}"
}

log "Starting tests"
log "Result: #$(run_test "Simple test of output" "echo 'OK: If you see this text, then test has passed successfully!'")"
log "Result: #OK, if docker containers have status Started.$(run_test "docker status" "docker ps -a 2>&1")"
log "Result: #OK, if empty or no errors$(run_test "docker logs nginx-mid" "docker logs nginx-mid 2>&1")"
log "Result: #OK, if empty or no errors$(run_test "docker logs nginx-target" "docker logs nginx-target 2>&1")"

# test nginx-target on port 80 - http without certificates
log "Result: #$(run_test "nginx-target on port 80" "curl ${curl_verbose} -Ssf 0.0.0.0:80 2>&1")"

# tests directly to nginx-target with client certificates
for port in 443 1443 2443 3443 4443 5443; do
  for cert in ca mid client; do
    test="docker run --rm -v /vagrant/nginx/ssl:/ssl --network=gost-network localhost:5000/gost-tools:v1 sh -c \
      'curl ${curl_verbose} -kSsf https://nginx-target:${port} --cert /ssl/generated/${cert}.crt:password --key /ssl/generated/${cert}.key 2>&1'"
    log "Result: #$(run_test "nginx-target with ${cert}.crt as client certificate on port ${port}" "${test}")"
  done
done

# tests to nginx-target through nginx-mid
for port in {8080..8100}; do
  log "Result: #$(run_test "nginx-mid on port ${port}" "curl ${curl_verbose} -Ssf 0.0.0.0:${port} 2>&1")"
done
