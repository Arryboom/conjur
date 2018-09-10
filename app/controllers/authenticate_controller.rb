# frozen_string_literal: true

class AuthenticateController < ApplicationController
  include Authenticators

  def index 
    authenticators = {
      # Installed authenticator plugins
      installed: installed_authenticators.keys.sort,
    
      # Authenticator webservices created in policy
      configured: configured_authenticators.sort,

      # Authenticators white-listed in CONJUR_AUTHENTICATORS
      enabled: enabled_authenticators.sort
    }

    render json: authenticators
  end

  def authenticate
    authentication_token = ::Authentication::Strategy.new(
      authenticators: installed_authenticators,
      audit_log: ::Authentication::AuditLog,
      security: nil,
      env: ENV,
      role_cls: ::Role,
      token_factory: TokenFactory.new
    ).conjur_token(
      ::Authentication::Strategy::Input.new(
        authenticator_name: params[:authenticator],
        service_id:         params[:service_id],
        account:            params[:account],
        username:           params[:id],
        password:           request.body.read,
        origin:             request.ip,
        request:            request
      )
    )
    render json: authentication_token
  rescue => e
    logger.debug("Authentication Error: #{e.message}")
    e.backtrace.each do |line|
      logger.debug(line)
    end
    raise Unauthorized
  end

  def k8s_inject_client_cert
    ::Authentication::AuthnK8s::Authenticator.new(env: ENV).inject_client_cert(params, request)
    head :ok
  rescue => e
    logger.debug("Authentication Error: #{e.message}")
    e.backtrace.each do |line|
      logger.debug(line)
    end
    raise Unauthorized
  end
end
