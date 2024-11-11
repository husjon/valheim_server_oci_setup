#!/bin/bash

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


function perform_self_update {
    SETUP_SCRIPT_URL="https://gist.github.com/husjon/c5225997eb9798d38db9f2fca98891ef/raw/setup_valheim_server.sh"

    ETAG_CACHE="${HOME}/.cache/setup_valheim_server.etag"
    SETUP_SCRIPT_PATH="$(realpath "$0")"

    TEMP_SCRIPT_PATH="$(mktemp)"

    info "Checking for setup script updates"

    curl --silent --etag-save "${ETAG_CACHE}" --etag-compare "${ETAG_CACHE}" -L "${SETUP_SCRIPT_URL}" -o "${TEMP_SCRIPT_PATH}"

    if [[ -s "${TEMP_SCRIPT_PATH}" ]]; then
        if ! cmp --silent $SETUP_SCRIPT_PATH $TEMP_SCRIPT_PATH; then
            echo "Setup script available, updating..."

            notify "Changes (< = removed  |  > = added):"
            diff --color --minimal "${SETUP_SCRIPT_PATH}" "${TEMP_SCRIPT_PATH}"
            echo
            sleep 1
            mv "${TEMP_SCRIPT_PATH}" "${SETUP_SCRIPT_PATH}"
            success "Updated setup script."
            notify "Please re-run the setup script..."
            echo
            exit 0
        fi
    fi

    success "No update available"
    echo
    rm -f "${TEMP_SCRIPT_PATH}"
}


