require_relative 'kb8_utils'
require_relative 'replace_obj_vars'

class Context

  attr_reader :always_deploy,
              :container_version_finder,
              :deployment_home,
              :env_name,
              :settings,
              :vars,
              :overridden_vars

  include Methadone::Main
  include Methadone::CLILogging

  def initialize(settings,
                 container_version_finder,
                 deployment_home,
                 always_deploy=false,
                 env_name=nil,
                 vars=nil,
                 overridden_vars={})

    debug "Creating initial context..."
    @container_version_finder = container_version_finder
    @settings = settings
    @deployment_home = deployment_home
    @always_deploy = always_deploy
    @env_name = env_name || settings.default_env_name
    @vars = vars
    @overridden_vars = overridden_vars
    @environment_file = nil
  end

  # This is a method as we may need variables to find the environment file...
  def environment
    return @vars unless @vars.nil?

    # If not set, Try to find them...
    glob_path = File.join(@deployment_home, @settings.env_file_glob_path)
    regexp_find = glob_path.gsub(/\*/, '(.*)')
    Dir[glob_path].each do | file_name |
      # Get the environment name from the file part of the glob path:
      # e.g. given ./environments/ci_mgt/kb8or.yaml
      #      get ci_mgt from ./environments/*/kb8or.yaml
      /#{regexp_find}/.match(file_name)
      env_name = $1
      if env_name == @env_name
        debug "env=#{env_name}"
        # Ensure we set the defaults as vars BEFORE we add environment specifics:
        @vars = @settings.defaults
        env_vars = Context.resolve_env_file(file_name)
        @vars = @vars.merge(env_vars)
        @vars = @vars.merge(@overridden_vars)
        @vars['env'] = env_name
        @environment_file = file_name
        break
      end
    end
    # Now finaly, update the settings now we know the environment!
    unless @vars
      @vars = {}
    end
    @settings = @settings.new(@vars)
    update_k8context
    debug "vars=#{vars}"
    @vars
  end

  def update_k8context
    # Create a context directly if set here
    if @settings.kb8_context
      @settings.update({ 'kb8_context' => Kb8Context.new(@settings.kb8_context)})
    end

    # Set the namespace as a known variable
    unless @vars['namespace']
      # Create a context from a single string set in the environment
      if @settings.kb8_context && @settings.kb8_context['namespace']
        @vars['namespace'] = @settings.kb8_context['namespace']
      end
    end
  end

  def environment_file?
    # Resolve the environment and any variables...
    environment

    # Return true only if a file in use
    !@environment_file.nil?
  end

  def resolve_vars_in_file(file_path)
    data = Kb8Utils::load_yaml(file_path)
    resolve_vars(data)
  end

  def resolve_vars(data)
    ReplaceObjVars.new(environment, @deployment_home).replace(data)
  end

  def self.resolve_env_file(file_path)
    data = Kb8Utils::load_yaml(file_path)
    # Resolve any vars within the env file:
    vars_resolver = ReplaceObjVars.new(data, File.dirname(file_path))
    vars_resolver.replace(data)
  end

  def update_vars(vars)
    @vars = @vars.merge(vars)
  end

  def new_with_vars(vars)
    context = new(vars)
    context.update_vars(vars)
    context
  end

  def new(data)
    debug "Cloning new context..."
    context = Context.new(@settings.new(data),
                          @container_version_finder,
                          @deployment_home,
                          @always_deploy,
                          @env_name,
                          @vars,
                          @overridden_vars)
    # Update vars from settings:
    context.update_vars(@settings.settings_as_vars)
    context
  end
end
