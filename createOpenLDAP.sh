#!/bin/bash
BASEDIR=$(readlink -f $(dirname $0))
set -e
LDAP_NAME=${LDAP_NAME:-openldap}
LDAP_VOLUME=${LDAP_VOLUME:-openldap-volume}
SLAPD_PASSWORD=${SLAPD_PASSWORD:-$1}
SLAPD_DOMAIN=${SLAPD_DOMAIN:-$2}
LDAP_IMAGE_NAME=${LDAP_IMAGE_NAME:-openfrontier/openldap}
PHPLDAPADMIN_NAME=${3:-phpldapadmin}
PHPLDAP_LDAP_HOSTS=${PHPLDAP_LDAP_HOSTS:-openldap}
PHPLDAP_IMAGE_NAME=${4:-osixia/phpldapadmin}
GERRIT_ADMIN_UID=${GERRIT_ADMIN_UID:-$5}
GERRIT_ADMIN_PWD=${GERRIT_ADMIN_PWD:-$6}
GERRIT_ADMIN_EMAIL=${GERRIT_ADMIN_EMAIL:-$7}

BASE_LDIF=base.ldif

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
sed -i "s/{ADMIN_UID}/${GERRIT_ADMIN_UID}/g" ${BASEDIR}/${BASE_LDIF}
sed -i "s/{ADMIN_EMAIL}/${GERRIT_ADMIN_EMAIL}/g" ${BASEDIR}/${BASE_LDIF}

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

docker exec openldap \
ldappasswd -x -D "cn=admin,${SLAPD_DN}" -w ${SLAPD_PASSWORD} -s ${GERRIT_ADMIN_PWD} \
"uid=${GERRIT_ADMIN_UID},ou=accounts,${SLAPD_DN}"
