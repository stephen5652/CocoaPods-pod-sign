#!/usr/bin/env ruby
require 'cocoapods-pod-sign/pod_sign_storage'

module Pod
  class Installer

    alias_method :origin_run_podfile_post_install_hook, :run_podfile_post_install_hook
    def run_podfile_post_install_hook

      storage = PodSignStorage.instance

      pod_sign_extract_team_id_from_user_project if storage.configurations.empty? && !storage.skip_sign

      targets = if installation_options.generate_multiple_pod_projects
                  pod_target_subprojects.flat_map { |p| p.targets }
                else
                  pods_project.targets
                end
      targets.each do |target|
        next unless target.respond_to?('product_type') && target.product_type == 'com.apple.product-type.bundle'

        target.build_configurations.each do |config|
          config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "org.cocoapods.${PRODUCT_NAME}"
          config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ""
          config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
          config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
        end
      end

      origin_run_podfile_post_install_hook
      true
    end

    private

    def pod_sign_extract_team_id_from_user_project
      puts("YKHooke pod install")
      target = aggregate_targets.first.user_project.root_object.targets.first
      target&.build_configurations&.each do |config|
          xcconfig_hash ||=
            if config.base_configuration_reference&.real_path&.exist?
              Xcodeproj::Config.new(config.base_configuration_reference.real_path).to_hash
            else
              {}
            end
          pod_sign_extract_team_id(xcconfig_hash, config.name)
          pod_sign_extract_team_id(config.build_settings, config.name)
        end
    end

    def pod_sign_extract_team_id(build_settings, config_name)
      team_id = build_settings['DEVELOPMENT_TEAM']
      sign_style = build_settings['CODE_SIGN_STYLE']
      sign_identity = build_settings['CODE_SIGN_IDENTITY']
      return unless team_id && config_name

      storage = PodSignStorage.instance
      storage.configurations[config_name] = { team_id: team_id,
                                              sign_style: sign_style,
                                              sign_identity: sign_identity }

    end
  end
end
