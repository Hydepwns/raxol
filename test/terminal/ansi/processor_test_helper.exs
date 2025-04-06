# Disable database for ANSI processor tests
Application.put_env(:raxol, :database_url, nil)

# Start only the required applications
Application.ensure_all_started(:logger)
Application.ensure_all_started(:gen_statem)
