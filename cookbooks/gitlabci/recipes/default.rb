%w(gcc checkinstall libcurl4-openssl-dev libreadline6-dev libc6-dev 
  libssl-dev libmysql++-dev make zlib1g-dev openssh-server git-core
  libyaml-dev postfix libpq-dev libicu-dev git vim imagemagick nginx apt
  libmysql-ruby libmysqlclient-dev).each do |name|
  package name
end

include_recipe "mysql::server"

app_path = "/home/#{node['app']['user']}/gitlab-ci"

######   MYSQL  #########
mysql_password = node[:mysql][:server_root_password]
mysql_user_name = node[:mysql][:user_name]
mysql_user_password = node[:mysql][:user_password]

execute "create MySQL user" do
  command "/usr/bin/mysql -u root -p#{mysql_password} -D mysql -r -B -N -e \"GRANT ALL PRIVILEGES ON *.* TO '#{mysql_user_name}'@'localhost' IDENTIFIED BY '#{mysql_user_password}' WITH GRANT OPTION;\""
  action :run
  not_if { `/usr/bin/mysql -u root -p#{mysql_password} -D mysql -r -B -N -e \"SELECT COUNT(*) FROM user where User='#{mysql_user_name}'"`.to_i == 1 }
end

execute "create database" do
  command "/usr/bin/mysql -u root -p#{mysql_password} -D mysql -r -B -N -e \"CREATE DATABASE IF NOT EXISTS gitlab_ci_production DEFAULT CHARACTER SET 'utf8' COLLATE 'utf8_unicode_ci';\""
  action :run
end

#######   NGINX   #######
directory "/etc/nginx/sites-available" do
  action :create
end

nginx_config_filename = node[:nginx][:config_filename]

template "/etc/nginx/sites-available/#{nginx_config_filename}" do
  source 'nginx.erb'
  variables(
    :app_path => app_path
  )
end

link "/etc/nginx/sites-enabled/#{nginx_config_filename}" do
  to "/etc/nginx/sites-available/#{nginx_config_filename}"
end

file "/etc/nginx/sites-enabled/default" do
  action :delete
end

#####   DEPLOYER USER  ########
chef_gem "ruby-shadow"

cookbook_file '/etc/sudoers.d/deployer_sudo' do
  mode "0440"
end

user node['app']['user'] do
  comment "Rails App Deployer"
  home "/home/#{node['app']['user']}"
  shell "/bin/bash"
  password node['deploy_user']['encoded_password']
end

directory "/home/#{node['app']['user']}/.ssh" do
  action :create
  owner node['app']['user']
  mode "700"
  recursive true
end

######  DIRECTORIES FOR RAILS APP  #######
['/releases', '/shared/sockets', '/shared', '/shared/log', '/shared/public', '/shared/config', '/shared/pids'].each do |catalog|
  directory "#{app_path}#{catalog}" do
    action :create
    user node['app']['user']
    recursive true
    mode "0755"
  end
end

##########   DATABASE.YML  ###########
template "#{app_path}/shared/config/database.yml" do
  source 'database.yml.erb'
  owner node['app']['user']
  mode '0644'
  variables(
    :password => node['mysql']['user_password'],
    :name => node['mysql']['database']
  )
end

execute "Generate locales (to avoid 'boost' lib errors)" do
  command "locale-gen en_US.UTF-8 ru_RU.UTF-8"
end

####  INIT SCRIPT FOR GITLAB CI  #######
template "/etc/init.d/gitlab_ci" do
  source 'init-script.erb'
  owner node['app']['user']
  variables(app_path: app_path)
end

execute "Give permissions for init script" do
  user node['app']['user']
  command "sudo chmod +x /etc/init.d/gitlab_ci"
end

execute "Auto run init script after reboot" do
  user node['app']['user']
  command "sudo update-rc.d gitlab_ci defaults 21"
end

## restart nginx ##
service 'nginx' do
  action :restart
end