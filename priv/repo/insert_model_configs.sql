INSERT INTO providers (id, type, name, config, inserted_at, updated_at)
    VALUES
      (gen_random_uuid(), 'openai', 'lambda_ai', '{"endpoint": "https://api.lambda.ai/v1/chat/completions"}', NOW(), NOW()),
      (gen_random_uuid(), 'openai', 'groq_ai', '{"endpoint": "https://api.groq.com/openai/v1/chat/completions"}', NOW(), NOW()),
      (gen_random_uuid(), 'openai', 'hyperbolic_ai', '{"endpoint": "https://api.hyperbolic.xyz/v1/chat/completions"}', NOW(), NOW()),
      (gen_random_uuid(), 'openai', 'together_ai', '{"endpoint": "https://api.together.xyz/v1/chat/completions"}', NOW(), NOW());

INSERT INTO model_configs (id, name, config, inserted_at, updated_at)
    VALUES
      (gen_random_uuid(), 'qwen25-coder-32b', '{"stream": true}', NOW(), NOW()),
      (gen_random_uuid(), 'llama-4-maverick-17b-128e', '{"stream": true}', NOW(), NOW());
      (gen_random_uuid(), 'qwen25-7b-instruct-turbo', '{"stream": true}', NOW(), NOW());

INSERT INTO model_config_providers (id, model_config_id, provider_id, name, inserted_at, updated_at)
    VALUES
      (
        gen_random_uuid(),
        (SELECT id FROM model_configs WHERE name='qwen25-coder-32b'),
        (SELECT id FROM providers WHERE name='lambda_ai'),
        'qwen25-coder-32b-instruct',
        NOW(),
        NOW()
      ),
      (
        gen_random_uuid(),
        (SELECT id FROM model_configs WHERE name='qwen25-coder-32b'),
        (SELECT id FROM providers WHERE name='groq_ai'),
        'qwen-2.5-coder-32b',
        NOW(),
        NOW()
      ),
      (
        gen_random_uuid(),
        (SELECT id FROM model_configs WHERE name='qwen25-coder-32b'),
        (SELECT id FROM providers WHERE name='hyperbolic_ai'),
        'Qwen/Qwen2.5-Coder-32B-Instruct',
        NOW(),
        NOW()
      ),
      (
        gen_random_uuid(),
        (SELECT id FROM model_configs WHERE name='qwen25-coder-32b'),
        (SELECT id FROM providers WHERE name='together_ai'),
        'Qwen/Qwen2.5-Coder-32B-Instruct',
        NOW(),
        NOW()
      ),
      (
        gen_random_uuid(),
        (SELECT id FROM model_configs WHERE name='llama-4-maverick-17b-128e'),
        (SELECT id FROM providers WHERE name='groq_ai'),
        'meta-llama/llama-4-maverick-17b-128e-instruct',
        NOW(),
        NOW()
      ),
      (
        gen_random_uuid(),
        (SELECT id FROM model_configs WHERE name='qwen25-7b-instruct-turbo'),
        (SELECT id FROM providers WHERE name='together_ai'),
        'Qwen/Qwen2.5-7B-Instruct-Turbo',
        NOW(),
        NOW()
      );
