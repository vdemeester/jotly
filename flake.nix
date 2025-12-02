{
  description = "Jotly - Android Journaling App";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    git-hooks,
    android-nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      perSystem = {
        config,
        pkgs,
        system,
        ...
      }: let
        android-sdk = android-nixpkgs.sdk.${system} (sdkPkgs:
          with sdkPkgs; [
            cmdline-tools-latest
            build-tools-34-0-0
            platform-tools
            platforms-android-34
            emulator
          ]);

        # ktlint editorconfig for Compose
        ktlintEditorconfig = pkgs.writeText "ktlint.editorconfig" ''
          root = true

          [*.{kt,kts}]
          ktlint_function_naming_ignore_when_annotated_with = Composable
        '';
      in {
        # Configure pre-commit hooks
        checks = {
          pre-commit-check = git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              # Kotlin linting
              ktlint = {
                enable = true;
                name = "ktlint";
                entry = "${pkgs.ktlint}/bin/ktlint --editorconfig=${ktlintEditorconfig} --format";
                files = "\\.(kt|kts)$";
                language = "system";
              };
              # Nix formatting
              alejandra.enable = true;
            };
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Java Development Kit
            jdk17

            # Kotlin
            kotlin
            ktlint

            # Gradle
            gradle

            # Android SDK and tools
            android-sdk

            # Additional development tools
            git

            # For Nix formatting
            alejandra
          ];

          # Environment variables for Android development
          ANDROID_HOME = "${android-sdk}/share/android-sdk";
          ANDROID_SDK_ROOT = "${android-sdk}/share/android-sdk";
          JAVA_HOME = "${pkgs.jdk17}";

          # Add Android tools to PATH and setup pre-commit hooks
          shellHook = ''
            export PATH="${android-sdk}/bin:$PATH"
            echo "🚀 Jotly development environment loaded"
            echo "📱 Android SDK: $ANDROID_SDK_ROOT"
            echo "☕ Java: $JAVA_HOME"
            echo ""
            echo "Available tools:"
            echo "  - gradle ($(gradle --version | head -n 1))"
            echo "  - adb (Android Debug Bridge)"
            echo "  - ktlint (Kotlin linter)"
            echo ""
            ${config.checks.pre-commit-check.shellHook}
          '';
        };

        formatter = pkgs.alejandra;
      };
    };
}
