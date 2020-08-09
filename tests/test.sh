#!/bin/bash

# This script is part of MailAD, see https://github.com/stdevPavelmc/mailad/
# Copyright 2020 Pavel Milanes Costa <pavelmc@gmail.com>
# LICENCE: GPL 3.0 and later  
#
# Goal:
#   - Test a few properties of the email server
#     see the README.md on this directory for deatils

# load the conf and locate the common
source /etc/mailad/mailad.conf

# check for the local credentials for the test
if [ -f /root/mailad/.mailadmin.auth ] ; then
    # load the credentials and go on
    source /root/mailad/.mailadmin.auth
else
    # no credential file, notice and stop
    echo "===> There is no local credentials file, aborting tests"
    echo " "
    echo " You can learn about test in the README.md file inside the"
    echo " test directory of the repository"
    exit 1
fi

# Capture the destination server or use the default
if [ "$1" == "" ] ; then
    SERVER="10.0.3.3"
else
    SERVER="$1"
fi

# internal vars
SOFT=`which swaks`
if [ "$SOFT" == "" ] ; then
    echo "======================================================"
    echo "ERROR: main tool not found: swaks"
    echo "======================================================"
    exit 1
fi

# others
LOG=./test.log
LOGP=./latest.log
cat /dev/null > $LOG

# Reset the locales
LANGUAGE="en_US"
LC_ALL=C
LANG="en_US.UTF-8"
export LANGUAGE
export LC_ALL
export LANG

# advice
echo " "
echo "Using server: $SERVER"
echo " "

### Send an email to the mail admin: port 25
$SOFT -s $SERVER --protocol SMTP -t $ADMINMAIL > $LOGP
R=$?
if [ $R -ne 0 ] ; then
    # error
    echo "======================================================"
    echo "ERROR: Can't send a mail to a valid local email using"
    echo "       simple SMTP (25)"
    echo " "
    echo "COMMENT: It's expected that your server can receive"
    echo "         emails for it's domain, please check your"
    echo "         configuration"
    echo " "
    echo "Exit code: $R"
    echo "Logs follow"
    echo "======================================================"
    cat $LOGP
    exit 1
else
    # ok
    echo "===> Ok: You can receive emails for your domain"
fi
# sum the logs
cat $LOGP > $LOG

### Send an email to the mail admin with auth as sender
$SOFT -s "$SERVER" -p 587 -tls -a PLAIN -au "$ADMINMAIL" -ap "$PASS" -t "$ADMINMAIL" -f "$ADMINMAIL"  > $LOGP
R=$?
if [ $R -ne 0 ] ; then
    # error
    echo "========================================================="
    echo "ERROR: Can't relay a mail to a valid local recipient with"
    echo "       authentication (as sender) over SUBMISSION (587)"
    echo " "
    echo "COMMENT: It's expected that your server can receive"
    echo "         emails for it's domain via SUBMISSION from an"
    echo "         authenticated user, please check your"
    echo "         configuration"
    echo " "
    echo "Exit code: $R"
    echo "Logs follow"
    echo "========================================================="
    cat $LOGP
    exit 1
else
    # ok
    echo "===> Ok: Authenticated users can send local emails"
fi
# sum the logs
cat $LOGP >> $LOG

### Send an email to the outside as a valid user with auth
$SOFT -s "$SERVER" -p 587 -tls -a PLAIN -au "$ADMINMAIL" -ap "$PASS" -t "fake@example.com" -f "$ADMINMAIL"  > $LOGP
R=$?
if [ $R -ne 0 ] ; then
    # error
    echo "=========================================================="
    echo "ERROR: Can't send a mail to an outside recipient using"
    echo "       authentication (as sender) from a local user over"
    echo "       SUBMISSION (587)"
    echo " "
    echo "COMMENT: It's expected that your server can send an email"
    echo "         to the outside world via SUBMISSION from an"
    echo "         authenticated local user, please check your"
    echo "         configuration"
    echo " "
    echo "Exit code: $R"
    echo "Logs follow"
    echo "=========================================================="
    cat $LOGP
    exit 1
else
    # ok
    echo "===> Ok: Authenticated users can send emails to the outside world"
fi
# sum the logs
cat $LOGP >> $LOG

