# DataPower WebGUI OCP Deployer

A tool to setup a basic DataPower deployment with the administrative WebGUI already enabled and accessible via a Route.

## Prerequisites

1. Install the DataPower operator from OperatorHub in a namespace of your choice.

2. Install the OpenShift `oc` cli

3. Login to the OpenShift cluster you wish to install the instance into on the cli.

## How to Use

1. Run `./install.sh`

> You may need to give it permissions to execute first with `chmod +x install.sh`

2. Follow the onscreen instructions which will check the OpenShift Project you wish to install into and what you wish your admin password for the dashboard to be.

3. The script will wait for the pods to be in a ready state and then provide the URL to the WebGUI.
