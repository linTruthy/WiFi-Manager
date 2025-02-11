{ pkgs, ... }: {
  packages = [
    pkgs.jdk17
  ];
  
  env = {
    JAVA_HOME = "${pkgs.jdk17}/lib/openjdk";
  };

  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];
    workspace = {
      onCreate = {
        setup-android = ''
          # Create Android SDK directory
          mkdir -p /home/user/android-sdk/cmdline-tools

          # Download command line tools
          wget https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip -O cmdline-tools.zip
          
          # Unzip to the correct location
          unzip -q cmdline-tools.zip
          mv cmdline-tools /home/user/android-sdk/cmdline-tools/latest
          rm cmdline-tools.zip

          # Add to PATH
          export PATH="/home/user/android-sdk/cmdline-tools/latest/bin:$PATH"
          
          # Set ANDROID_HOME
          export ANDROID_HOME="/home/user/android-sdk"
        '';
        build-flutter = ''
          cd /home/user/myapp/android

          # Accept licenses after tools are installed
          yes | sdkmanager --licenses || true

          ./gradlew \
            --parallel \
            -Pverbose=true \
            -Ptarget-platform=android-x86 \
            -Ptarget=/home/user/myapp/lib/main.dart \
            -Pbase-application-name=android.app.Application \
            -Pdart-defines=RkxVVFRFUl9XRUJfQ0FOVkFTS0lUX1VSTD1odHRwczovL3d3dy5nc3RhdGljLmNvbS9mbHV0dGVyLWNhbnZhc2tpdC85NzU1MDkwN2I3MGY0ZjNiMzI4YjZjMTYwMGRmMjFmYWMxYTE4ODlhLw== \
            -Pdart-obfuscation=false \
            -Ptrack-widget-creation=true \
            -Ptree-shake-icons=false \
            -Pfilesystem-scheme=org-dartlang-root \
            assembleDebug
        '';
      };
    };
    previews = {
      enable = true;
      previews = {
        android = {
          command = ["flutter" "run" "--machine" "-d" "android" "-d" "localhost:5555"];
          manager = "flutter";
        };
      };
    };
  };
}