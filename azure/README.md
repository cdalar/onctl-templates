# Azure DevOps self-hosted Agents

Ref: https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/agents?view=azure-devops&tabs=yaml%2Cbrowser#self-hosted-agents

# using .env file
  * Create a dot-env file.
    copy [`.env.example`](.env.example) to ".env.test" and fill in your variables:
    ```
    TOKEN=<Yout_PAT_token>
    AGENT_POOL_NAME=<POOL_NAME>
    URL=https://dev.azure.com/<ORG_NAME>
    ```
  * Run onctl command with --dot-env parameter.
    ```bash
    onctl up -n agent1 -a azure/agent-pool.sh --dot-env .env.test
    ```

# parameters in command line
  ```
  onctl up -n agent1 -a azure/agent-pool.sh -e TOKEN=<Yout_PAT_token> -e AGENT_NAME=<unique_name> -e AGENT_POOL_NAME=<POOL_NAME> -e URL=https://dev.azure.com/<ORG_NAME>
  ```

