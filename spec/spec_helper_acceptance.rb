require 'beaker-rspec/spec_helper'
require 'beaker-rspec/helpers/serverspec'

# Install Puppet on all Beaker hosts
unless ENV['BEAKER_provision'] == 'no'
  hosts.each do |host|
    # Install Puppet
    if host.is_pe?
      install_pe
    else
      install_puppet
    end
  end
end

RSpec.configure do |c|
  # Project root
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    # Install opendaylight module on any/all Beaker hosts
    # TODO: Should this be done in host.each loop?
    puppet_module_install(:source => proj_root, :module_name => 'opendaylight')
    hosts.each do |host|
      # Install stdlib, a dependency of the odl mod
      # TODO: Why is 1 an acceptable exit code?
      on host, puppet('module', 'install', 'puppetlabs-stdlib'), { :acceptable_exit_codes => [0,1] }
      # Install archive, a dependency of the odl mod use for tarball-type installs
      # TODO: I'd perfer not to use gini-archive. See:
      # https://github.com/dfarrell07/puppet-opendaylight/issues/52
      on host, puppet('module', 'install', 'gini-archive'), { :acceptable_exit_codes => [0] }
    end
  end
end

# Shared function that handles generic validations
# These should be common for all odl class param combos
def generic_validations()
  # TODO: It'd be nice to do this independently of install dir name
  describe file('/opt/opendaylight-0.2.2/') do
    it { should be_directory }
    it { should be_owned_by 'odl' }
    it { should be_grouped_into 'odl' }
    it { should be_mode '775' }
  end

  describe service('opendaylight') do
    it { should be_enabled }
    it { should be_enabled.with_level(3) }
    it { should be_running }
  end

  # OpenDaylight will appear as a Java process
  describe process('java') do
    it { should be_running }
  end

  # TODO: It'd be nice to do this independently of install dir name
  describe user('odl') do
    it { should exist }
    it { should belong_to_group 'odl' }
    it { should have_home_directory '/opt/opendaylight-0.2.2' }
  end

  describe file('/home/odl') do
    # Home dir shouldn't be created for odl user
    it { should_not be_directory }
  end

  describe file('/usr/lib/systemd/system/opendaylight.service') do
    it { should be_file }
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
    it { should be_mode '644' }
  end
end

# Shared function that validates Karaf config file
def karaf_config_validations(features)
  # TODO: It'd be nice to do this independently of install dir name
  describe file('/opt/opendaylight-0.2.2/etc/org.apache.karaf.features.cfg') do
    it { should be_file }
    it { should be_owned_by 'odl' }
    it { should be_grouped_into 'odl' }
    it { should be_mode '775' }
    its(:content) { should match /^featuresBoot=#{features.join(",")}/ }
  end
end

# Shared function that handles validations specific to RPM-type installs
def rpm_validations()
  describe yumrepo('opendaylight') do
    it { should exist }
    it { should be_enabled }
  end

  describe package('opendaylight') do
    it { should be_installed }
  end
end
