FROM archlinux:latest

# Update packages and install necessary dependencies
RUN pacman -Syu --noconfirm && \
    pacman -Sy --noconfirm base-devel openssl wget git sudo openssh && \
    useradd -m -G wheel -s /bin/bash arch-torification && \
    sed -i "/^#.*%wheel.*ALL=(ALL:ALL).*ALL/s/^#//" /etc/sudoers && \
    echo "Uncommented %wheel ALL=(ALL:ALL) ALL in sudoers file." || \
    echo "%wheel ALL=(ALL:ALL) ALL is already uncommented in sudoers file."

# Copy SSH private key and set permissions
ARG BASE64_PRIVATE_KEY
RUN mkdir -p /root/.ssh && \
    echo "$BASE64_PRIVATE_KEY" | base64 --decode > /root/.ssh/jenil && \
    chmod 600 /root/.ssh/jenil

# Set up SSH agent and add SSH key
RUN eval $(ssh-agent -s) && \
    ssh-add /root/.ssh/jenil && \
    ssh-add -l && \
    whoami

# Clone repository, perform operations, and push changes
RUN git clone ssh://aur@aur.archlinux.org/arch-torification.git && \
    cd arch-torification && \
    sudo rm -rf * && \
    wget https://raw.githubusercontent.com/jenil1122/Arch-torification/master/PKGBUILD && \
    makepkg --printsrcinfo > .SRCINFO && \
    git add PKGBUILD .SRCINFO && \
    git commit -m "update" && \
    git push
