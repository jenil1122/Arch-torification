FROM manjarolinux

# Install necessary packages
RUN pacman -Syu --noconfirm && \
    pacman -Sy --noconfirm base-devel openssl wget git sudo openssh

# Create user and setup sudo
RUN useradd -m -G wheel -s /bin/bash arch-torification && \
    sed -i '/^#.*%wheel.*ALL=(ALL:ALL).*ALL/s/^#//' /etc/sudoers

# Mount the secret and perform actions as the arch-torification user
RUN --mount=type=secret,id=BASE64_PRIVATE_KEY 

RUN su arch-torification -c " \
        mkdir -p ~/.ssh && \
        cat /run/secrets/BASE64_PRIVATE_KEY | base64 -d > ~/.ssh/jenil && \
        chmod 600 ~/.ssh/jenil && \
        eval \$(ssh-agent -s) && \
        ssh-add ~/.ssh/jenil && \
        git clone ssh://aur@aur.archlinux.org/arch-torification.git ~/arch-torification && \
        cd ~/arch-torification && \
        wget https://raw.githubusercontent.com/jenil1122/Arch-torification/master/PKGBUILD && \
        makepkg --printsrcinfo > .SRCINFO && \
        git add PKGBUILD .SRCINFO && \
        git commit -m 'update' && \
        git push \
    "
