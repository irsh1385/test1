export RG="TestRG"
export location="South India"
export login="adminuser"
export vNet="${RG}-vNET"
export tags="created-by=admin env=dev"

----
vnetadd=10.0.0.0/16
SUBNET1=AppSubnet|10.0.1.0/24|app-tier-nsg
SUBNET2=WebSubnet|10.0.2.0/24|web-tier-nsg
SUBNET3=DBSubnet|10.0.3.0/24|db-tier-nsg
SUBNET4=JumpSubnet|10.0.4.0/24|jump-nsg
NSG1=app-tier-nsg|default|0
NSG2=db-tier-nsg|default|0
NSG3=web-tier-nsg|custom|2
NSG4=jump-nsg|custom|1
web-tier-nsg-rule=100,HTTP-allow,0.0.0.0/0,*,10.0.1.0/24,80,Allow,Tcp|110,HTTPS-allow,0.0.0.0/0,*,10.0.1.0/24,443,Allow,Tcp
jump-nsg-rule=100,SSH-allow,0.0.0.0/0,*,10.0.0.128/25,22,Allow,Tcp
NIC1=app-tier-vm-nic|2|AppSubnet|app-tier-nsg|NA
NIC2=db-tier-vm-nic|2|WebSubnet|db-tier-nsg|NA
NIC3=web-tier-vm-nic|2|DBSubnet|web-tier-nsg|NA
NIC4=jump-tier-vm-nic|1|JumpSubnet|jump-nsg|jump-pip
PIP1=jump-pip
PIP2=web-lb-pip
AVS=avail-set|3
VM1=app-tier-vm|2|avail-set-1
VM2=db-tier-vm|2|avail-set-2
VM3=web-tier-vm|2|avail-set-3
VM4=jump-tier-vm|1|NA




# Create a resource group
echo "Creating $resourceGroup in $location..."
az group create --name $RG --location "$location" --tags $tags

# Create a virtual network
AddPrefix=`grep vnetadd parameter.txt | cut -d"=" -f2`
az network vnet create -g $RG -n $vNet --location "$location" --address-prefix $AddPrefix --tags $tags

#Create NSG
grep NSG parameter.txt | while read line
do
nsgName=`echo $line | cut -d"=" -f2 | cut -d"|" -f1`
Rule=`echo $line | cut -d"=" -f2 | cut -d"|" -f2`
RuleCount=`echo $line | cut -d"=" -f2 | cut -d"|" -f3`
echo "Creating NSG :: $nsgName"
az network nsg create --resource-group $RG --name $nsgName --tags $tags
if [ $Rule = "custom" ]
then
i=1

while [ $i -le $RuleCount ]
do
  ARR1=`grep $nsgName-rule parameter.txt | cut -d"=" -f2 | cut -d"|" -f$i`
  ARR=(`echo $ARR1 | tr ',' ' '`)
  az network nsg rule create --resource-group $RG --nsg-name $nsgName --name ${ARR[1]} --protocol ${ARR[7]} --source-address-prefixes ${ARR[2]} --priority ${ARR[0]} --destination-address-prefixes ${ARR[4]} --destination-port-range ${ARR[5]} --access ${ARR[6]}
  i=$((i+1))
done
else
        continue
fi
done


#Create Subnet
grep SUBNET parameter.txt | while read line
do
subName=`echo $line | cut -d"=" -f2 | cut -d"|" -f1`
AddPrefix=`echo $line | cut -d"=" -f2 | cut -d"|" -f2`
nsgName=`echo $line | cut -d"=" -f2 | cut -d"|" -f3`
echo "Creating Subnet :: $subName"
az network vnet subnet create --address-prefix $AddPrefix --name $subName --resource-group $RG --vnet-name $vNet --network-security-group $nsgName
done

#Create PIP
grep PIP parameter.txt | while read line
do
pipName=`echo $line | cut -d"=" -f2 | cut -d"|" -f1`
az network public-ip create --resource-group $RG --name $pipName --dns-name $pipName-test2022
done

#Creating NIC
grep NIC parameter.txt | while read line
do
NicName=`echo $line | cut -d"=" -f2 | cut -d"|" -f1`
Count=`echo $line | cut -d"=" -f2 | cut -d"|" -f2`
subnetName=`echo $line | cut -d"=" -f2 | cut -d"|" -f3`
nsgName=`echo $line | cut -d"=" -f2 | cut -d"|" -f4`
pipName=`echo $line | cut -d"=" -f2 | cut -d"|" -f5`

