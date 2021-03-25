FROM ghcr.io/catthehacker/ubuntu:act-18.04
SHELL [ "/bin/bash", "-l", "-c" ]
# Powershell Install
RUN apt-get update && apt-get install \
    apt-transport-https && \
    bash <(curl -s https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/install-powershell.sh)
#Dotnet Install
RUN wget https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y dotnet-sdk-5.0