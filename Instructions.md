# Credit
The original guide is from Reddit user That_Conversation_91 on [r/Valheim](https://www.reddit.com/r/valheim/).  
Original post can be found [here](https://www.reddit.com/r/valheim/comments/s1os21/create_your_own_free_dedicated_server)


# Instructions
**Note**: For this guide a free account is required on the Oracle Cloud Infrastructure allowing us to spin up a server which is decently specced.  
If you have the knowledge of setting up a server on an alternative cloud provider or your own hardware you may skip ahead to [Installing the Valheim Dedicated Server](#Installing-the-Valheim-Dedicated-Server)

## OCI (Oracle Cloud Infrastructure)
1. Head on over to https://cloud.oracle.com/ to sign up for a free account.  
    After logging in you will be shown a **Get Started** page.  
    All subsequent section starts from **Getting Started**.

### Pre-requisite for Windows
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


### Creating the VM instance
1. From the Getting Started dashboard, scroll down a bit and click the **Create a VM instance**
2. On the right hand side of **Image and shape** click **Edit**
    1. Click **Change image** and choose **Canonical Ubuntu** and confirm with the **Select image** button.
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
    This will take a couple of minutes while the instance is being provisioned / set up.  
    While we wait for it we'll go back to the dashboard and set up the networking.  
    Click on the **ORACLE Cloud** header or [click here](https://cloud.oracle.com/) to go back to the Getting started page.


### Configuring the Network and firewall rules
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


## Connecting to the VM Instance
The IP Address we copied in the previous step will be referenced here as `IP_ADDRESS`
### Windows
1. Start **putty** which we downloaded in [Pre-requisite for Windows](###-Pre-requisite-for-Windows)
2. We'll configure the following parameters:
    * Host Name (or IP address): `IP_ADDRESS`
    * Port: `22`
    * Saved Sessions: `Valheim Server`
    * Click **Save**
3. Next in the navigation tree to the left go to **Connection** > **SSH** > **Auth** > **Credentials**
    1. Under **Private key file for authentication** click **Browse...** and navigate to the Private key we saved using **puttygen**
4. Go back up in the navigation tree to **Session** and click **Save**
5. Then click *Open**
6. You should within a couple of seconds see a prompt along the lines of `ubuntu@instance-20221120-1503:~$ `
7. You're now good to go to [Installing the Valheim Dedicated Server](#Installing-the-Valheim-Dedicated-Server)

### Mac / Linux
1. On Mac and Linux we already have an SSH client installed.
2. Open up a terminal then execute `ssh ubuntu@IP_ADDRESS`
3. You should within a couple of seconds see a prompt along the lines of `ubuntu@instance-20221120-1503:~$ `
4. You're now good to go to [Installing the Valheim Dedicated Server](#Installing-the-Valheim-Dedicated-Server)



## Installing the Valheim Dedicated Server
1. Run the following command:
    ```bash
    wget https://gist.github.com/husjon/c5225997eb9798d38db9f2fca98891ef/raw/ea05ecc2cb2f0f9f0923ec467044b12c7681f1f9/setup_valheim_server.sh
    ```
    This will download the installation script onto your server allowing it to set up everything which is needed.

2. Then run the following command:
    ```bash
    bash ./setup_valheim_server.sh
    ```

    This will take a couple of minutes to complete.  
    The script installs all the necessary packages and set up the server with initial values.  
    Once it finishes it let you know that we need to make a small edit to one file then start the server.

## Configuring the Valheim Server
1. Open up the **server_credentials** file with `nano ~/server_credentials` (or text editor of choice)
2. Adjust the **SERVER_NAME**, **WORLD_NAME** **PASSWORD**, **PUBLIC** as you see fit.  
    **Note**: The setup script populated the password field automatically with a random decently strong password.
3. When done, Press `Ctrl+X`, then `y` and finally `Enter`.
    **Note**: Mac users might need to use the `Cmd` button instead of `Ctrl`


## Starting the Valheim Server
To start the server, run the command `systemctl --user start valheim_server`

More information can be found in the attached Readme.md file and can be viewed with `cat ~/Readme.md`