# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'log4r'
require 'yaml'

# configs, custom updates _defaults
@logger = Log4r::Logger.new("vagrant::docker::driver")
defaults_cfg = YAML.load_file('vagrant-settings.yaml_defaults')
if File.exist?('vagrant-settings.yaml')
  custom_cfg = YAML.load_file('vagrant-settings.yaml')
  cfg = defaults_cfg.merge(custom_cfg)
else
  cfg = defaults_cfg
end

IP24NET = ENV['IP24NET'] || cfg['ip24net']
DOCKER_IMAGE = ENV['DOCKER_IMAGE'] || cfg['docker_image']
DOCKER_CMD = ENV['DOCKER_CMD'] || cfg['docker_cmd']
DOCKER_MOUNTS = ENV['DOCKER_MOUNTS'] || cfg['docker_mounts']
DOCKER_DRIVER = ENV['DOCKER_DRIVER'] || cfg['docker_driver']
OCF_RA_PROVIDER = ENV['OCF_RA_PROVIDER'] || cfg['ocf_ra_provider']
OCF_RA_PATH = ENV['OCF_RA_PATH'] || cfg['ocf_ra_path']
UPLOAD_METHOD = ENV['UPLOAD_METHOD'] || cfg['upload_method']
SMOKETEST_WAIT = ENV['SMOKETEST_WAIT'] || cfg['smoketest_wait']
GALERA_DISTRO = ENV['GALERA_DISTRO'] || cfg['galera_distro']
WSREP_SST_METHOD = ENV['WSREP_SST_METHOD'] || cfg['wsrep_sst_method']
XTRA_VER = ENV['XTRA_VER'] || cfg['xtra_ver']
USE_JEPSEN = ENV['USE_JEPSEN'] || cfg['use_jepsen']
JEPSEN_APP = ENV['JEPSEN_APP'] || cfg['jepsen_app']
JEPSEN_TESTCASE = ENV['JEPSEN_TESTCASE'] ||cfg['jepsen_testcase']
QUIET = ENV['QUIET'] || cfg['quiet']
STORAGE= ENV['STORAGE'] || cfg['storage']
NODES=ENV['NODES'] || cfg['nodes'] || 'n1 n2 n3 n4 n5'
if USE_JEPSEN == "true"
  SLAVES_COUNT = NODES.split(' ').length - 1
  CPU = ENV['CPU'] || (1000 / (SLAVES_COUNT + 1) rescue 200)
  MEM = ENV['MEMORY'] || '256M'
else
  SLAVES_COUNT = (ENV['SLAVES_COUNT'] || cfg['slaves_count']).to_i
  CPU = ENV['CPU'] || cfg['cpu']
  MEM = ENV['MEMORY'] || cfg['memory']
end
if QUIET == "true"
  REDIRECT=">/dev/null 2>&1"
else
  REDIRECT="2>&1"
end

def shell_script(filename, env=[], args=[], redirect=REDIRECT)
  shell_script_crafted = "/bin/bash -c \"#{env.join ' '} #{filename} #{args.join ' '} #{redirect}\""
  @logger.info("Crafted shell-script: #{shell_script_crafted})")
  shell_script_crafted
end

# W/a unimplemented docker-exec, see https://github.com/mitchellh/vagrant/issues/4179
# Use docker exec instead of the SSH provisioners
def docker_exec (name, script)
  @logger.info("Executing docker-exec at #{name}: #{script}")
  system "docker exec -it #{name} #{script}"
end

# Render a pacemaker primitive configuration with a seed node n1
corosync_setup = shell_script("/vagrant/vagrant_script/conf_corosync.sh", ["CNT=#{SLAVES_COUNT+1}"])
primitive_setup = shell_script("/vagrant/vagrant_script/conf_primitive.sh",
  ["SEED=n1", "STORAGE='#{STORAGE}'", "SST_METHOD=#{WSREP_SST_METHOD}"])
ra_ocf_setup = shell_script("/vagrant/vagrant_script/conf_ra_ocf.sh",
  ["UPLOAD_METHOD='#{UPLOAD_METHOD}'", "OCF_RA_PATH='#{OCF_RA_PATH}'",
   "OCF_RA_PROVIDER='#{OCF_RA_PROVIDER}'", "STORAGE='#{STORAGE}'"])

