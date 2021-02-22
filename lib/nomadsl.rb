#!/usr/bin/env ruby

require 'json'

ARTIFACTS = {}

module Nomadsl
  def die(err)
    raise err
  end

  def nomadsl_print(b)
    @nomadsl_print = b
  end

  def only(*levels)
    unless levels.include? @stack.last
      loc = caller_locations(1,1)[0]
      die "Bad syntax on line #{loc.lineno}! '#{loc.label}' can only appear in #{levels.collect{|x| "'#{x}'" }.join(', ')}"
    end
  end

  #################################################################
  # rendering methods

  def str!(k, v)
    die "Value for '#{k}' is nil" if v.nil?
    str(k, v)
  end

  def str(k, v)
    render "#{k} = #{v.to_s.to_json}" unless v.nil?
  end

  def list!(k, v)
    die "Value for '#{k}' is nil" if v.nil?
    list(k, v)
  end

  def list(k, v)
    render "#{k} = #{[v].flatten.to_json}" unless v.nil?
  end

  def int!(k, v)
    die "Value for '#{k}' is nil" if v.nil?
    int(k, v)
  end

  def int(k, v)
    render "#{k} = #{v.to_i}" unless v.nil?
  end

  def bool!(k, v)
    die "Value for '#{k}' is nil" if v.nil?
    bool(k, v)
  end

  def bool(k, v)
    render "#{k} = #{v ? true : false}" unless v.nil?
  end

  def blob!(k, v)
    die "Value for '#{k}' is nil" if v.nil?
    blob(k, v)
  end

  def blob(k, v)
    render "#{k} = <<BLOB"
    @out << "#{v.chomp}\nBLOB\n"
  end

  def strmap!(k, v)
    die "Value for '#{k}' is nil" if v.nil?
    strmap(k, v)
  end

  def strmap(k, v)
    if v
      block(k) do
        v.each do |k2,v2|
          str k2, v2
        end
      end
    end
  end

  # try really hard
  def any(k, v)
    if v.nil?
      return
    elsif v.is_a? Array
      list k, v
    elsif v.is_a? Integer
      int k, v
    elsif v.is_a? TrueClass or v.is_a? FalseClass
      bool k, v
    elsif v.is_a? String
      if v.to_i.to_s == v
        int k, v
      else
        str k, v
      end
    elsif v.is_a? Hash
      block(k) do
        v.each do |k, v|
          any k, v
        end
      end
    else
      die "An unexpected type was encountered."
    end
  end

  def render(s)
    @first = false
    @out << "#{'  '*@indent}#{s}\n"
  end

  def block(t, n=nil)
    unless @first
      @out << "\n"
    end

    render(n ? "#{t} #{n.to_json} {" : "#{t} {")

    if block_given?
      @stack.push t
      @first = true
      @indent += 1
      yield
      @indent -= 1
      @first = false
      @stack.pop
    end
    render "}"
  end

  ################################################
  # real stuff
  # https://www.nomadproject.io/docs/job-specification/

  # https://www.nomadproject.io/docs/job-specification/job.html#all_at_once
  def all_at_once(v)
    only :job
    bool :all_at_once, v
  end

  # https://www.nomadproject.io/docs/job-specification/artifact.html
  def artifact(source:, destination: nil, mode: nil, options: nil)
    only :task
    block(:artifact) do
      str! :source, source
      str :destination, destination
      str :mode, mode
      strmap :options, options
    end
  end

  # https://www.nomadproject.io/docs/job-specification/affinity.html
  def affinity(attribute: nil, operator: nil, value: nil, weight: nil)
    only :job, :group, :task, :device
    block(:affinity) do
      str! :attribute, attribute
      str :operator, operator
      str! :value, value
      int :weight, weight
    end
  end

  # https://www.nomadproject.io/docs/job-specification/service.html#check-parameters
  def check(address_mode: nil, args: nil, command: nil, grpc_service: nil, grpc_use_tls: nil, initial_status: nil, interval: nil, method: nil, name: nil, path: nil, port: nil, protocol: nil, timeout: nil, type: nil, tls_skip_verify: nil)
    only :service
    block(:check) do
      str :address_mode, address_mode
      list :args, args
      str :command, command
      str :grpc_service, grpc_service
      bool :grpc_use_tls, grpc_use_tls
      str :initial_status, initial_status
      str :interval, interval
      str :method, method
      str :name, name
      str :path, path
      str :port, port
      str :protocol, protocol
      str :timeout, timeout
      str :type, type
      bool :tls_skip_verify, tls_skip_verify
      yield if block_given?
    end
  end

  # https://www.nomadproject.io/docs/job-specification/check_restart.html
  def check_restart(limit: nil, grace: nil, ignore_warnings: nil)
    only :service, :check
    block(:check_restart) do
      int :limit, limit
      str :grace, grace
      bool :ignore_warnings, ignore_warnings
    end
  end

  # https://www.nomadproject.io/docs/job-specification/task.html#config
  def config(**opts)
    only :task
    config_method = "__config_#{@driver}".to_sym
    if private_methods.include?(config_method)
      send(config_method, **opts)
    else
      # try to wing it
      block(:config) do
        opts.each do |k,v|
          any k, v
        end
      end
    end
  end

  def __config_exec(command:, args: nil)
    only :task
    block(:config) do
      str! :command, command
      list :args, args
    end
  end


  # https://www.nomadproject.io/docs/job-specification/constraint.html
  def constraint(attribute: nil, operator: nil, value: nil)
    only :job, :group, :task, :device
    block(:constraint) do
      str :attribute, attribute
      str :operator, operator
      str :value, value
    end
  end

  # https://www.nomadproject.io/docs/job-specification/job.html#datacenters
  def datacenters(*d)
    only :job
    list! :datacenters, d
  end

  # https://www.nomadproject.io/docs/job-specification/device.html
  def device(name: nil, count: nil)
    only :resources
    block(:device, name) do
      int :count, count
      yield if block_given?
    end
  end

  # https://www.nomadproject.io/docs/job-specification/dispatch_payload.html
  def dispatch_payload(file:)
    only :task
    block(:dispatch_payload) do
      str! :file, file
    end
  end

  # https://www.nomadproject.io/docs/job-specification/env.html
  def env(**opts)
    only :task
    strmap :env, opts
  end

  # https://www.nomadproject.io/docs/job-specification/ephemeral_disk.html
  def ephemeral_disk(migrate: nil, size: nil, sticky: nil)
    only :group
    block(:ephemeral_disk) do
      bool :migrate, migrate
      int :size, size
      bool :sticky, sticky
    end
  end

  # https://www.nomadproject.io/docs/job-specification/group.html
  def group(name, count: nil)
    only :job
    block(:group, name) do
      int :count, count
      yield
    end
  end

  # https://www.nomadproject.io/docs/job-specification/service.html#header-stanza
  def header(name, values)
    only :check
    block(:header) do
      list! name, values
    end
  end

  # https://www.nomadproject.io/docs/job-specification/job.html
  def job(j)
    # initialize the variables since this is the actual root
    @out = ""
    @indent = 0
    @first = true
    @stack = [:root]

    only :root
    result = block(:job, j) { yield }
    if @nomadsl_print
      puts result
    end
    result
  end

  # https://www.nomadproject.io/docs/job-specification/logs.html
  def logs(max_files: nil, max_file_size: nil)
    only :task
    block(:logs) do
      int :max_files, max_files
      int :max_file_size, max_file_size
    end
  end

  # https://www.nomadproject.io/docs/job-specification/meta.html
  def meta(**opts)
    only :job, :group, :task
    strmap :meta, opts
  end

  # https://www.nomadproject.io/docs/job-specification/migrate.html
  def migrate(max_parallel: nil, health_check: nil, min_healthy_time: nil, healthy_deadline: nil)
    only :job, :group
    block(:migrate) do
      int :max_parallel, max_parallel
      str :health_check, health_check
      str :min_healthy_time, min_healthy_time
      str :healthy_deadline, healthy_deadline
    end
  end

  # https://www.nomadproject.io/docs/job-specification/job.html#namespace
  # Supported by Nomad Enterprise ONLY
  def namespace(n)
    only :job
    str! :namespace, n
  end

  # https://www.nomadproject.io/docs/job-specification/network.html
  def network(mbits: nil)
    only :resources
    block(:network) do
      int :mbits, mbits
      yield if block_given?
    end
  end

  # https://www.nomadproject.io/docs/job-specification/parameterized.html
  def parameterized(payload: "optional", meta_optional: nil, meta_required: nil)
    only :job
    die "Bad option for parameterized.payload: '#{payload}'" unless %w( optional required forbidden ).include?(payload)
    block :parameterized do
      str! :payload, payload
      list :meta_optional, meta_optional
      list :meta_required, meta_required
    end
  end

  # https://www.nomadproject.io/docs/job-specification/periodic.html
  def periodic(cron: nil, prohibit_overlap: nil, time_zone: nil)
    only :job
    block(:periodic) do
      str :cron, cron
      bool :prohibit_overlap, prohibit_overlap
      str :time_zone, time_zone
    end
  end

  # https://www.nomadproject.io/docs/job-specification/network.html#port
  def port(n, static: nil)
    only :network
    if static
      block(:port, n) do
        int :static, static
      end
    else
      render "port #{n.to_json} {}"
    end
  end

  # https://www.nomadproject.io/docs/job-specification/job.html#priority
  def priority(p)
    only :job
    int! :priority, p
  end

  # https://www.nomadproject.io/docs/job-specification/job.html#region
  def region(r)
    only :job
    str! :region, r
  end

  # https://www.nomadproject.io/docs/job-specification/reschedule.html
  def reschedule(attempts: nil, interval: nil, delay: nil, delay_function: nil, max_delay: nil, unlimited: nil)
    only :job, :group
    block(:reschedule) do
      int :attempts, attempts
      str :interval, interval
      str :delay, delay
      str :delay_function, delay_function
      str :max_delay, max_delay
      bool :unlimited, unlimited
    end
  end

  # https://www.nomadproject.io/docs/job-specification/resources.html
  def resources(cpu: nil, iops: nil, memory: nil)
    only :task
    block(:resources) do
      int :cpu, cpu
      int :iops, iops
      int :memory, memory
      yield if block_given?
    end
  end

  # https://www.nomadproject.io/docs/job-specification/restart.html
  def restart(attempts: nil, delay: nil, interval: nil, mode: nil)
    only :group
    block(:restart)do
      int :attempts, attempts
      str :delay, delay
      str :interval, interval
      str :mode, mode
    end
  end

  # https://www.nomadproject.io/docs/job-specification/service.html
  def service(address_mode: nil, canary_tags: nil, name: nil, port: nil, tags: nil)
    only :task
    block(:service) do
      str :address_mode, address_mode
      list :canary_tags, canary_tags
      str :name, name
      str :port, port
      list :tags, tags
      yield if block_given?
    end
  end

  # https://www.nomadproject.io/docs/job-specification/spread.html
  def spread(attribute: nil, weight: nil)
    only :job, :group, :task
    block(:spread) do
      str! :attribute, attribute
      int :weight, weight
      yield if block_given?
    end
  end

  # https://www.nomadproject.io/docs/job-specification/spread.html#target-parameters
  def target(name: nil, value: nil, percent: nil)
    only :spread
    block(:target, name) do
      str :value, value
      str :weight, weight
    end
  end

  # https://www.nomadproject.io/docs/job-specification/task.html
  def task(t, driver: "exec", kill_signal: nil, kill_timeout: nil, leader: nil, shutdown_delay: nil, user: nil)
    only :group
    @driver = driver
    block(:task, t) do
      str :driver, driver
      str :kill_signal, kill_signal
      str :kill_timeout, kill_timeout
      bool :leader, leader
      str :shutdown_delay, shutdown_delay
      str :user, user
      yield
    end
  end

  # https://www.nomadproject.io/docs/job-specification/template.html
  def template(change_mode: nil, change_signal: nil, data: nil, destination:, env: nil, left_delimiter: nil, perms: nil, right_delimiter: nil, source: nil, splay: nil, vault_grace: nil)
    only :task
    block(:template) do
      str :change_mode, change_mode
      str :change_signal, change_signal
      str! :destination, destination
      blob :data, data
      bool :env, env
      str :left_delimiter, left_delimiter
      str :perms, perms
      str :right_delimiter, right_delimiter
      str :source, source
      str :splay, splay
      str :vault_grace, vault_grace
    end
  end

  # https://www.nomadproject.io/docs/job-specification/job.html#type
  def type(t)
    only :job
    die "Bad job type '#{t}'" unless %w( batch service system ).include?(t)
    str! :type, t
  end

  # https://www.nomadproject.io/docs/job-specification/update.html
  def update(max_parallel: nil, health_check: nil, min_healthy_time: nil, healthy_deadline: nil, progress_deadline: nil, auto_revert: nil, canary: nil, stagger: nil)
    only :job, :group
    block(:update) do
      int :max_parallel, max_parallel
      str :health_check, health_check
      str :min_healthy_time, min_healthy_time
      str :healthy_deadline, healthy_deadline
      str :progress_deadline, progress_deadline
      bool :auto_revert, auto_revert
      int :canary, canary
      str :stagger, stagger
    end
  end

  # https://www.nomadproject.io/docs/job-specification/vault.html
  def vault(change_mode: nil, change_token: nil, env: nil, policies: nil)
    only :job, :group, :task
    block(:vault) do
      str :change_mode, change_mode
      str :change_token, change_token
      bool :env, env
      list :policies, policies
    end
  end

  # https://www.nomadproject.io/docs/job-specification/job.html#vault_token
  # NOTE: explicitly unsupported, dangerous


  ########################################################
  # shortcuts

  def package(id)
    if pkg = ARTIFACTS[id.to_sym]
      artifact(**pkg)
    else
      die "Unknown package ID '#{id}'"
    end
  end

  def _vault_aws_creds(path, export)
    prefix = export ? "export " : ""
    path = path.is_a?(String) ? [path] : path
    args = path.reduce("") do |concat, str|
      concat = "#{concat} \"#{str}\""
    end
    <<~DATA
      {{with secret #{args}}}
      #{prefix}AWS_ACCESS_KEY_ID={{.Data.access_key}}
      #{prefix}AWS_SECRET_ACCESS_KEY={{.Data.secret_key}}
      {{if .Data.security_token}}
      #{prefix}AWS_SESSION_TOKEN={{.Data.security_token}}
      {{end}}
      {{end}}
    DATA
  end

  def preloaded_vault_aws_creds(name, path)
    template(data: _vault_aws_creds(path, false), destination: "secrets/#{name}.env", env: true)
  end

  def vault_aws_creds(name, path)
    template(data: _vault_aws_creds(path, true), destination: "secrets/#{name}.env")
  end

  def _vault_consul_creds(path, export)
    prefix = export ? "export " : ""
    path = path.is_a?(String) ? [path] : path
    args = path.reduce("") do |concat, str|
      concat = "#{concat} \"#{str}\""
    end
    <<~DATA
      {{with secret #{args}}}
      #{prefix}CONSUL_HTTP_TOKEN={{.Data.token}}
      {{end}}
    DATA
  end

  def preloaded_vault_consul_creds(name, path)
    template(data: _vault_consul_creds(path, false), destination: "secrets/#{name}.env", env: true)
  end

  def vault_consul_creds(name, path)
    template(data: _vault_consul_creds(path, true), destination: "secrets/#{name}.env")
  end
end