function main {
    # Stop on error
    set -e

    if [[ $(lsb_release -rs) != '22.04' ]]; then
        error "The release \"$(lsb_release  -ds 2>/dev/null)\" is not supported, please re-install using Ubuntu 22.04 LTS."
        echo "See https://gist.github.com/husjon/c5225997eb9798d38db9f2fca98891ef#ubuntu-version for more information"
        echo
        exit 1
    fi

    cd

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
        echo "Note: this is currenly highly experimental"
        echo -n "[yes/no] (default: no)  "

        read -r answer

        case $answer in
            YES|Yes|yes|y)
                CROSSPLAY_SUPPORT=true
                break;;
            NO|No|no|n|*)
                CROSSPLAY_SUPPORT=false
                break;;
        esac
    done



    # Update and upgrade the system
    mkdir -p ~/.cache
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
        build-essential \
        cmake \
        gcc-arm-linux-gnueabihf \
        git \
        libc6:armhf \
        libncurses6 \
        libstdc++6 \
        libpulse0 && \
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
            git fetch
            if [[ $ARCH == 64 ]] && [[ -n $BOX64_VERSION ]]; then
                TAG="${BOX64_VERSION}"
            elif [[ $ARCH == 86 ]] && [[ -n $BOX86_VERSION ]]; then
                TAG="${BOX86_VERSION}"
            else
                TAG="$(git tag | tail -n 1)"
            fi

            git checkout "${TAG}"
            cmake .. -DRPI4ARM64=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo
            make -j"$(nproc)" && success "Building Box${ARCH} - Done"

            info "Installing Box${ARCH}"
            sudo make install && success "Installing Box${ARCH} - Done"
        done
        sudo systemctl restart systemd-binfmt.service

        if ! grep -F '[valheim_server.x86_64]  #box64 v0.2.6' ~/.box64rc; then
            info "Adding box64 configuration"
            cat <<-EOF | tee -a ~/.box64rc
			[valheim_server.x86_64]  #box64 v0.2.6
			BOX64_DYNAREC_BLEEDING_EDGE=0
			BOX64_DYNAREC_STRONGMEM=3
			EOF
        fi
    fi



    # Fetch and initialize steamcmd
    if [[ ! -f ~/steamcmd/steamcmd.sh ]]; then
        info "Fetching steamcmd"
        mkdir -p ~/steamcmd && \
            cd ~/steamcmd && \
            curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
        ./steamcmd.sh +quit && success "Fetching steamcmd - Done"
    fi
    # Add steamcmd steamclient.so symlink
    info "Adding steamclient.so symlink"
    mkdir -p ~/.steam/sdk64 && ln -frs ~/steamcmd/linux64/steamclient.so ~/.steam/sdk64/



    # Install the Valheim Dedicated Server from Steam
    if [[ ! -f ~/valheim_server/start_server.sh ]]; then
        info "Installing Valheim Dedicated Server"
        cd ~/steamcmd
        ./steamcmd.sh \
            +@sSteamCmdForcePlatformType linux \
            +force_install_dir "/home/$USER/valheim_server" \
            +login anonymous \
            +app_update 896660 validate \
            +quit && \
                success "Installing Valheim Dedicated Server - Done"
    fi



    # Add x86_64 version of libpulse-mainloop-glib.so.0
    if [[ $CROSSPLAY_SUPPORT == true ]]; then
        if [[ ! -f ~/valheim_server/linux64/libpulse-mainloop-glib.so.0 ]]; then
            info "Installing libpulse-mainloop-glib.so.0:x86_64"
            pushd "$(mktemp -d)"
            wget http://mirrors.kernel.org/ubuntu/pool/main/p/pulseaudio/libpulse-mainloop-glib0_15.99.1+dfsg1-1ubuntu1_amd64.deb
            dpkg -x libpulse-mainloop-glib0_15.99.1+dfsg1-1ubuntu1_amd64.deb ./ && \
                cp usr/lib/x86_64-linux-gnu/libpulse-mainloop-glib.so.0 "/home/$USER/valheim_server/linux64/"
            success "Installing libpulse-mainloop-glib.so.0:x86_64 - Done"
            popd
        fi
    else
        rm -f "/home/$USER/valheim_server/linux64/libpulse-mainloop-glib.so.0"
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



    # Add Valheim helper
    info "Creating Valheim Server helper"
    mkdir -p /usr/sbin
    cat <<-EOF | sudo tee /usr/sbin/valheim_server > /dev/null
		#!/bin/bash

		# Stop on error
		set -e

		function show_usage {
		    echo "Usage:  \$(basename \$0) COMMAND"
		    echo
		    echo "Commands:"
		    echo "  update      Stops and Updates the Valheim server"
		    echo "  start       Start the Valheim server"
		    echo "  stop        Stops the Valheim server"
		    echo "  restart     Restart the Valheim server"
		    echo "  logs        Shows the logs of the Valheim server"
		    echo "  logs-live   Shows the live logs of the Valheim server"
		    echo "  help        Shows this help message"
		    echo
		}

		function start_server {
		    if ! systemctl --user --quiet is-active valheim_server; then
		        echo "Starting Server..."
		        systemctl --user start valheim_server

		        sleep 2     # sleeping to allow service to start up before validating.

		        systemctl --user --quiet is-active valheim_server && \
		            echo "Server Started"
		    else
		        echo "Server already running"
		    fi
		}

		function stop_server {
		    if systemctl --user --quiet is-active valheim_server; then
		        echo "Stopping Server, please wait..."
		        systemctl --user stop valheim_server
		        echo "Server Stopped"
		    else
		        echo "Server already stopped"
		    fi
		}

		function restart_server {
		    stop_server && start_server
		}


		case \$1 in
		    update)
		        stop_server

		        /home/\${USER}/steamcmd/steamcmd.sh \\
		            +@sSteamCmdForcePlatformType linux \\
		            +force_install_dir "/home/\${USER}/valheim_server" \\
		            +login anonymous \\
		            +app_update 896660 validate \\
		            +quit
		        echo
		        echo "Server updated."
		        echo "Start the server with \"valheim_server start\""
		    ;;

		    start|stop|restart)
		        \${1}_server;;
		    logs)
		        journalctl --user -u valheim_server;;
		    logs-live)
		        journalctl --user -f -u valheim_server;;
		    help|--help|-h|*)
		        show_usage;;
		esac
	EOF
    sudo chmod +x /usr/sbin/valheim_server



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

		WorkingDirectory=/home/${USER}/valheim_server
		EnvironmentFile=/home/${USER}/server_credentials

		Environment=SteamAppId=892970
		Environment=LD_LIBRARY_PATH="./linux64:\$LD_LIBRARY_PATH"

		ExecStart=/home/${USER}/valheim_server/valheim_server.x86_64 \\
		    -nographics \\
		    -batchmode \\
		    -port "\${PORT}" \\
		    -public "\${PUBLIC}" \\
		    -name "\${SERVER_NAME}" \\
		    -world "\${WORLD_NAME}" \\
		    -password "\${PASSWORD}" \\
		    ${CROSSPLAY} \\
		    -savedir "/home/${USER}/valheim_data"

		[Install]
		WantedBy=default.target
	EOF

    # Enable Lingering Systemd user sessions
    loginctl enable-linger

    # Reload Systemd
    systemctl --user daemon-reload

    # Enable Valheim Systemd service allowing it to start automatically on boot
    systemctl --user enable valheim_server.service && success "Setting up Systemd Service - Done"



    info "Creating Readme"
	cat <<-EOF > ~/Readme.md && success "Creating Readme - Done"
		# Valheim Server Helper Commands
		## Help
		valheim_server help

		## Start server
		valheim_server start

		## Stop server
		valheim_server stop

		## Updating the server
		valheim_server upgrade


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
    echo "  valheim_server start"
    echo
    echo "A readme with additional commands have also been placed in the home directory"
}

if [ `id -u` -eq 0 ]; then
    error Please run this script as a regular user.

    exit 1
fi

perform_self_update


# Pinned versions for Box 64 / 86
BOX64_VERSION="v0.2.6"
BOX86_VERSION="v0.3.6"

main | tee install_valheim_server.log
