cfwtune
=======

Cisco Firewalls Tune (ACL Optimizer)
Made In Argentina.

The simplest way to optimize Cisco Firewalls Configurations.
Bash <3

Functionality
=======
1. Object-Group Subnetting
2. Object-Group Dummies (Unused)
3. ACLS Misapplied (Wrong Routing)
4. ACLS Dummies (Unused)
5. ACLS Shadows (Duplicate)

Compatibility (Tested)
=======

Cisco PIX Firewall (7.x/8.x)

Cisco ASA Firewall (7.x/8.x)

Cisco FWSM Firewall (3.x/4.x)

Dependencies
=======

dos2unix / ipcalc / ruby

Generally: sudo yum install dos2unix ipcalc ruby

How To
=======
You need From Your Firewall:

show running config or show tech > shrun.txt

show route > shroute.txt

EXECUTE:

./cfwtune shroute.txt shrun.txt
