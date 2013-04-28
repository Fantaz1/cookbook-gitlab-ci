Description
-----------
This cookbook is only for setup environment for GitLab CI, not for deploying. Fork GitLab CI and use Capistrano gem for deploying, or use this fork: https://github.com/Fantaz1/gitlab-ci/tree/2-0-stable, with already installed Capistrano

Cookbook was tested only with 2-0-stable version of GitLab CI and on Ubuntu 12.04

Usage
-----

1. Encode your user password with
<pre>
    openssl passwd -1 "mypassword"
</pre>

2. Add solo.json to folder, like this:
<pre>
    {
        "app":{
            "user": "deployer"
        },
        "mysql": {
            "server_root_password": "password",
            "server_debian_password": "password",
            "server_repl_password": "password",
            "socket": "/var/run/mysqld/mysqld.sock",
            "bind_address": "localhost",
            "user_name": "mysqluser",
            "user_password": "password",
            "database": "gitlab_ci_production"
        },
        "github": {
            "url": "https://github.com/Fantaz1/gitlab-ci.git"
        },
        "hostname": "gitlabci.dev",
        "deploy_user": {
            "encoded_password": "EncodedPasswordFromStep1"
        },
        "nginx": {
            "config_filename": "gitlabci"
        },
        "run_list": [
            "recipe[openssl::default]",
            "recipe[gitlabci::default]",
            "recipe[mysql::server]"
        ]
    }
</pre>
3. Run command:
<pre>
    bash deploy.sh vagrant@192.168.33.10
</pre>
4. Deploy GitLab CI to this server

5. That's all:)