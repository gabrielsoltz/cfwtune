cfwtune
=======

Cisco Firewalls Tune (ACL Optimizer)
Made In Argentina. Bash <3

The simplest way to optimize Cisco Firewalls Configurations.

Compatibility (Tested)
=======

Cisco PIX Firewall (7.x/8.x)
Cisco ASA Firewall (7.x/8.x)
Cisco FWSM Firewall (3.x/4.x)

Compatibility (Tested)
=======

Cisco PIX Firewall (7.x/8.x)
Cisco ASA Firewall (7.x/8.x)
Cisco FWSM Firewall (3.x/4.x)

Dependencies
=======

dos2unix
ipcalc
ruby

Generally: sudo yum install dos2unix ipcalc ruby

How To
=======
1. You need From Your Firewall:
show running config / show tech > shrun.txt
show route > shroute.txt

2. Execute:
./cfwtune shroute.txt shrun.txt