case GALERA_DISTRO
when "percona"
  galera_install = shell_script("/vagrant/vagrant_script/mysql_install2.sh",
  ["XTRA_VER='#{XTRA_VER}'"])
when "codership"
  galera_install = shell_script("/vagrant/vagrant_script/mysql_install.sh")
  raise if WSREP_SST_METHOD != 'mysqldump'
when "mariadb"
  galera_install = shell_script("/vagrant/vagrant_script/mysql_install3.sh",
  ["XTRA_VER='#{XTRA_VER}'"])
else
  raise "Distro #{GALERA_DISTRO} is not supported"
end

galera_conf_setup = shell_script("cp /vagrant/conf/my.cnf /etc/mysql/")
wsrep_init_setup = shell_script("cp /vagrant/conf/wsrep-init-file /tmp/")
conf_wsrep = shell_script("/vagrant/vagrant_script/conf_cluster.sh", [],
  [SLAVES_COUNT+1, WSREP_SST_METHOD])

# Setup docker dropins, lein, jepsen and hosts/ssh access for it
jepsen_setup = shell_script("/vagrant/vagrant_script/conf_jepsen.sh")
docker_dropins = shell_script("/vagrant/vagrant_script/conf_docker_dropins.sh",
  ["DOCKER_DRIVER=#{DOCKER_DRIVER}"])
lein_test = shell_script("/vagrant/vagrant_script/lein_test.sh", ["PURGE=true", "NODES='#{NODES}'"],
  [JEPSEN_APP, JEPSEN_TESTCASE], "1>&2")
ssh_setup = shell_script("/vagrant/vagrant_script/conf_ssh.sh",[], [SLAVES_COUNT+1], "1>&2")
root_login = shell_script("/vagrant/vagrant_script/conf_root_login.sh")
entries = "'#{IP24NET}.2 n1'"
SLAVES_COUNT.times do |i|
  index = i + 2
  ip_ind = i + 3
  entries += " '#{IP24NET}.#{ip_ind} n#{index}'"
end
hosts_setup = shell_script("/vagrant/vagrant_script/conf_hosts.sh", [], [entries])

db_test_remote = shell_script("/vagrant/vagrant_script/test_dbcluster.sh",
  ["WAIT=#{SMOKETEST_WAIT}"], [SLAVES_COUNT+1, "n1"], "1>&2")
