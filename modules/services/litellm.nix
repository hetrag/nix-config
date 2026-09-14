{ config, ... }:

{
  services.litellm = {
    enable = true;
    host = "0.0.0.0";
    port = 5000;

    environmentFile = config.sops.templates."litellm-env".path;

    settings = {
      general_settings = {
        master_key = "os.environ/LITELLM_MASTER_KEY";
      };
deepseek-v4-flash-vision-exp
      model_list = [
        {
          model_name = "DeepSeek V4.1 Flash";
          litellm_params = {
            model = "openai/accounts/fireworks/models/deepseek-v4p1-flash";
            api_base = "https://yoda.teknologisk.dk/public/api-gateway/fireworks/v1";
            api_key = "os.environ/FIREWORKS_API_KEY";
          };
        }
        {
          model_name = "GLM 5.3 Flash";
          litellm_params = {
            model = "openai/accounts/fireworks/models/glm-5p3-flash";
            api_base = "https://yoda.teknologisk.dk/public/api-gateway/fireworks/v1";
            api_key = "os.environ/FIREWORKS_API_KEY";
          };
        }
        {
          model_name = "GLM 5.3 Flash";
          litellm_params = {
            model = "openai/accounts/fireworks/models/glm-5p3-flash";
            api_base = "https://yoda.teknologisk.dk/public/api-gateway/fireworks/v1";
            api_key = "os.environ/FIREWORKS_API_KEY";
          };
        }
        {
          model_name = "GLM 5.3 Coding";
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