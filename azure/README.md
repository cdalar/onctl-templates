# Azure DevOps self-hosted Agents

Ref: https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/agents?view=azure-devops&tabs=yaml%2Cbrowser#self-hosted-agents

# using .env file
  * Create a dot-env file.
    create the file below with your variables and save it as ".env.test"
    ```
    TOKEN=<Yout_PAT_token>
    AGENT_NAME=<unique_name>
    AGENT_POOL_NAME=<POOL_NAME>
    URL=https://dev.azure.com/<PROJECT_NAME>
    ```
  * Run onctl command with --dot-env parameter.
    ```bash
    onctl up -n agent1 -a azure/agent-pool.sh --dot-env .env.test
    ```

# parameters in command line
  ```
  onctl up -n agent1 -a azure/agent-pool.sh -e TOKEN=<Yout_PAT_token> -e AGENT_NAME=<unique_name> -e AGENT_POOL_NAME=<POOL_NAME> -e URL=https://dev.azure.com/<PROJECT_NAME>
  ```

