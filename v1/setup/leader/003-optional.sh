#!/usr/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../../lib/helpers.sh

echo "-------Leader node, beginning optional setup scripts-------"
for service in $(etcd-get /environment/services)
do
  servicedir=$DIR/../../opt/${service}/setup/leader
  if [[ ! -d $servicedir ]]; then
      continue
  fi

  for script in $(ls $servicedir|grep -e '.sh$')
  do
      sudo $servicedir/${script}
  done
done
echo "-------Leader node, done optional setup scripts-------"
