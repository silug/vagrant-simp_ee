echo "============================INSTALLING AGENT===================================="
echo "Installing $SCAN_ORG-$SCAN_TYPE from yum repo from $CONSOLE_IP:$CONSOLE_PORT"
cd /vagrant
cp simp-scanner.repo /etc/yum.repos.d
sed -i "s/<CONSOLE-IP>:<CONSOLE-PORT>\/plugins\/<SCAN-ORG>/$CONSOLE_IP:$CONSOLE_PORT\/plugins\/$SCAN_ORG/g" "/etc/yum.repos.d/simp-scanner.repo"
yum install -y "$SCAN_ORG-$SCAN_TYPE"
touch "/etc/$SCAN_ORG/agent.log"
mkdir "/etc/$SCAN_ORG/reports"

#echo "$CONSOLE_IP sicura-console-collector" > /etc/hosts

mkdir "/etc/$SCAN_ORG"
config="/etc/$SCAN_ORG/$SCAN_ORG-$SCAN_TYPE.yaml"

if [ $API = 2 ] ; then
  echo "============================SETTING UP V2 API==================================="
  cp simp-agent.yaml $config
  sed -i "s/<CONSOLE-IP>:<CONSOLE-PORT>/$CONSOLE_IP:$CONSOLE_PORT/g" $config

  if [ $CIS = "true" ] ; then
    echo "===========================INSTALLING CIS ASSESSOR=============================="
    ### V2
    sed -i 's/# - ciscat/- ciscat/g' $config
    sed -i "s/<CIS-BENCHMARK>/$CIS_BENCHMARK/g" $config
    sed -i "s/<CIS-PROFILE>/$CIS_PROFILE/g" $config

    ########################## Pre 180 ############################
    # manual install
    echo 'Manually installing CIS Assessor'
    bash 'cis_setup.sh'

    # cis package
    # echo 'Running CIS installer'
    # yum install -y unzip
    # yum install -y simp-agent-cis-1.0.1-1.x86_64.rpm
    # mkdir /var/db/simp/agent/state/bin/Assessor-CLI/license
    # unzip cis_license.zip -d /var/db/simp/agent/state/bin/Assessor-CLI/license
    # mv /var/db/simp/agent/state/bin/Assessor-CLI /etc/simp
    ########################## Pre 180 ############################

    echo 'Turning on ignore platform mismatch'
    sed -i 's/ignore.platform.mismatch=false/g' 'ignore.platform.mismatch=true'
  fi

  if [ $STIG = "true" ] ; then
    ### V2
    sed -i 's/# - openscap/- openscap/g' $config
    sed -i "s/<STIG-BENCHMARK>/$STIG_BENCHMARK/g" $config
    sed -i "s/<STIG-PROFILE>/$STIG_PROFILE/g" $config
  fi
else
  sicura-agent info
fi

if [ $BOLT = "true" ] ; then
  echo "============================INSTALLING BOLT====================================="
  sed -i 's/# - bolt/- bolt/g' $config
  bash bolt_setup.sh
fi

cd /home/vagrant

sed -i "s/collector-https: true/collector-https: false/g" $config
sed -i "s/collector-port: 6468/collector-port: $CONSOLE_PORT/g" $config

echo "============================START AGENT SERVICE====================================="
systemctl start "$SCAN_ORG-$SCAN_TYPE"
