#!/bin/sh
# Author: Christoph Galuschka <christoph.galuschka@chello.at>

t_Log "Running $0 - sendmail can accept and deliver local email."

# send mail to localhost
mail=$(echo -e "ehlo localhost\nmail from: root@localhost\nrcpt to: root@localhost\ndata\nt_functional test\n.\nquit\n" | nc -w 5 localhost 25 | grep accepted)
if [ $? == 0 ]
  then
  t_Log 'Mail has been queued successfully'
  MTA_ACCEPT=0
fi

sleep 1
regex='250\ 2\.0\.0\ ([0-9A-Za-z]*)\ Message\ accepted\ for\ delivery'
if [[ $mail =~ $regex ]]
  then
  egrep -q "${BASH_REMATCH[1]}\:.*stat\=Sent" /var/log/maillog
  DELIVERED=$?
fi

if ([ $MTA_ACCEPT == 0  ] && [ $DELIVERED == 0 ])
  then
  ret_val=0
  t_Log 'Mail has been delivered and removed from queue.'
fi

t_CheckExitStatus $ret_val