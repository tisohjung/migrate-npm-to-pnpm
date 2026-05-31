class MigrateToPnpm < Formula
  desc "Recursively find and migrate npm projects to pnpm"
  homepage "https://github.com/tisohjung/migrate-npm-to-pnpm"
  url "https://github.com/tisohjung/migrate-npm-to-pnpm/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "23cf5d52ca5c40f9263f9882cc65e1add8918fc451c225c92c81f38c02b99bbb"
  license "MIT"

  depends_on "pnpm"

  def install
    # Install the script onto PATH as `migrate-to-pnpm` (without the .sh extension)
    bin.install "migrate-to-pnpm.sh" => "migrate-to-pnpm"
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/migrate-to-pnpm --help")
  end
end
