# Credit
The original guide is from Reddit user That_Conversation_91 on [r/Valheim](https://www.reddit.com/r/valheim/).  
Original Post can be found [here](https://www.reddit.com/r/valheim/comments/s1os21/create_your_own_free_dedicated_server)


# Instructions
**Note**: For this guid a free account is required on the Oracle Cloud Infrastructure allowing us to spin up a server which is decently specced.  
If you have the knowledge of setting up a server on an alternative cloud provider or your own hardware you may skip ahead to [Installing the Valheim Dedicated Server](#Installing-the-Valheim-Dedicated-Server)

## OCI (Oracle Cloud Infrastructure)
1. Head on over to https://cloud.oracle.com/ to sign up for a free account.  
    After logging in you will be shown a **Get Started** page.  
    All subsequent section starts from **Getting Started**.

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
    * If you do not have an SSH key pair already set up,  
       select **Generate a key pair for me** and save both the private and public keys to your computer.  
       We'll be using these to connect to the server later on.
5. Click **Create**.  
    This will take a couple of minutes while the instance is being provisioned / set up.  
    While we wait for it we'll go back to the dashboard and set up the networking.  
    Click on the **ORACLE Cloud** header or [click here](https://cloud.oracle.com/) to go back to the Getting started page.


### Configuring the Network and firewall rules
1. At the top of the Getting started page, click on **Dashboard**
2. Under **Resource explorer**, click **Virtual Cloud Networks**, then click the network (f.ex `vcn-20221120-1500`)
3. On the left hand side, click on **Security Lists**, then the `Default Security List for NETWORKNAME`
4. We will be creating a rule for this server so that we can connect to the server.
    1. Under **Ingress Rules**, click **Add Ingress Rules**:
        * Source Type: `CIDR`
        * Source CIDR: `0.0.0.0/0`
        * IP Protocol: `UDP`
        * Source Port Range: `All`
        * Destination Port Range `2456-2459`
5. This concludes all the steps we need to do in Oracle, now it's time to install the Valheim Dedicated Server.


## Installing the Valheim Dedicated Server
