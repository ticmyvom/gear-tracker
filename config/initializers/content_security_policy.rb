# Be sure to restart your server when you modify this file.

# Tells browsers to load scripts, styles, images and fonts only from this app,
# so a script someone manages to inject into a page won't run.
# See https://guides.rubyonrails.org/security.html#content-security-policy-header
#
# Nothing is loaded from other sites. If a change needs to, allow that one site
# here, and say why in the pull request.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self
    policy.connect_src :self
    policy.base_uri    :self
    policy.form_action :self
    # Stops other sites from showing this app in a frame to trick people into clicking.
    policy.frame_ancestors :none
  end

  # A fresh random nonce on each request lets the app's own inline importmap
  # script and Turbo's progress bar style run, and nothing else inline.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[ script-src style-src ]
end
