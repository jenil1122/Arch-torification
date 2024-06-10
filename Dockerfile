FROM archlinux:latest

RUN --mount=type=secret,id=BASE64_PRIVATE_KEY \
    export BASE64_PRIVATE_KEY=$(cat /run/secrets/BASE64_PRIVATE_KEY) && \
    echo "$BASE64_PRIVATE_KEY" | base64 --decode > ~/.ssh/jenil && \
    chmod 600 ~/.ssh/jenil && \
    echo "SSH key created at ~/.ssh/jenil" && \
    ls -la ~/.ssh && \
    eval $(ssh-agent -s) && \
    ssh-add ~/.ssh/jenil && \
    ssh-add -l && \
    whoami && \
    git clone ssh://aur@aur.archlinux.org/arch-torification.git && \
    cd arch-torification && \
    sudo rm -rf * && \
    wget https://raw.githubusercontent.com/jenil1122/Arch-torification/master/PKGBUILD && \
    makepkg --printsrcinfo > .SRCINFO && \
    git add PKGBUILD .SRCINFO && \
    git commit -m "update" && \
    git push
