# login to Azure
az login --identity

# get information about the current environment
resourceGroupName=`curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/resourceGroupName?api-version=2018-10-01&format=text"`

# get the resource name of the storage account using tags
storageAccountName=`az resource list --tag dt=serverlogstorage --query [].name -o tsv`

# get the storage account primary key
storageAccountKey=`az storage account keys list -g $resourceGroupName -n $storageAccountName --query [0].value -o tsv`

# set (hard code) the name of the server log storage share
fileShareName=serverlogstorage

# install CIFS utils
sudo yum install cifs-utils -y

# apply the instructions on Azure docs to make the Azure Files share persist across reboots
# https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-use-files-linux

mntPath="/mnt/$storageAccountName/$fileShareName"
sudo mkdir -p $mntPath

# create a credentials file for the storage account key
if [ ! -d "/etc/smbcredentials" ]; then
    sudo mkdir "/etc/smbcredentials"
fi

smbCredentialFile="/etc/smbcredentials/$storageAccountName.cred"

if [ ! -f $smbCredentialFile ]; then
    echo "username=$storageAccountName" | sudo tee $smbCredentialFile > /dev/null
    echo "password=$storageAccountKey" | sudo tee -a $smbCredentialFile > /dev/null
else 
    echo "The credential file $smbCredentialFile already exists, and was not modified."
fi

# make the credentials file read only by root
sudo chmod 600 $smbCredentialFile

httpEndpoint=$(az storage account show \
    --resource-group $resourceGroupName \
    --name $storageAccountName \
    --query "primaryEndpoints.file" | tr -d '"')
smbPath=$(echo $httpEndpoint | cut -c7-$(expr length $httpEndpoint))$fileShareName

if [ -z "$(grep $smbPath\ $mntPath /etc/fstab)" ]; then
    echo "$smbPath $mntPath cifs nofail,vers=3.0,credentials=$smbCredentialFile,serverino" | sudo tee -a /etc/fstab > /dev/null
else
    echo "/etc/fstab was not modified to avoid conflicting entries as this Azure file share was already present. You may want to double check /etc/fstab to ensure the configuration is as desired."
fi

sudo mount -a

# Exit script with 0 code to tell Azure that the deployment is done
exit 0 

