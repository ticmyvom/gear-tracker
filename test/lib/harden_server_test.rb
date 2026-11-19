require "test_helper"

# script/harden-server.sh runs once, as root, on a fresh server. It can only
# really be tried on a server, so these tests check its safety rules.
class HardenServerTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("script/harden-server.sh")

  def script = SCRIPT.read

  test "is valid bash and executable" do
    assert SCRIPT.executable?
    assert system("bash", "-n", SCRIPT.to_s), "bash found a syntax error"
    assert_match "set -euo pipefail", script
  end

  test "refuses to run unless root already has an SSH key, so you can't be locked out" do
    assert_match %r{/root/\.ssh/authorized_keys}, script
    check = script.index("authorized_keys")
    assert_operator check, :<, script.index("PermitRootLogin no"), "the key check must come before SSH is locked down"
  end

  test "creates the same deploy user Kamal connects as" do
    deploy = YAML.load(ERB.new(Rails.root.join("config/deploy.yml").read).result)

    assert_match(/^DEPLOY_USER=#{deploy.dig("ssh", "user")}$/, script)
  end

  test "turns off password and root logins and checks the SSH config before applying it" do
    [ "PermitRootLogin no", "PasswordAuthentication no", "KbdInteractiveAuthentication no" ].each { assert_includes script, it }
    assert_operator script.index("sshd -t"), :<, script.index("systemctl reload ssh")
  end

  test "allows only SSH and web traffic through the firewall" do
    assert_includes script, "ufw default deny incoming"
    allowed = script.scan(/^ufw allow (.+)$/).flatten
    assert_equal [ "OpenSSH", "80/tcp", "443/tcp" ], allowed
  end

  test "adds swap only when there is none, privately and permanently" do
    assert_includes script, 'if [[ -z "$(swapon --show)" ]]'
    assert_operator script.index("chmod 600 /swapfile"), :<, script.index("mkswap /swapfile")
    assert_includes script, "/swapfile none swap sw 0 0"
  end

  test "installs security updates automatically" do
    assert_includes script, "unattended-upgrades"
    assert_includes script, 'APT::Periodic::Unattended-Upgrade "1";'
  end
end