db_test = shell_script("/vagrant/vagrant_script/test_dbcluster.sh",
  ["WAIT=#{SMOKETEST_WAIT}"], [SLAVES_COUNT+1], "1>&2")

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # W/a unimplemented docker networking, see
  # https://github.com/mitchellh/vagrant/issues/6667.
  # Create or delete the vagrant net (depends on the vagrant action)
  config.trigger.before :up do
    system <<-SCRIPT
    if ! docker network inspect "vagrant-#{OCF_RA_PROVIDER}" >/dev/null 2>&1 ; then
      docker network create -d bridge \
        -o "com.docker.network.bridge.enable_icc"="true" \
        -o "com.docker.network.bridge.enable_ip_masquerade"="true" \
        -o "com.docker.network.driver.mtu"="1500" \
        --gateway=#{IP24NET}.1 \
        --ip-range=#{IP24NET}.0/24 \
        --subnet=#{IP24NET}.0/24 \
        "vagrant-#{OCF_RA_PROVIDER}" >/dev/null 2>&1
    fi
    SCRIPT
  end
  config.trigger.after :destroy do
    system <<-SCRIPT
    docker network rm "vagrant-#{OCF_RA_PROVIDER}" >/dev/null 2>&1
    SCRIPT
  end

  config.vm.provider :docker do |d, override|
    d.image = DOCKER_IMAGE
    d.remains_running = false
    d.has_ssh = false
    d.cmd = DOCKER_CMD.split(' ')
  end

  # Prepare docker volumes for nested containers
  docker_volumes = []
  if DOCKER_MOUNTS != 'none'
    if DOCKER_MOUNTS.kind_of?(Array)
      mounts = DOCKER_MOUNTS
    else
      mounts = DOCKER_MOUNTS.split(" ")
    end
    mounts.each do |m|
      next if m == "-v"
      docker_volumes << [ "-v", m ]
    end
  end

  # A Jepsen only case, set up a contol node
  if USE_JEPSEN == "true"
    config.vm.define "n0", primary: true do |config|
      docker_volumes << [ "-v", "/sys/fs/cgroup:/sys/fs/cgroup",
        "-v", "/usr/bin/docker:/usr/bin/docker:ro",
        "-v", "/var/run/docker.sock:/var/run/docker.sock" ]
      config.vm.host_name = "n0"
      config.vm.provider :docker do |d, override|
        d.name = "n0"
        d.create_args = [ "--stop-signal=SIGKILL", "-i", "-t", "--privileged", "--ip=#{IP24NET}.254",
          "--memory=#{MEM}", "--cpu-shares=#{CPU}",
          "--net=vagrant-#{OCF_RA_PROVIDER}", docker_volumes].flatten
      end
      config.trigger.after :up, :option => { :vm => 'n0' } do
        docker_exec("n0","#{jepsen_setup}")
        docker_exec("n0","#{hosts_setup}")
        docker_exec("n0","#{ssh_setup}")
        # Wait and run a smoke test against a cluster, shall not fail
        docker_exec("n0","#{db_test_remote}") or raise "Smoke test: FAILED to assemble a cluster"
        # Then run all of the jepsen tests for the given app, and it *may* fail
        docker_exec("n0","#{docker_dropins}")
        docker_exec("n0","#{lein_test}")
        # Verify if the cluster was recovered
        docker_exec("n0","#{db_test_remote}")
      end
    end
  end

  # Any conf tasks to be executed for all nodes should be added here as well
  COMMON_TASKS = [root_login, ssh_setup, corosync_setup, galera_install, ra_ocf_setup,
    galera_conf_setup, wsrep_init_setup, primitive_setup, conf_wsrep]

  config.vm.define "n1", primary: true do |config|
    config.vm.host_name = "n1"
    config.vm.provider :docker do |d, override|
      d.name = "n1"
      d.create_args = [ "--stop-signal=SIGKILL", "-i", "-t", "--cap-add=NET_ADMIN",
        "--memory=#{MEM}", "--cpu-shares=#{CPU}",
        "--ip=#{IP24NET}.2", "--net=vagrant-#{OCF_RA_PROVIDER}", docker_volumes].flatten
    end
    config.trigger.after :up, :option => { :vm => 'n1' } do
      docker_exec("n1","/usr/sbin/rsyslogd")
      docker_exec("n1","/usr/sbin/sshd")
      COMMON_TASKS.each { |s| docker_exec("n1","#{s}") }
      # Wait and run a smoke test against a cluster, shall not fail
      docker_exec("n1","#{db_test}")
    end
  end

  SLAVES_COUNT.times do |i|
    index = i + 2
    ip_ind = i + 3
    raise if ip_ind > 254
    config.vm.define "n#{index}" do |config|
      config.vm.host_name = "n#{index}"
      config.vm.provider :docker do |d, override|
        d.name = "n#{index}"
        d.create_args = ["--stop-signal=SIGKILL", "-i", "-t", "--cap-add=NET_ADMIN",
          "--memory=#{MEM}", "--cpu-shares=#{CPU}",
          "--ip=#{IP24NET}.#{ip_ind}", "--net=vagrant-#{OCF_RA_PROVIDER}", docker_volumes].flatten
      end
      config.trigger.after :up, :option => { :vm => "n#{index}" } do
        docker_exec("n#{index}","/usr/sbin/rsyslogd")
        docker_exec("n#{index}","/usr/sbin/sshd")
        COMMON_TASKS.each { |s| docker_exec("n#{index}","#{s}") }
        # Wait and run a smoke test against a cluster, shall not fail
        docker_exec("n#{index}","#{db_test}") unless USE_JEPSEN == "true"
      end
    end
  end
end
