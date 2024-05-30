# Maintainer: Jenil 
pkgname=arch-torify
pkgver=1.0
pkgrel=1
pkgdesc="Arch-torification boosts Linux security by leveraging the power of Tor for anonymized network communication. Built on the Arch Linux distribution, this tool seamlessly integrates Tor routing into the system, ensuring all network traffic is encrypted and routed through the Tor network for maximum privacy."
arch=('x86_64')
url="https://github.com/jenil1122/Arch-torification"
license=('GPL3')
depends=('tor' 'iptables')
source=("https://github.com/jenil1122/Arch-torification/releases/download/${pkgver}/arch-torify")
sha256sums=('SKIP') # Since GitHub releases already provide checksums

package() {
    install -Dm4755 arch-torify "${pkgdir}/usr/bin/arch-torify" # Set suid bit for root permission
    # Update the shell's cache
    hash -r
}
