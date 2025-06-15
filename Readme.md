# Table of Content

- [Table of Content](#table-of-content)
- [:warning: Disclaimer :warning:](#warning-disclaimer-warning)
  - [Ubuntu version](#ubuntu-version)
  - [Box64 configuration](#box64-configuration)
- [Credit](#credit)
- [Instructions](#instructions)
- [Pre-requisite](#pre-requisite)
  - [Windows](#windows)
  - [Mac / Linux](#mac--linux)
- [OCI (Oracle Cloud Infrastructure)](#oci-oracle-cloud-infrastructure)
  - [Creating the VM instance](#creating-the-vm-instance)
  - [Configuring the Network and firewall rules](#configuring-the-network-and-firewall-rules)
- [Connecting to the VM Instance](#connecting-to-the-vm-instance)
  - [Windows](#windows-1)
  - [Mac / Linux](#mac--linux-1)
- [Installing the Valheim Dedicated Server](#installing-the-valheim-dedicated-server)
- [Configuring the Valheim Server](#configuring-the-valheim-server)
- [Starting the Valheim Server](#starting-the-valheim-server)
- [Updating the Valheim Server](#updating-the-valheim-server)
- [Crossplay (Console / Game Pass)](#crossplay-console--game-pass)
- [Modding](#modding)
- [Installer Self-update](#installer-self-update)
- [Adding Pre-existing worlds](#adding-pre-existing-worlds)
- [Troubleshooting](#troubleshooting)
  - [Discord](#discord)
- [Changing versions](#changing-versions)
  - [Switcing to the Previous Stable Version](#switcing-to-the-previous-stable-version)
  - [Switching to the Public Beta Branch](#switching-to-the-public-beta-branch)
  - [Reverting back to the public version](#reverting-back-to-the-public-version)
- [Oracle and Reclamation of Idle Compute Instances](#oracle-and-reclamation-of-idle-compute-instances)
- [TODOs](#todos)


# :warning: Disclaimer :warning:

## Ubuntu version
Currently the only supported version of Ubuntu is Ubuntu 22.04 LTS, please make sure the image **Canonical Ubuntu 22.04 Minimal aarch64** is selected during the setup procedure.

This is because changes was done in preparation to how timestamps will be handled prior to 2038.  
This was added last minute prior to the Ubuntu 24.04LTS release cycle feature feeeze, which unfortunately impacted `armhf` which we rely on here, more information can be found at the ubuntu mailing list: https://lists.ubuntu.com/archives/ubuntu-devel-announce/2024-March/001344.html

## Box64 configuration

This install script has now been updated with a configuration for box64 which has been tested to work for a few weeks and by different people using this guide.  
If you have made any changes to the `~/.box64rc` configuration file for the `[valheim_server.x86_64]` section, please remove it and run the setup script.  
If you should experience any issues, please leave a comment.

~~This script / procedure for setting up a Valheim server on ARM is currently broken as of 7th of November 2023.
(https://www.valheimgame.com/news/patch-0-217-28/)~~

~~This unfortunately also includes the rollback procedure.
Check comments for any updates regarding this issue.~~

# Credit
The original guide is from Reddit user That_Conversation_91 on [r/Valheim](https://www.reddit.com/r/valheim/).  
Original post can be found [here](https://www.reddit.com/r/valheim/comments/s1os21/create_your_own_free_dedicated_server)


# Instructions
**Note**: For this guide a free account is required on the Oracle Cloud Infrastructure allowing us to spin up a server which is decently specced.  

In this guide, we'll:
  * Set up a Virtual Machine using the Oracle Cloud Infrastructure, including firewall rules
  * Prepare and use SSH to connect to the Virtual Machine
  * Update the Operating System and install the Valheim Dedicated Server software
  * Finally we'll use Systemd to allow the server to run automatically.

If you have the knowledge of setting up a server on an alternative cloud provider or your own hardware you may skip ahead to [Installing the Valheim Dedicated Server](#Installing-the-Valheim-Dedicated-Server)



# Pre-requisite
## Windows
To connect to the server in the section [Connecting to the VM Instance](##-Connecting-to-the-VM-Instance) we need to do some preparation.
1. First of all we need an SSH client, namely Putty
2. Head on over to https://www.putty.org/ and click on the **Download PuTTY** link
3. Scroll down to **Alternative binary files**
    1. click on **putty.exe** (64-bit x86)
    2. next scroll down and you'll find **puttygen** click on **puttygen.exe** (64-bit x86)
4. Open up **puttygen**
    1. Press **Generate**
    2. Copy the whole SSH key starting at ssh-rsa, we'll need this in the next section when [Creating the VM Instance](###-Creating-the-VM-instance)
    3. Press **Save public key** and save it to f.ex your Desktop
    3. Press **Save private key** and save it to f.ex your Desktop  
        It will ask about password protecting the key, this isn't necessary for this setup.

## Mac / Linux
Verify that we have a set of SSH key pairs
1. Open a terminal
2. Run the command `ls -l ~/.ssh/`.  
    If you see the files `id_rsa` and `id_rsa.pub`, you can continue on with [OCI (Oracle Cloud Infrastructure)](##-OCI-(Oracle-Cloud-Infrastructure))
3. If you did not see these files, you can run the command `ssh-keygen -N '' -f ~/.ssh/id_rsa`
    Now you can re-run the command from step **2** and you should see both files.



# OCI (Oracle Cloud Infrastructure)
1. Head on over to https://cloud.oracle.com/ to sign up for a free account.  
    After logging in you will be shown a **Get Started** page.  
    All subsequent section starts from **Getting Started**.


## Creating the VM instance
1. From the Getting Started dashboard, scroll down a bit and click the **Create a VM instance**
2. On the right hand side of **Image and shape** click **Edit**
    1. Click **Change image** and choose a **Canonical Ubuntu 22.04 Minimal aarch64** and confirm with the **Select image** button.  
    **Note:** make sure you select **aarch64** which is aimed at ARM server
    2. Click **Change shape** and set the following:
        * Instance type: `Virtual machine`
        * Shape series: `Ampere`
        * Shape: `VM.Standard.A1.Flex`
        * OCPUs: `4`
        * Memory: `24GB`
3. On the right hand side of **Networking** click **Edit**
    1. Select **Create new virtual cloud network** and leave the values as is.
4. On the right hand side of **Add SSH keys** click **Edit**
    * If you're f.ex on Linux or Mac you can find your SSH keys under `~/.ssh/id_rsa.pub`
      In this case you can select **Upload public key files (.pub)** then navigate to `~/.ssh/id_rsa.pub`
    * For Windows, the SSH public key we copied in [Pre-requisite for Windows](###-Pre-requisite-for-Windows) can be pasted in by under **Paste public keys**
5. Click **Create**.  
    **Note**: If you get a warning about Out of Capacity, scroll up to the **Placement** section and try another Domain (AD 1, AD 2 or AD 3), and try again.  
    This will take a couple of minutes while the instance is being provisioned / set up.  
    While we wait for it we'll go back to the dashboard and set up the networking.  
    Click on the **ORACLE Cloud** header or [click here](https://cloud.oracle.com/) to go back to the Getting started page.


## Configuring the Network and firewall rules
1. At the top of the Getting started page, click on **Dashboard**
2. Under **Resource explorer**, click **Virtual Cloud Networks**, then click the network (f.ex `vcn-20221120-1500`)
3. On the left hand side, click on **Security Lists**, then the `Default Security List for NETWORKNAME`
4. We will be creating a rule so that we can connect to the server from Valheim.
    1. Under **Ingress Rules**, click **Add Ingress Rules**:
        * Source Type: `CIDR`
        * Source CIDR: `0.0.0.0/0`
        * IP Protocol: `UDP`
        * Source Port Range: `All`
        * Destination Port Range `2456-2459`
5. Click on the **ORACLE Cloud** header or [click here](https://cloud.oracle.com/) to go back to the Getting started page.
6. Navigate back to the Dashboard, under the **Resource explorer** click on **Instances** then the instance (f.ex `instance-20221120-1503`)
7. On the right hand side you'll see **Instance access**, click **Copy** to the right of **Public IP address**, we need this in the next step.


# Connecting to the VM Instance
The IP Address we copied in the previous step will be referenced here as `IP_ADDRESS`
## Windows
1. Start **putty** which we downloaded in [Pre-requisite for Windows](###-Pre-requisite-for-Windows)
2. We'll configure the following parameters:
    * Host Name (or IP address): `IP_ADDRESS`
    * Port: `22`
    * Saved Sessions: `Valheim Server`
    * Close window on exit: `Never`
    * Click **Save**
3. Next in the navigation tree to the left go to **Connection** > **SSH** > **Auth** > **Credentials**
    1. Under **Private key file for authentication** click **Browse...** and navigate to the Private key we saved using **puttygen**
4. Go back up in the navigation tree to **Session** and click **Save**
5. Then click *Open*
6. You should within a couple of seconds see a prompt along the lines of `ubuntu@instance-20221120-1503:~$ `
7. You're now good to go to [Installing the Valheim Dedicated Server](#Installing-the-Valheim-Dedicated-Server)

## Mac / Linux
1. On Mac and Linux we already have an SSH client installed.
2. Open up a terminal then execute `ssh ubuntu@IP_ADDRESS`
3. You should within a couple of seconds see a prompt along the lines of `ubuntu@instance-20221120-1503:~$ `
4. You're now good to go to [Installing the Valheim Dedicated Server](#Installing-the-Valheim-Dedicated-Server)



# Installing the Valheim Dedicated Server
1. Run the following command:
    ```bash
    wget https://raw.githubusercontent.com/husjon/valheim_server_oci_setup/refs/heads/main/setup_valheim_server.sh
    ```
    This will download the installation script onto your server allowing it to set up everything which is needed.

2. Then run the following command:
    ```bash
    bash ./setup_valheim_server.sh
    ```
    The first time this is run, the setup script will update the operating system and then reboot.
    If you get notification about kernel upgrades, or restarting services you may just press `Enter`, allowing the default values be.
    After it's done you will be disconnected, wait about 15-20 seconds then reconnect to the server.

3. Run the same command again
    ```bash
    bash ./setup_valheim_server.sh
    ```
    **Note:** If you're playing on Console or Xbox Game Pass / Microsoft Game Pass, please enable Crossplay.  
    Also, read the [Crossplay](#crossplay-console--game-pass) section.

    The installation will take a couple of minutes to complete as the script installs all the necessary packages and set up the server with initial values.  
    Once it finishes it let you know that we need to make a small edit to one file then start the server.



# Configuring the Valheim Server
1. Open up the **server_credentials** file with `nano ~/server_credentials` (or text editor of choice)
2. Adjust the **SERVER_NAME**, **WORLD_NAME** **PASSWORD**, **PUBLIC** as you see fit.  
    **Note**: The setup script populated the password field automatically with a random decently strong password.
3. When done, Press `Ctrl+X`, then `y` and finally `Enter`.  
    **Note**: Mac users might need to use the `Cmd` button instead of `Ctrl`



# Starting the Valheim Server
To start the server, run the command `valheim_server start`  
This will take a couple of minutes as the world is being generated.

From within the game, it might not show in the **Select Server** list, instead click the **Add server** button and type in the address `IP_ADDRESS:2456` (Using the IP address from[Configuring the Network and firewall rules](###-Configuring-the-Network-and-firewall-rules))

More information can be found in the attached Readme.md file and can be viewed with `cat ~/Readme.md`



# Updating the Valheim Server
Whenever the Valheim client updates, the server also needs to be updated.  
To do this, log onto the VM then run the command `valheim_server update`  
This will stop the running server and update the server files.  
Once done, you must start the server using `valheim_server start`



# Crossplay (Console / Game Pass)
**Note**: Crossplay on ARM architecture is currently experimental (thanks to **@bitdo1**).  

~~During setup you will be asked if crossplay should be enabled or disabled.~~  
The question for enabling crossplay has been disabled due to instability.  
If however you'd like to try it out, the following command can be run:

```sh
CROSSPLAY_SUPPORT=true bash ./setup_valheim_server.sh
```
This will configure the server to allow for crossplay support.  
Do keep in mind that this is experimental and might cause the server to crash.  
If this is the case, re-running the install script as described in [Installing the Valheim Dedicated Server](#installing-the-valheim-dedicated-server) will restore it.


~~If you'd like to enable / disable this after the first setup, you can change it by rerunning the setup script.~~
~~You will need to restart the server for this to take effect using `valheim_server restart `~~

After crossplay has been enabled, the join procedure is the same as normal using `IP:port`, however you can now also join by using a 6 digit code which can be found in the logs after the server has started (using the `valheim_server logs-live` command).  
Example log message:  
`Session "My Valheim server" with join code 295265 and IP 12.34.56.78:2456 is active with 0 player(s)`

**Note:** Do keep in mind that the join code will change every time the server is restarted!



# Modding
[BepInEx](https://github.com/BepInEx/BepInEx) currently do not support ARM, hence modding currently seem to not be possible.  
If this changes in the future, this section will be updated to reflect that.  
An issue has been raised with BepInEx and can be found here [BepInEx/BepInEx#336](https://github.com/BepInEx/BepInEx/issues/336)

PS: If you're willing to try to install mods on your ARM instance and are able to so successfully, please do let me know.

As for a guide to install mods, here is one.  
https://www.youtube.com/watch?v=h2t9cSFidt0




# Installer Self-update
The `setup_valheim_server.sh` now has a self-update feature which allow it to update itself and apply any bugfixes that should be necessary whenever the script is run.

After updating, it will show what have changed, update itself, then ask the user to restart the setup script.  
It is not retroactively applied, hence the script will need to be downloaded again f.ex with:
```bash
wget https://raw.githubusercontent.com/husjon/valheim_server_oci_setup/refs/heads/main/setup_valheim_server.sh -O ~/setup_valheim_server.sh
```
This will overwrite the existing script.

This feature was added **Thu, 15 Dec 2022 19:56:51 +0100**.



# Adding Pre-existing worlds
If you already have a world you've played on (f.ex hosted on your own computer) and you'd like to continue using it with this server,  
the following steps can be used.
1. Locate your save folder, navigate to this folder:  
The files we are interested in are the `.db` and `.fwl` files.
    * Windows: `%userprofile%/AppData/LocalLow/IronGate/Valheim/Worlds`
    * Linux: `$HOME/.config/unity3d/IronGate/Valheim/worlds`
2. Stop the Valheim Server with `valheim_server stop`
3. With an SFTP client (f.ex FileZilla), upload the `.db` and `.fwl` file to the folder: `/home/${USER}/valheim_data`
4. Edit the `~/server_credentials` and update the `WORLD_NAME` parameter to the name of your World files.  
F.ex if you world file was `My_Valheim_World.db` and `My_Valheim_World.fwl`, set it to `WORLD_NAME="My_Valheim_World"`
5. Start the Valheim Server with `valheim_server start`
6. Within a few moments the server should be back up and running with the world you uploaded.



# Troubleshooting
In case you should experience any issues and would need some assistance, the install logs and server logs are helpful to troubleshoot the issue.

To help with this the following steps should be followed:
1. Create a log output of the running server using the following command:  
`journalctl --no-pager --since=-1d --user -u valheim_server > ~/valheim_server.systemd.log`  
This will take a snapshot of the logs from the Valheim Server from the last 24 hours.  
In case the Valheim server was never started, this can be omitted.
2. Download the `install_valheim_server.log` and `valheim_server.systemd.log` file located under `/home/ubuntu` using f.ex [FileZilla](https://filezilla-project.org/download.php?type=client).  
  **Note:** Use port 22 for SFTP/SSH.
3. Go to https://gist.github.com/, click **Add File** for each file, then **Create Public / Secret Gist**  
This creates a gist (similar to this guide) which we can go through to troubleshoot.
4. Copy the URL to the gist and create a comment down below describing the issue and adding the link to the gist.

I might be delayed due to work / timezones etc, but hoping to get you going as quickly as possible.


## Discord
I've decided to open up my discord server so if you need help or would like to suggest improvements or similar, please tag along.  
https://discord.gg/ExnzM4E7pE


# Changing versions
This could be useful in case the public version breaks something.
Make sure you create a backup of the server before switching versions.

## Switcing to the Previous Stable Version
1. Run SteamCMD to change to the `default_old` branch
```bash
cd ~/steamcmd

./steamcmd.sh \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir "/home/$USER/valheim_server" \
    +login anonymous \
    +app_update 896660 -beta default_old validate \
    +quit
```
3. In Steam, right-click the game, open Properties, go to Betas and select `default_old` from the dropdown and wait for the game to update (this might take a few minutes).
4. Start the game and connect to your server as normal.


## Switching to the Public Beta Branch
1. Run SteamCMD to change to the `public-test` branch
```bash
cd ~/steamcmd

./steamcmd.sh \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir "/home/$USER/valheim_server" \
    +login anonymous \
    +app_update 896660 -beta public-test -betapassword yesimadebackups validate \
    +quit
```
3. In Steam, right-click the game, open Properties, go to Betas and select `public-test` from the dropdown and wait for the game to update (this might take a few minutes).  
   If `public-test` is not in the list, type in `yesimadebackups` in the Input field below and press **Check Code**.
4. Start the game and connect to your server as normal.


## Reverting back to the public version
1. Run SteamCMD to change to the `public` branch
```bash
cd ~/steamcmd

./steamcmd.sh \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir "/home/$USER/valheim_server" \
    +login anonymous \
    +app_update 896660 -beta public validate \
    +quit
```
3. In Steam, right-click the game, open Properties, go to Betas and select `None` from the dropdown and wait for the game to update (this might take a few minutes).
4. Start the game and connect to your server as normal.


# Oracle and Reclamation of Idle Compute Instances
Oracle have a policy on their Always Free instances whichs allows them to reclaim instances that are idle or using less than a certain percentile (See: [Always_Free_Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#compute__idleinstances)).

For the most part using the server should not trigger this.

If the server should be flagged for reclaimation, you'll receive an email saying that it has been flagged for being idle for the last 7 days.  
Next it will say that if it continues for another 7 days, the server will be stopped.  
This gives us ample time to either back up the data or continue playing.

The only thing needed to do is to log onto your Oracle Cloid Infrastructure, go to your Instances and click the Restart button, this will pause the reclaimation.



# TODOs
* ~~Add ability to update the Valheim server prior to starting the server.~~  
**Tue, 24 Jan 2023 23:01:18 +0100**  
Now part of the `valheim_server` helper command.

* ~~Add information about adding pre-existing worlds~~  
**Tue, 24 Jan 2023 22:47:19 +0100**

* ~~Add support for users other than `ubuntu`~~  
**Tue, 24 Jan 2023 22:33:56 +0100**  
Made it so that the install script no longer is tied to the `ubuntu` user.
