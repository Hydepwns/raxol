use Mix.Config

config :burrito,
  # Base configuration
  app_name: "raxol",
  base_output_dir: "burrito_out",
  base_path: "",
  
  # Development profile
  dev: [
    steps: [
      # Steps for development building
      :download_burrito_packages,
      :copy_beam_files,
      :copy_runtime_files,
      :make_boot_script,
      :configure_cuttlefish
    ],
    output_dir: "dev",
    # Platform-specific configuration for development
    os_specific: [
      macos: [
        include_erts: true,
        extra_steps: [],
        config: [
          # MacOS-specific configuration values 
          strip: false,
          executable: "raxol_dev",
          identifier: "io.github.hydepwns.raxol-dev",
          signing_identity: nil # No signing for dev builds
        ]
      ],
      linux: [
        include_erts: true,
        extra_steps: [],
        config: [
          # Linux-specific configuration values
          strip: false,
          executable: "raxol_dev",
          compressed: false
        ]
      ],
      windows: [
        include_erts: true,
        extra_steps: [],
        config: [
          # Windows-specific configuration values
          executable: "raxol_dev.exe",
          console_app: true # Shows console window for development
        ]
      ]
    ]
  ],
  
  # Production profile
  prod: [
    steps: [
      # Steps for production building with optimizations
      :download_burrito_packages,
      :copy_beam_files,
      :copy_runtime_files,
      :make_boot_script,
      :configure_cuttlefish,
      :compress_release
    ],
    output_dir: "prod",
    # Platform-specific configuration for production
    os_specific: [
      macos: [
        include_erts: true,
        extra_steps: [:build_dmg],
        config: [
          # MacOS-specific configuration values for production
          strip: true,
          executable: "raxol",
          identifier: "io.github.hydepwns.raxol",
          signing_identity: "Developer ID Application", # Will be used if available
          notarize: true # Notarize app for distribution (requires valid credentials)
        ]
      ],
      linux: [
        include_erts: true,
        extra_steps: [:build_deb, :build_rpm],
        config: [
          # Linux-specific configuration values for production
          strip: true,
          executable: "raxol",
          compressed: true,
          # Packaging information for Linux distributions
          deb: [
            vendor: "Raxol",
            maintainer: "Hydepwns <drew@axol.io>",
            homepage: "https://github.com/hydepwns/raxol",
            categories: ["Development", "Terminal", "UI"]
          ],
          rpm: [
            vendor: "Raxol",
            license: "MIT",
            url: "https://github.com/hydepwns/raxol"
          ]
        ]
      ],
      windows: [
        include_erts: true,
        extra_steps: [:build_installer],
        config: [
          # Windows-specific configuration values for production
          executable: "raxol.exe",
          console_app: false, # Hide console window for production builds
          # Installer configuration
          inno_setup: [
            app_name: "Raxol",
            app_version: Mix.Project.config()[:version],
            publisher: "Hydepwns",
            setup_icon_file: "assets/icons/raxol.ico",
            gui_app: true
          ]
        ]
      ]
    ]
  ] 