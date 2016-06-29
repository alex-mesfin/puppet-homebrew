Facter.add(:has_brew) do
  confine :operatingsystem => :darwin
  setcode do
    File.exists?('/usr/local/homebrew/bin/brew') || system('brew --version >/dev/null 2>&1')
  end
end
