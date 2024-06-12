# syntax=docker/dockerfile:1.2
# Use archlinux as the base image
FROM archlinux

# Install necessary packages
RUN pacman -Syu --noconfirm && \
    pacman -Sy --noconfirm base-devel openssl wget git sudo openssh

# Create user and setup sudo
RUN useradd -m -G wheel -s /bin/bash arch-torification && \
    sed -i '/^#.*%wheel.*ALL=(ALL:ALL).*ALL/s/^#//' /etc/sudoers

# Mount the secret and perform actions as the arch-torification user
RUN --mount=type=secret,id=BASE64_PRIVATE_KEY \
    BASE64_PRIVATE_KEY=$(cat /run/secrets/BASE64_PRIVATE_KEY) && \
    su arch-torification -c " \
        mkdir -p ~/.ssh && \
        echo $BASE64_PRIVATE_KEY | base64 --decode > ~/.ssh/jenil && \
        chmod 600 ~/.ssh/jenil && \
        eval \$(ssh-agent -s) && \
        ssh-add ~/.ssh/jenil && \
        git clone ssh://aur@aur.archlinux.org/arch-torification.git ~/arch-torification && \
        cd ~/arch-torification && \
        wget https://raw.githubusercontent.com/jenil1122/Arch-torification/master/PKGBUILD && \
        makepkg --printsrcinfo > .SRCINFO && \
        git add PKGBUILD .SRCINFO && \
        git commit -m 'update' && \
        git push"

# Set the default command (optional)
CMD ["/bin/bash"]
