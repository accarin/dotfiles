function hermes --description "Run Hermes Agent via Docker"
    docker run -it --rm \
        --network ornith-hermes-stack_default \
        -v ~/.hermes:/opt/data \
        -v ~/ornith-hermes-stack/projects:/workspace \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -w /workspace \
        -e HOME=/workspace \
        -e HERMES_WRITE_SAFE_ROOT=/workspace \
        -e HERMES_UID=(id -u) \
        -e HERMES_GID=(id -g) \
        -e HERMES_LLM_BASE_URL=http://ornith-llm:8080/v1 \
        -e HERMES_API_KEY=local \
        -e HERMES_MODEL=ornith-35b \
        -e HERMES_ACCEPT_HOOKS=1 \
        nousresearch/hermes-agent \
        hermes $argv
end
