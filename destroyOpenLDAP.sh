#!/bin/bash

LDAP_NAME=${LDAP_NAME:-openldap}
LDAP_VOLUME=${LDAP_VOLUME:-openldap-volume}
PHPLDAPADMIN_NAME=${PHPLDAPADMIN_NAME:-phpldapadmin}

if [ -n "$(docker ps -a | grep ${LDAP_NAME})" ]; then
docker stop ${LDAP_NAME}
docker rm -v ${LDAP_NAME}
docker rm -v ${LDAP_VOLUME}
fi

if [ -n "$(docker ps -a | grep ${PHPLDAPADMIN_NAME})" ]; then
docker stop ${PHPLDAPADMIN_NAME}
docker rm -v ${PHPLDAPADMIN_NAME}
fi
