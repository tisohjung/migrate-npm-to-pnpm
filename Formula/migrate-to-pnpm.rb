class MigrateToPnpm < Formula
  desc "Recursively find and migrate npm projects to pnpm"
  homepage "https://github.com/tisohjung/migrate-npm-to-pnpm"
  url "https://github.com/tisohjung/migrate-npm-to-pnpm/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "37f5c89d542f612484ffeca8690a76456c47ae0373c56c0eee1dd36a41544b08"
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
