# Simple environment loader for Julia
# Loads environment variables from .env files

"""
Load environment variables from .env files with precedence:
1. .env.local (highest precedence)
2. .env.site  
3. .env (lowest precedence)
"""
function load_env(base_dir::String = ".")
    env_files = [".env", ".env.site", ".env.local"]
    
    for env_file in env_files
        env_path = joinpath(base_dir, env_file)
        if isfile(env_path)
            try
                open(env_path, "r") do file
                    for line in eachline(file)
                        line = strip(line)
                        # Skip empty lines and comments
                        if isempty(line) || startswith(line, "#")
                            continue
                        end
                        
                        # Parse KEY=VALUE
                        if contains(line, "=")
                            key, value = split(line, "=", limit=2)
                            key = strip(key)
                            value = strip(value)
                            
                            # Remove quotes if present
                            if (startswith(value, "\"") && endswith(value, "\"")) ||
                               (startswith(value, "'") && endswith(value, "'"))
                                value = value[2:end-1]
                            end
                            
                            # Set environment variable only if not already set
                            if !haskey(ENV, key)
                                ENV[key] = value
                            end
                        end
                    end
                end
                println("📝 Loaded environment from $env_file")
            catch e
                println("⚠️  Warning: Could not load $env_file: $e")
            end
        end
    end
end

# Auto-load environment when this file is included
load_env()