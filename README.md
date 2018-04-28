# debian8-openvas9
Vagrant files that will auto build and initialize a debian8-based OpenVAS9 server with some defaults I like.

## Greenbone Security Web Access
Starting with Greenbone Security Assistant v7.0.3, the gsad process will only accept web connections that contain specifically alloed HTTP host headers. 

Edit the file /usr/local/lib/systemd/system/gsad.service and add the resolvable DNS name or current IP of the system to the "--allow-header-host" launch option. This defaults to "openvas."

## SSH Keys
By default the bootstrap.sh file removes the ability to log in via ssh password for all users. Add an authorized_keys file within the resources directory and add any keys you'd like. I don't track this file for security reasons.
