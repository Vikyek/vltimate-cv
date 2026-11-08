# Maintainer: Vikyek <https://github.com/Vikyek>
pkgname=vltimate-cv
pkgver=4.0.0
pkgrel=1
pkgdesc="Open-core proof-of-work technical intelligence harvester and strict ATS resume engine"
arch=('any')
url="https://github.com/Vikyek/vltimate-cv"
license=('MIT')
depends=('bash' 'python' 'git' 'curl' 'openssl')
optdepends=(
    'chromium: headless ATS/ModernCV PDF export'
    'gnupg: GPG vault archive encryption'
    'github-cli: automatic GitHub handle detection'
)
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

package() {
    cd "$pkgname-$pkgver"

    install -Dm755 harvest_cv.sh "$pkgdir/usr/share/$pkgname/harvest_cv.sh"
    install -Dm644 cv_harvester_system_prompt.md "$pkgdir/usr/share/$pkgname/cv_harvester_system_prompt.md"
    install -Dm644 cv_template.html "$pkgdir/usr/share/$pkgname/cv_template.html"

    install -Dm755 scripts/export_profile.py "$pkgdir/usr/share/$pkgname/scripts/export_profile.py"
    install -Dm755 scripts/llm_adapter.py "$pkgdir/usr/share/$pkgname/scripts/llm_adapter.py"

    install -Dm644 config/config.template.env "$pkgdir/usr/share/$pkgname/config/config.template.env"
    install -Dm644 config/pdf_customization.template.json "$pkgdir/usr/share/$pkgname/config/pdf_customization.template.json"
    install -Dm644 config/user_constraints.template.md "$pkgdir/usr/share/$pkgname/config/user_constraints.template.md"

    install -d "$pkgdir/usr/bin"
    ln -s "/usr/share/$pkgname/harvest_cv.sh" "$pkgdir/usr/bin/$pkgname"

    install -Dm644 "man/man1/$pkgname.1" "$pkgdir/usr/share/man/man1/$pkgname.1"
    install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
