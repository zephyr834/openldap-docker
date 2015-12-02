#!/bin/bash
set -e

echo "Adding to admin group"
ldapmodify -vv -x -D "cn=admin,dc=demo,dc=com" -w secret <<!123
dn: cn=admin,ou=groups,dc=demo,dc=com
changetype: modify
replace: memberUid
memberUid: admin
!123

echo "Adding to developers group"
#echo "dn: cn=developers,ou=groups,dc=demo,dc=com
#changetype: modify 
#add: memberUid 
#memberUid: testuser
#" | ldapmodify -x -D "cn=admin,dc=demo,dc=com" -w secret
ldapmodify -vv -x -D "cn=admin,dc=demo,dc=com" -w secret <<!123
dn: cn=developers,ou=groups,dc=demo,dc=com
changetype: modify
replace: memberUid
memberUid: testuser
!123