### Send an email to a non-existent user, port 25
USER=`mktemp | cut -d '/' -f 3`
$SOFT -s $SERVER --protocol SMTP -t "$USER@$DOMAIN" > $LOGP
R=$?
if [ $R -ne 24 ] ; then
    # error
    echo "=========================================================="
    echo "ERROR: Can send a mail to a non-valid local email via SMTP"
    echo " "
    echo "COMMENT: It's expected that your server bounce mails for"
    echo "         unknown recipients of your domain, please check"
    echo "         your configuration"
    echo " "
    echo "Exit code: $R"
    echo "Logs follow"
    echo "=========================================================="
    cat $LOGP
    exit 1
else
    # ok
    echo "===> Ok: Your server reject unknown recipients"
fi
# sum the logs
cat $LOGP >> $LOG

### Send an email to an external user as an outsider domain, port 25 (open relay)
USER=`mktemp | cut -d '/' -f 3`
USER1=`mktemp | cut -d '/' -f 3`
$SOFT -s $SERVER --protocol SMTP -t "$USER@example" -f "$USER1@example" > $LOGP
R=$?
if [ $R -ne 24 ] ; then
    # error
    echo "========================================================"
    echo "ERROR: Can relay a mail not for your domain and comming"
    echo "       from a external domain"
    echo " "
    echo "COMMENT: It's expected that your server does not relay"
    echo "         mails for other domains than the configured one"
    echo "         so you are an OPEN REALY server, and that is"
    echo "         bad, VERY BAD, please check your configuration"
    echo " "
    echo "Exit code: $R"
    echo "Logs follow"
    echo "========================================================"
    cat $LOGP
    exit 1
else
    # ok
    echo "===> Ok: Your server is not and open relay"
fi
# sum the logs
cat $LOGP >> $LOG

### Send an email to the mail admin: port SSMTP
$SOFT -s "$SERVER" --protocol SSMTP -t $ADMINMAIL > $LOGP
R=$?
if [ $R -ne 24 ] ; then
    # error
    echo "======================================================="
    echo "ERROR: Can send a mail to a valid local email via SSMTP"
    echo "       with no authentication"
    echo " "
    echo "COMMENT: It's expected that your server bounce emails"
    echo "         via secure channel with no authentication,"
    echo "         please check your configuration"
    echo " "
    echo "Exit code: $R"
    echo "Logs follow"
    echo "======================================================"
    cat $LOGP
    exit 1
else
    # ok
    echo "===> Ok: The server rejects relaying mail though unauthenticated SMTPS"
fi
# sum the logs
cat $LOGP >> $LOG

### Send an email as an user and auth as other (id spoofing)
$SOFT -s "$SERVER" -p 587 -tls -a PLAIN -au "$ADMINMAIL" -ap "$PASS" -t "$ADMINMAIL" -f "$USER@$DOMAIN" > $LOGP
R=$?
if [ $R -ne 24 ] ; then
    # error
    echo "========================================================="
    echo "ERROR: Can send a mail to a valid local email using"
    echo "       SUBMISSION and a valid authentication that does"
    echo "       not match the sender address"
    echo " "
    echo "COMMENT: It's expected that your server bounce emails"
    echo "         from a sender that authenticated as another user"
    echo "         this is a well known id spoofing technique,"
    echo "         please check your configuration"
    echo " "
    echo "Exit code: $R"
    echo "Logs follow"
    echo "========================================================="
    cat $LOGP
    exit 1
else
    # ok
    echo "===> Ok: The server does NOT allow id spoofing"
fi
# sum the logs
cat $LOGP >> $LOG

### Send an email to the mail admin with an attachment bigger than the allowed: port 25
MS=`echo "$MESSAGESIZE*1024*1024*1.2" | bc -q | cut -d '.' -f 1`
TMP=`mktemp`
dd if=/dev/zero of=$TMP bs=1 count="$MS" 2>/dev/null
$SOFT -s $SERVER --protocol SMTP -t $ADMINMAIL --attach "$TMP" > $LOGP
rm $TMP
R=$?
if [ $R -ne 0 ] ; then
    # error
    echo "======================================================"
    echo "ERROR: Can send a mail to a valid local email via SMTP"
    echo "       with an attachement bigger than the stated"
    echo " "
    echo "COMMENT: It's expected that your server bounce emails"
    echo "         that are bigger that the maximium stated,"
    echo "         please check your configuration"
    echo " "
    echo "Exit code: $R"
    echo "Logs follow"
    echo "======================================================"
    cat $LOGP
    exit 1
