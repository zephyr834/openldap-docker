#!/bin/bash
BASEDIR=$(readlink -f $(dirname $0))
set -e
LDAP_NAME=${LDAP_NAME:-openldap}
LDAP_VOLUME=${LDAP_VOLUME:-openldap-volume}
SLAPD_PASSWORD=${SLAPD_PASSWORD:-$1}
SLAPD_DOMAIN=${SLAPD_DOMAIN:-$2}
LDAP_IMAGE_NAME=${LDAP_IMAGE_NAME:-openfrontier/openldap}
CI_ADMIN_UID=${CI_ADMIN_UID:-$3}
CI_ADMIN_PWD=${CI_ADMIN_PWD:-$4}
CI_ADMIN_EMAIL=${CI_ADMIN_EMAIL:-$5}
PHPLDAPADMIN_NAME=${6:-phpldapadmin}
PHPLDAP_IMAGE_NAME=${7:-osixia/phpldapadmin}
PHPLDAP_LDAP_HOSTS=${PHPLDAP_LDAP_HOSTS:-openldap}

BASE_LDIF=base.ldif

ADD_TO_GROUPS_SCRIPT=add-users-to-initial-groups.sh

#Convert FQDN to LDAP base DN
SLAPD_TMP_DN=".${SLAPD_DOMAIN}"
while [ -n "${SLAPD_TMP_DN}" ]; do
SLAPD_DN=",dc=${SLAPD_TMP_DN##*.}${SLAPD_DN}"
SLAPD_TMP_DN="${SLAPD_TMP_DN%.*}"
done
SLAPD_DN="${SLAPD_DN#,}"

#Create OpenLDAP volume.
docker run \
--name ${LDAP_VOLUME} \
--entrypoint="echo" \
${LDAP_IMAGE_NAME} \
"Create OpenLDAP volume."

#Create base.ldif
sed -e "s/{SLAPD_DN}/${SLAPD_DN}/g" ${BASEDIR}/${BASE_LDIF}.template > ${BASEDIR}/${BASE_LDIF}
sed -i "s/{ADMIN_UID}/${CI_ADMIN_UID}/g" ${BASEDIR}/${BASE_LDIF}
sed -i "s/{ADMIN_EMAIL}/${CI_ADMIN_EMAIL}/g" ${BASEDIR}/${BASE_LDIF}

#Start openldap
docker run \
--name ${LDAP_NAME} \
-p 389:389 \
--volumes-from ${LDAP_VOLUME} \
-e SLAPD_PASSWORD=${SLAPD_PASSWORD} \
-e SLAPD_DOMAIN=${SLAPD_DOMAIN} \
-e USE_SSL=false \
-v ${BASEDIR}/${BASE_LDIF}:/${BASE_LDIF}:ro \
-d ${LDAP_IMAGE_NAME}

#start Phpldap admin
docker run \
--name ${PHPLDAPADMIN_NAME} \
-p 7443:80 \
--link ${LDAP_NAME}:openldap \
-e PHPLDAPADMIN_LDAP_HOSTS=${PHPLDAP_LDAP_HOSTS} \
-e PHPLDAPADMIN_HTTPS=false \
-d ${PHPLDAP_IMAGE_NAME}


while [ -z "$(docker logs ${LDAP_NAME} 2>&1 | tail -n 4 | grep 'slapd starting')" ]; do
    echo "Waiting openldap ready."
    sleep 1
done

#Import accounts
docker exec openldap \
ldapadd -f /${BASE_LDIF} -x -D "cn=admin,${SLAPD_DN}" -w ${SLAPD_PASSWORD}

## Setup CI Admin user's password
docker exec openldap \
ldappasswd -x -D "cn=admin,${SLAPD_DN}" -w ${SLAPD_PASSWORD} -s ${CI_ADMIN_PWD} \
"uid=${CI_ADMIN_UID},ou=accounts,${SLAPD_DN}"

## Test User Account
docker exec openldap \
ldappasswd -x -D "cn=admin,${SLAPD_DN}" -w ${SLAPD_PASSWORD} -s testpass \
"uid=testuser,ou=accounts,${SLAPD_DN}"

# Add testuser to developers group for testing
echo "Adding users to initial groups"
docker cp ${BASEDIR}/${ADD_TO_GROUPS_SCRIPT} openldap:/ # Copy over modify script since it can't be executed 
docker exec openldap /${ADD_TO_GROUPS_SCRIPT}
