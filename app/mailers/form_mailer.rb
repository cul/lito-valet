class FormMailer < ApplicationMailer
  # add_template_helper(ValetRequestsHelper)
  helper ValetRequestsHelper

  default from: 'noreply@library.columbia.edu'

  ###
  ### BARNARD REMOTE - staff request email and patron confirm email
  ###

  # Email request to staff
  def barnard_remote_request
    @params = params
    to      = params[:staff_email]
    from    = "Barnard Remote Request Service <#{params[:staff_email]}>"
    title   = params[:bib_record].title
    subject = "New Barnard Remote Request [#{title}]"
    mail(to: to, from: from, subject: subject)
  end

  # Email confirmation to Patron
  def barnard_remote_confirm
    to = params[:patron_email]
    from = "Barnard Remote Request Service <#{params[:staff_email]}>"
    title = params[:bib_record].title
    subject = "Barnard Remote Request Confirmation [#{title}]"
    mail(to: to, from: from, subject: subject)
  end

  ###
  ### STARRSTOR - staff request email and patron confirm email
  ###

  # Email request to staff
  def starrstor_request
    @params = params
    to      = params[:staff_email]
    # from    = "Starr Remote Request Service <#{params[:staff_email]}>"
    from = 'Starr Remote Request Service <starrstor@library.columbia.edu>'
    title   = params[:bib_record].title
    subject = "New StarrStor request [#{title}]"
    mail(to: to, from: from, subject: subject)
  end

  # Email confirmation to Patron
  def starrstor_confirm
    to = params[:patron_email]
    # from = "Starr Remote Request Service <#{params[:staff_email]}>"
    from = 'Starr Remote Request Service <starrstor@library.columbia.edu>'
    title = params[:bib_record].title
    subject = "StarrStor Request Confirmation [#{title}]"
    mail(to: to, from: from, subject: subject)
  end

  ###
  ### PRECAT - single mail to both staff and patron
  ###
  def precat
    to = params[:patron_email] + ', ' + params[:staff_email]
    from = "Butler Circulation <#{params[:staff_email]}>"
    title = params[:bib_record].title
    subject = "Precat Search Request [#{title}]"
    mail(to: to, from: from, subject: subject)
  end

  ###
  ### IN PROCESS / ON ORDER - single mail to both staff and patron
  ###
  def in_process
    to = params[:patron_email] + ', ' + params[:staff_email]
    from = "Request Services <#{params[:staff_email]}>"
    title = params[:bib_record].title
    subject = "On Order / In Process Request [#{title}]"
    mail(to: to, from: from, subject: subject)
  end

  ###
  ### ITEM FEEDBACK - single mail to both staff and patron
  ###
  def item_feedback
    to = params[:patron_email] + ', ' + params[:staff_email]
    from = "Item Feedback <#{params[:staff_email]}>"
    title = params[:bib_record].title
    subject = "Item Feedback [#{title}]"
    mail(to: to, from: from, subject: subject)
  end

  ###
  ### RECAP - confirmation emails to patrons
  ###

  def recap_loan_confirm
    to = params['emailAddress']
    from = 'recap@library.columbia.edu'
    confirm_bcc = APP_CONFIG[:recap_loan][:confirm_bcc]
    recap_subject = 'Offsite Pick-Up Confirmation'
    recap_subject += " [#{params['titleIdentifier']}]" if params['titleIdentifier']
    recap_subject += " (#{Rails.env})" if Rails.env != 'valet_prod'
    subject = recap_subject
    # Make params available within template by using an instance variable
    @params = params
    mail_params = {to: to, from: from, subject: subject}
    mail_params[:bcc] = confirm_bcc if confirm_bcc
    mail(mail_params)
  end

  def recap_scan_confirm
    to = params['emailAddress']
    from = 'recap@library.columbia.edu'
    confirm_bcc = APP_CONFIG[:recap_scan][:confirm_bcc]
    recap_subject = 'Offsite Scan Confirmation'
    recap_subject += " [#{params['titleIdentifier']}]" if params['titleIdentifier']
    recap_subject += " (#{Rails.env})" if Rails.env != 'valet_prod'
    subject = recap_subject
    # Make params available within template by using an instance variable
    @params = params
    mail_params = {to: to, from: from, subject: subject}
    mail_params[:bcc] = confirm_bcc if confirm_bcc
    mail(mail_params)
  end

  ###
  ### AVERY ONSITE
  ###
  def avery_onsite_request
    @params = params
    staff_email = APP_CONFIG[:avery_onsite][:staff_email]
    to      = staff_email
    from    = "Avery Services <#{staff_email}>"
    title   = params[:bib_record].title
    subject = "New On-Site Use request [#{title}]"
    mail(to: to, from: from, subject: subject)
  end

  def avery_onsite_confirm
    @params = params
    staff_email = APP_CONFIG[:avery_onsite][:staff_email]
    to      = params[:patron_email]
    from    = "Avery Services <#{staff_email}>"
    title   = params[:bib_record].title
    subject = "Avery On-Site Use - Request Confirmation [#{title}]"
    mail(to: to, from: from, subject: subject)
  end

  ###
  ### NOT-ON-SHELF - staff request email
  ###

  # Email request to both staff and patron
  def notonshelf_request
    @params = params
    to = params[:patron_email] + ', ' + params[:staff_email]

    from    = "Circulation <#{params[:staff_email]}>"
    title   = params[:bib_record].title
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    subject = "Search_Request: #{timestamp}"
    mail(to: to, from: from, subject: subject)
  end
end
