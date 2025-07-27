use Mix.Config

# Base steps for all builds
@base_steps [
  :download_burrito_packages,
  :copy_beam_files,
  :copy_runtime_files,
  :make_boot_script,
  :configure_cuttlefish
]

# Common platform configurations
@common_config [
  include_erts: true,
  identifier: "io.github.hydepwns.raxol"
]

# Package metadata for distribution
@package_meta [
  vendor: "Raxol",
  maintainer: "Hydepwns <drew@axol.io>",
  homepage: "https://github.com/hydepwns/raxol",
  license: "MIT"
]

config :burrito,
  app_name: "raxol",
  base_output_dir: "burrito_out",

  # Development profile - optimized for speed
  dev: [
    steps: @base_steps,
    output_dir: "dev",
    os_specific: [
      macos:
        @common_config ++
          [
            config: [
              executable: "raxol_dev",
              strip: false,
              signing_identity: nil
            ]
          ],
      linux:
        @common_config ++
          [
            config: [
              executable: "raxol_dev",
              strip: false,
              compressed: false
            ]
          ],
      windows:
        @common_config ++
          [
            config: [
              executable: "raxol_dev.exe",
              console_app: true
            ]
          ]
    ]
  ],

  # Production profile - optimized for distribution
  prod: [
    steps: @base_steps ++ [:compress_release],
    output_dir: "prod",
    os_specific: [
      macos:
        @common_config ++
          [
            extra_steps: [:build_dmg],
            config: [
              executable: "raxol",
              strip: true,
              signing_identity: "Developer ID Application",
              notarize: true
            ]
          ],
      linux:
        @common_config ++
          [
            extra_steps: [:build_deb, :build_rpm],
            config: [
              executable: "raxol",
              strip: true,
              compressed: true,
              deb:
                @package_meta ++ [categories: ["Development", "Terminal", "UI"]],
              rpm: @package_meta
            ]
          ],
      windows:
        @common_config ++
          [
            extra_steps: [:build_installer],
            config: [
              executable: "raxol.exe",
              console_app: false,
              inno_setup: [
                app_name: "Raxol",
                app_version: Mix.Project.config()[:version],
                publisher: "Hydepwns",
                setup_icon_file: "@static/icons/raxol.ico",
                gui_app: true
              ]
            ]
          ]
    ]
  ]
