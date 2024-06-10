FROM archlinux:latest

ARG BASE64_PRIVATE_KEY

RUN pacman -Syu --noconfirm \
    && pacman -Sy --noconfirm base-devel openssl wget git sudo openssh \
    && useradd -m -G wheel -s /bin/bash arch-torification \
    && if grep -q "^#.*%wheel.*ALL=(ALL:ALL).*ALL" /etc/sudoers; then \
         sed -i "/^#.*%wheel.*ALL=(ALL:ALL).*ALL/s/^#//" /etc/sudoers \
         && echo "Uncommented %wheel ALL=(ALL:ALL) ALL in sudoers file."; \
       else \
         echo "%wheel ALL=(ALL:ALL) ALL is already uncommented in sudoers file."; \
       fi \
    && echo "$BASE64_PRIVATE_KEY" | base64 --decode > /root/.ssh/jenil \
    && chmod 600 /root/.ssh/jenil \
    && echo "SSH key created at /root/.ssh/jenil" \
    && ls -la /root/.ssh \
    && eval $(ssh-agent -s) \
    && ssh-add /root/.ssh/jenil \
    && ssh-add -l \
    && whoami \
    && git clone ssh://aur@aur.archlinux.org/arch-torification.git \
    && cd arch-torification \
    && sudo rm -rf * \
    && wget https://raw.githubusercontent.com/jenil1122/Arch-torification/master/PKGBUILD \
    && makepkg --printsrcinfo > .SRCINFO \
    && git add PKGBUILD .SRCINFO \
    && git commit -m "update" \
    && git push