if [ $pipName = "NA" ]
then
i=1
while [ $i -le $Count ]
do
az network nic create --resource-group $RG --name $NicName-$i --vnet-name $vNet --subnet $subnetName --network-security-group $nsgName
i=$((i+1))
done
else
i=1
while [ $i -le $Count ]
do
az network nic create --resource-group $RG --name $NicName-$i --vnet-name $vNet --subnet $subnetName --network-security-group $nsgName  --public-ip-address $pipName
i=$((i+1))
done
fi
done

#Create Availability set
grep AVS parameter.txt | while read line
do
AVSName=`echo $line | cut -d"=" -f2 | cut -d"|" -f1`
Count=`echo $line | cut -d"=" -f2 | cut -d"|" -f2`
i=1
while [ $i -le $Count ]
do
az vm availability-set create --resource-group $RG --name $AVSName-$i
i=$((i+1))
done   
done 

#Create Storage 
az storage account create -n teststorage20221  --resource-group $RG --location "$location" --sku Standard_LRS --tags $tags

#Creating VM and related Resource
grep VM parameter.txt | while read line
do
VMName=`echo $line | cut -d"=" -f2 | cut -d"|" -f1`
Count=`echo $line | cut -d"=" -f2 | cut -d"|" -f2`
AVSName=`echo $line | cut -d"=" -f2 | cut -d"|" -f3`
    
if [ $AVSName = "NA" ]
then
i=1
while [ $i -le $Count ]
do
az vm create --resource-group $RG --name $VMName-$i --location "$location" --nics $VMName-nic-$i --image UbuntuLTS --admin-username azureuser --generate-ssh-keys --os-disk-name $VMName-$i-OSDisk --boot-diagnostics-storage teststorage20221

i=$((i+1))
done
else
i=1
while [ $i -le $Count ]
do
az vm create --resource-group $RG --name $VMName-$i --location "$location" --availability-set $AVSName --nics $VMName-nic-$i --image UbuntuLTS --admin-username azureuser --generate-ssh-keys --os-disk-name $VMName-$i-OSDisk --boot-diagnostics-storage teststorage20221

i=$((i+1))
done
fi
done

#Create Public LB
az network lb create --resource-group $RG --name web-lb --sku Basic --public-ip-address web-lb-pip --frontend-ip-name myFrontEnd --backend-pool-name myBackEndPool
az network lb probe create --resource-group $RG  --lb-name web-lb  --name weblbProbeHttp --protocol tcp --port 80
az network lb probe create --resource-group $RG  --lb-name web-lb  --name weblbProbeHttps --protocol tcp --port 443
az network lb rule create --resource-group $RG --lb-name web-lb --name myHTTPRule --protocol tcp --frontend-port 80 --backend-port 80 --frontend-ip-name myFrontEnd --backend-pool-name myBackEndPool --probe-name weblbProbeHttp --disable-outbound-snat true --idle-timeout 15
az network lb rule create --resource-group $RG --lb-name web-lb --name myHTTPRules --protocol tcp --frontend-port 443 --backend-port 443 --frontend-ip-name myFrontEnd --backend-pool-name myBackEndPool --probe-name weblbProbeHttps --disable-outbound-snat true --idle-timeout 15
array=(web-tier-vm-nic-1 web-tier-vm-nic-2)
for vmnic in "${array[@]}"
do
    az network nic ip-config address-pool add --address-pool myBackendPool --ip-config-name ipconfig1 --nic-name $vmnic --resource-group $RG --lb-name web-lb
done

#Create Internal LB
az network lb create --resource-group $RG --name internal-lb --sku Basic --vnet-name $vNet --subnet WebSubnet --frontend-ip-name myFrontEnd --backend-pool-name myBackEndPool
az network lb probe create --resource-group $RG  --lb-name internal-lb  --name weblbProbeHttp --protocol tcp --port 80
az network lb probe create --resource-group $RG  --lb-name internal-lb  --name weblbProbeHttps --protocol tcp --port 443
az network lb rule create --resource-group $RG --lb-name internal-lb --name myHTTPRule --protocol tcp --frontend-port 80 --backend-port 80 --frontend-ip-name myFrontEnd --backend-pool-name myBackEndPool --probe-name weblbProbeHttp --disable-outbound-snat true --idle-timeout 15
az network lb rule create --resource-group $RG --lb-name internal-lb --name myHTTPRules --protocol tcp --frontend-port 443 --backend-port 443 --frontend-ip-name myFrontEnd --backend-pool-name myBackEndPool --probe-name weblbProbeHttps --disable-outbound-snat true --idle-timeout 15
array=(app-tier-vm-nic-1 app-tier-vm-nic-2)
for vmnic in "${array[@]}"
do
    az network nic ip-config address-pool add --address-pool myBackendPool --ip-config-name ipconfig1 --nic-name $vmnic --resource-group $RG --lb-name internal-lb
done