else
    # ok
    echo "===> Ok: Mail size restriction is working"
fi
# sum the logs
cat $LOGP >> $LOG

# NATIONAL

### Send an email to a national User from an international account: port 25
$SOFT -s $SERVER --protocol SMTP -t $NACUSER -f "testing@example.com" > $LOGP
R=$?
if [ $R -ne 24 ] ; then
    # error
    echo "======================================================"
    echo "ERROR: Can send a mail to a defined national account"
    echo "       from an international address: using SMTP (25)"
    echo " "
    echo "COMMENT: It's expected that your server block this"
    echo "         emails, as a policy, please check your"
    echo "         configuration"
    echo " "
    echo "Exit code: $R"
    echo "Logs follow"
    echo "======================================================"
    cat $LOGP
    exit 1
else
    # ok
    echo "===> Ok: National restricted users can't receive emails from outside"
fi
# sum the logs
cat $LOGP >> $LOG

### Send an email to the outside as a national user user with auth
$SOFT -s "$SERVER" -p 587 -tls -a PLAIN -au "$NACUSER" -ap "$NACUSERPASSWD" -t "fake@example.com" -f "$NACUSER" > $LOGP
R=$?
if [ $R -ne 24 ] ; then
    # error
    echo "=========================================================="
    echo "ERROR: Can send a mail to an internet recipient from a"
    echo "       national limited account, using SUBMISSION (587)"
    echo " "
    echo "COMMENT: It's expected that your server block this as"
    echo "         the users is limited to national access only,"
    echo "         please check your configuration"
    echo " "
    echo "Exit code: $R"
    echo "Logs follow"
    echo "=========================================================="
    cat $LOGP
    exit 1
else
    # ok
    echo "===> Ok: National restricted users can't send emails to internet"
fi
# sum the logs
cat $LOGP >> $LOG

### Send an email to a national recipient as a national user user with auth
$SOFT -s "$SERVER" -p 587 -tls -a PLAIN -au "$NACUSER" -ap "$NACUSERPASSWD" -t "reject@nonexistent.cu" -f "$NACUSER" > $LOGP
R=$?
if [ $R -ne 0 ] ; then
    # error
    echo "=========================================================="
    echo "ERROR: Can't send a mail to a national recipient from a"
    echo "       national limited account, using SUBMISSION (587)"
    echo " "
    echo "COMMENT: It's not the expected, your server must allow the"
    echo "         user to send the mail, please check your"
    echo "         configuration"
    echo " "
    echo "Exit code: $R"
    echo "Logs follow"
    echo "=========================================================="
    cat $LOGP
    exit 1
else
    # ok
    echo "===> Ok: National restricted users can send emails to national address"
fi
# sum the logs
cat $LOGP >> $LOG

### LOCAL

### Send an email to a local user from an international account: port 25
$SOFT -s $SERVER --protocol SMTP -t "$LOCUSER" -f "testing@example.com" > $LOGP
R=$?
if [ $R -ne 24 ] ; then
    # error
    echo "======================================================"
    echo "ERROR: Can send a mail to a defined local account from"
    echo "       an international address: using SMTP (25)"
    echo " "
    echo "COMMENT: It's expected that your server block this"
    echo "         emails as this users has only local domain"
    echo "         access, please check your configuration"
    echo " "
    echo "Exit code: $R"
    echo "Logs follow"
    echo "======================================================"
    cat $LOGP
    exit 1
else
    # ok
    echo "===> Ok: Local restricted users can't receive emails from outside"
fi
# sum the logs
cat $LOGP >> $LOG

