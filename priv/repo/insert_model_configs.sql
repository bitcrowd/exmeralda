INSERT INTO providers (id, type, endpoint, inserted_at, updated_at)
    VALUES
      (gen_random_uuid(), 'lambda', 'https://api.lambda.ai/v1/chat/completions', NOW(), NOW()),
      (gen_random_uuid(), 'groq', 'https://api.groq.com/openai/v1/chat/completions', NOW(), NOW()),
      (gen_random_uuid(), 'hyperbolic', 'https://api.hyperbolic.xyz/v1/chat/completions', NOW(), NOW()),
      (gen_random_uuid(), 'together', 'https://api.together.xyz/v1/chat/completions', NOW(), NOW());

INSERT INTO model_configs (id, name, config, inserted_at, updated_at)
    VALUES
      (gen_random_uuid(), 'qwen25-coder-32b', '{"stream": true}', NOW(), NOW()),
      (gen_random_uuid(), 'llama-4-maverick-17b-128e', '{"stream": true}', NOW(), NOW());

INSERT INTO model_config_providers (id, model_config_id, provider_id, name, inserted_at, updated_at)
    VALUES
      (
        gen_random_uuid(),
        (SELECT id FROM model_configs WHERE name='qwen25-coder-32b'),
        (SELECT id FROM providers WHERE type='lambda'),
        'qwen25-coder-32b-instruct',
        NOW(),
        NOW()
      ),
      (
        gen_random_uuid(),
        (SELECT id FROM model_configs WHERE name='qwen25-coder-32b'),
        (SELECT id FROM providers WHERE type='groq'),
        'qwen-2.5-coder-32b',
        NOW(),
        NOW()
      ),
      (
        gen_random_uuid(),
        (SELECT id FROM model_configs WHERE name='qwen25-coder-32b'),
        (SELECT id FROM providers WHERE type='hyperbolic'),
        'Qwen/Qwen2.5-Coder-32B-Instruct',
        NOW(),
        NOW()
      ),
      (
        gen_random_uuid(),
        (SELECT id FROM model_configs WHERE name='qwen25-coder-32b'),
        (SELECT id FROM providers WHERE type='together'),
        'Qwen/Qwen2.5-Coder-32B-Instruct',
        NOW(),
        NOW()
      ),
      (
        gen_random_uuid(),
        (SELECT id FROM model_configs WHERE name='llama-4-maverick-17b-128e'),
        (SELECT id FROM providers WHERE type='groq'),
        'meta-llama/llama-4-maverick-17b-128e-instruct',
        NOW(),
        NOW()
      );

INSERT INTO generation_configs (id, model_config_provider_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), id, NOW(), NOW() from model_config_providers;
