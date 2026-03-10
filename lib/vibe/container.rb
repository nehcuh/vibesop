# frozen_string_literal: true

require_relative "utils"
require_relative "errors"
require_relative "doc_rendering"
require_relative "native_configs"
require_relative "overlay_support"
require_relative "path_safety"
require_relative "target_renderers"
require_relative "external_tools"
require_relative "init_support"

module Vibe
  class Container
    attr_reader :repo_root

    def initialize(repo_root)
      @repo_root = repo_root
      @services = {}
      @yaml_mutex = Mutex.new
    end

    def utils
      @services[:utils] ||= Utils
    end

    def yaml_loader
      @services[:yaml_loader] ||= ->(path) { YAML.load_file(File.join(@repo_root, path)) }
    end

    def register(name, service)
      @services[name] = service
    end

    def resolve(name)
      @services[name] || raise(ConfigurationError, "Service #{name} not registered")
    end

    def registered?(name)
      @services.key?(name)
    end
  end
end