### Send an email to the outside as a local user user with auth
$SOFT -s "$SERVER" -p 587 -tls -a PLAIN -au "$LOCUSER" -ap "$LOCUSERPASSWORD" -t "fake@example.com" -f "$LOCUSER" > $LOGP
R=$?
if [ $R -ne 24 ] ; then
    # error
    echo "=========================================================="
    echo "ERROR: Can send a mail to an internet recipient from a"
    echo "       local limited account, using SUBMISSION (587)"
    echo " "
    echo "COMMENT: It's expected that your server block this as"
    echo "         the users is limited to local access only,"
    echo "         please check your configuration"
    echo " "
    echo "Exit code: $R"
    echo "Logs follow"
    echo "=========================================================="
    cat $LOGP
    exit 1
else
    # ok
    echo "===> Ok: Local restricted users can't send emails to internet"
fi
# sum the logs
cat $LOGP >> $LOG

### Send an email to a local recipient as a local user user with auth
$SOFT -s "$SERVER" -p 587 -tls -a PLAIN -au "$LOCUSER" -ap "$LOCUSERPASSWORD" -t "$NACUSER" -f "$LOCUSER" > $LOGP
R=$?
if [ $R -ne 0 ] ; then
    # error
    echo "=========================================================="
    echo "ERROR: Can't send a mail to an local recipient from a"
    echo "       local limited account, using SUBMISSION (587)"
    echo " "
    echo "COMMENT: It's not the expected, your server must allow the"
    echo "         user to send the mail, please check your"
    echo "         configuration"
    echo " "
    echo "Exit code: $R"
    echo "Logs follow"
    echo "=========================================================="
    cat $LOGP
    exit 1
else
    # ok
    echo "===> Ok: Local restricted users can send emails to local recipients"
fi
# sum the logs
cat $LOGP >> $LOG

# EVERYONE testing
if [ "$EVERYONE" != "" ] ; then
    ### Send an email to the everyone as a local user
    $SOFT -s "$SERVER" -p 587 -tls -a PLAIN -au "$LOCUSER" -ap "$LOCUSERPASSWORD" -t "$EVERYONE" -f "$LOCUSER" > $LOGP
    R=$?
    if [ $R -ne 0 ] ; then
        # error
        echo "=========================================================="
        echo "ERROR: Can't send a mail to the EVERYONE account declared"
        echo "       in the config using a local autenticated account"
        echo "       using SUBMISSION (587)"
        echo " "
        echo "COMMENT: It's not the expected, your server must allow the"
        echo "         user to send the mail, please check your"
        echo "         configuration"
        echo " "
        echo "Exit code: $R"
        echo "Logs follow"
        echo "=========================================================="
        cat $LOGP
        exit 1
    else
        # ok
        echo "===> Ok: Local users can send emails to the everyone declared alias"
    fi
    # sum the logs
    cat $LOGP >> $LOG

    ### Send an email to a the everyone alias from an international account: port 25
    $SOFT -s $SERVER --protocol SMTP -t "$EVERYONE" -f "testing@invalid.com" > $LOGP
    R=$?
    if [ "$EVERYONE_ALLOW_EXTERNAL_ACCESS" == "no" ] ; then
        # no access from the outside
        if [ $R -eq 0 ] ; then
            # error
            echo "======================================================"
            echo "ERROR: Can send a mail to the defined everyone alias"
            echo "       from an international address: using SMTP (25)"
            echo "       and your config does not allow that"
            echo " "
            echo "COMMENT: It's expected that your server block this"
            echo "         emails as the main config does not allow"
            echo "         this explicitely"
            echo " "
            echo "Exit code: $R"
            echo "Logs follow"
            echo "======================================================"
            cat $LOGP
            exit 1
        else
            # ok
            echo "===> Ok: EVERYONE alias can't receive emails from outside"
        fi
    else
        if [ $R -ne 0 ] ; then
            # error
            echo "======================================================"
            echo "ERROR: Can't send a mail to the defined everyone alias"
            echo "       from an international address: using SMTP (25)"
            echo "       and your config does allow that"
            echo " "
            echo "COMMENT: It's expected that your server allows this"
            echo "         emails as the main config does allow this"
            echo "         explicitely"
            echo " "
            echo "Exit code: $R"
            echo "Logs follow"
            cat $LOGP
            exit 1
        else
            # ok
            echo "===> Ok: EVERYONE alias can receive emails from outside"
        fi
    fi 
    # sum the logs
    cat $LOGP >> $LOG
fi