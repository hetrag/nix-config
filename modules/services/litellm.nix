{ config, ... }:

{
  services.litellm = {
    enable = true;
    host = "127.0.0.1";
    port = 5000;

    environmentFile = config.sops.templates."litellm-env".path;

    settings = {
      general_settings = {
        master_key = "os.environ/LITELLM_MASTER_KEY";
      };

      model_list = [
        {
          model_name = "kimi-k2p6";
          litellm_params = {
            model = "openai/accounts/fireworks/models/kimi-k2p6";
            api_base = "https://yoda.teknologisk.dk/public/api-gateway/fireworks/v1";
            api_key = "os.environ/FIREWORKS_API_KEY";
          };
        }
        {
          model_name = "glm5-3-coding";
          litellm_params = {
            model = "openai/glm-5.3";
            api_base = "https://api.z.ai/api/coding/paas/v4";
            api_key = "os.environ/ZAI_API_KEY";
          };
        }
      ];
    };
  };

  # Secrets managed via sops-nix
  sops.secrets."litellm/master_key" = { };
  sops.secrets."litellm/fireworks_api_key" = { };
  sops.secrets."litellm/zai_api_key" = { };

  sops.templates."litellm-env".content = ''
    LITELLM_MASTER_KEY=${config.sops.placeholder."litellm/master_key"}
    FIREWORKS_API_KEY=${config.sops.placeholder."litellm/fireworks_api_key"}
    ZAI_API_KEY=${config.sops.placeholder."litellm/zai_api_key"}
  '';
}