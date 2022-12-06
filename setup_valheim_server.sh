#!/bin/bash


function main {
    # Stop on error
    set -e
    cd

    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    ORANGE=$(tput setaf 3)
    BOLD=$(tput bold)
    CLEAR=$(tput sgr0)

    function warn { echo -en "\n\n${BOLD}${ORANGE}[-] $* ${CLEAR}\n"; }
    function success { echo -en "${BOLD}${GREEN}[+] $* ${CLEAR}\n"; }
    function info { echo -en "\n\n${BOLD}[ ] $* ${CLEAR}\n"; }
    function error { echo -en "${BOLD}${RED}[!] $* ${CLEAR}\n"; }
    function notify { echo -en "\n\n${BOLD}${ORANGE}[!] $* ${CLEAR}\n"; }


    while :; do
        echo "This script will install the Valheim Dedicated server "
        echo -n "Are you sure? [yes/no]  "

        read -r answer

        case $answer in
            YES|Yes|yes|y)
                break;;
            NO|No|no|n)
                echo Aborting; exit;;
        esac
    done

    echo

    while :; do
        echo "Should this server use crossplay?"
        echo -n "[yes/no]  "

        read -r answer

        case $answer in
            YES|Yes|yes|y)
                CROSSPLAY_SUPPORT=true
                break;;
            NO|No|no|n)
                CROSSPLAY_SUPPORT=false
                break;;
        esac
    done



    # Update and upgrade the system
    if [[ ! -f ~/.cache/valheim_server_setup ]]; then
        info "First time setup"
        info "Adding Architecture"
        sudo apt -y update
        sudo dpkg --add-architecture armhf

        info "Updating and upgrading the OS"
        sudo apt -y update
        sudo apt -y upgrade && touch ~/.cache/valheim_server_setup
        success "Updating and upgrading the OS - Done"
        sudo reboot
        warn "Rebooting..."
    fi



    # Prepare box86 and box64
    info "Installing required packages"
    sudo apt -y install \
        git \
        build-essential \
        cmake \
        gcc-arm-linux-gnueabihf \
        libc6:armhf \
        libncurses5:armhf \
        libstdc++6:armhf && \
        success "Installing required packages - Done"


    if uname -p | grep "aarch64" > /dev/null; then
        notify "Found system to be 64bit Arm"
        # Fetch and build Box 86 and 64
        for ARCH in {86,64}; do
            cd
            if [[ ! -d "$HOME/box${ARCH}" ]]; then
                info "Fetching Box${ARCH}"
                git clone "https://github.com/ptitSeb/box${ARCH}" && \
                    mkdir -p "box${ARCH}/build"
                success "Fetching Box${ARCH} - Done"
            fi

            info "Building Box${ARCH}"
            cd "$HOME/box${ARCH}/build"
            git checkout $(git tag | tail -n 1)
            cmake .. -DRPI4ARM64=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo
            make -j"$(nproc)" && success "Building Box${ARCH} - Done"

            info "Installing Box${ARCH}"
            sudo make install && success "Installing Box${ARCH} - Done"
        done
        sudo systemctl restart systemd-binfmt.service
    fi



    # Fetch and initialize steamcmd
    if [[ ! -f ~/steamcmd/steamcmd.sh ]]; then
        info "Fetching steamcmd"
        mkdir -p ~/steamcmd && \
            cd ~/steamcmd && \
            curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
        ./steamcmd.sh +quit && success "Fetching steamcmd - Done"
    fi



    # Install the Valheim Dedicated Server from Steam
    if [[ ! -f ~/valheim_server/start_server.sh ]]; then
        info "Installing Valheim Dedicated Server"
        cd ~/steamcmd
        ./steamcmd.sh \
            +@sSteamCmdForcePlatformType linux \
            +login anonymous \
            +force_install_dir /home/ubuntu/valheim_server \
            +app_update 896660 validate \
            +quit && \
                success "Installing Valheim Dedicated Server - Done"
    fi



    # Initialize the Server Credentials file
    if [[ ! -f ~/server_credentials ]]; then
        info "Generating server_credentials file"
        PASSWORD="$(tr -dc "a-zA-Z0-9" < /dev/urandom | fold -w "32" | head -n 1)"
        cat <<-EOF > ~/server_credentials && success "Done"
			SERVER_NAME="My server"
			WORLD_NAME="My World"

			# NOTE: Minimum password length is 5 characters & Password cant be in the server name.
			PASSWORD="${PASSWORD}"

			# If the server should be listed publically. (1=yes, 0=no)
			PUBLIC=0

			PORT=2456
		EOF
        success "Generating server_credentials file - Done"
    fi



    # Update firewall
    info "Updating firewall rules"
    RULES=(
        "INPUT -p udp -m state --state NEW -m udp --dport 2456 -j ACCEPT"
        "INPUT -p udp -m state --state NEW -m udp --dport 2457 -j ACCEPT"
        "INPUT -p udp -m state --state NEW -m udp --dport 2458 -j ACCEPT"
    )
    FIREWALL_RULES_ADDED=false
    for RULE in "${RULES[@]}"; do
        sudo iptables -C ${RULE} 2> /dev/null || \
            sudo iptables -I ${RULE} && FIREWALL_RULES_ADDED=true
    done
    if $FIREWALL_RULES_ADDED; then
        sudo cp /etc/iptables/rules.v4{,.bak}
        TMP_FILE=$(mktemp)
        sudo iptables-save > "${TMP_FILE}"
        sudo mv "${TMP_FILE}" /etc/iptables/rules.v4
    fi
    success "Done"



    # Set up the Systemd Service
    info "Setting up Systemd Service"
    mkdir -p ~/.config/systemd/user/

    [[ $CROSSPLAY_SUPPORT == true ]] && CROSSPLAY="-crossplay"
    # Add servicefile
    cat <<-EOF > ~/.config/systemd/user/valheim_server.service
		[Unit]
		Description=Valheim Dedicated Server

		[Service]
		KillSignal=SIGINT
		TimeoutStopSec=30

		Restart=always
		RestartSec=5

		WorkingDirectory=/home/ubuntu/valheim_server
		EnvironmentFile=/home/ubuntu/server_credentials

		Environment=SteamAppId=892970
		Environment=LD_LIBRARY_PATH="./linux64:\$LD_LIBRARY_PATH"

		ExecStart=/home/ubuntu/valheim_server/valheim_server.x86_64 \\
		    -nographics \\
		    -batchmode \\
		    -port "\${PORT}" \\
		    -public "\${PUBLIC}" \\
		    -name "\${SERVER_NAME}" \\
		    -world "\${WORLD_NAME}" \\
		    -password "\${PASSWORD}" \\
		    ${CROSSPLAY} \\
		    -savedir "/home/ubuntu/valheim_data"

		[Install]
		WantedBy=default.target
	EOF

    # Reload Systemd
    systemctl --user daemon-reload

    # Enable Valheim Systemd service allowing it to start automatically on boot
    systemctl --user enable valheim_server.service && success "Setting up Systemd Service - Done"



    info "Creating Readme"
	cat <<-EOF > ~/Readme.md && success "Creating Readme - Done"
		# Start server
		systemctl --user start valheim_server.service


		# Restart server
		systemctl --user restart valheim_server.service


		# Stop server
		systemctl --user stop valheim_server.service


		# Viewing logs server
		## live logs
		journalctl --user -f -u valheim_server.service

		## full logs
		journalctl --user -u valheim_server.service


		# Updating the server
		systemctl --user stop valheim_server

		cd ~/steamcmd
		time ./steamcmd.sh \\
		            +@sSteamCmdForcePlatformType linux \\
		            +login anonymous \\
		            +force_install_dir /home/ubuntu/valheim_server \\
		            +app_update 896660 \\
		            +quit

		systemctl --user start valheim_server


		# Enable / Disable crossplay
		This can be accomplished by re-running the setup script.
		It will ask you of you want crossplay enabled or disabled.
	EOF



    # Start the Valheim Systemd service
    success "Setup finished"
    echo "A file named 'server_credentials' have been placed in the home directory"
    echo "Edit as you see fit with f.ex 'nano ~/server_credentials'"
    echo "Within nano, when done editing, press 'Ctrl+X', then 'y', finally 'Enter'"
    echo
    echo "Finally, to start the server, the following command can be used:"
    echo "  systemctl --user start valheim_server.service"
    echo
    echo "A readme with additional commands have also been placed in the home directory"
}

main | tee install_valheim_server.log
