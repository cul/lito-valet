

Creating a new Valet service
============================

Valet has gone through a few different code arrangements.

BearStor is the model for the most current arrangement.


Update app_config.yml
---------------------
Your new service should have a section in app_config with
some basic settings filled in.  Type can be 'form' or 'bounce'.

  paging:
    label: 'Paging'
    authenticate: true
    type: bounce


Update routes.rb
---------------------
Your new service should be one of the many service-names
listed which map to controller: 'forms'

  resources :paging,
            :ill,
            :docdel,
            :intercampus,
            :in_process,
            :precat,
            :itemfeedback,
            :notonshelf,
            :bearstor,
            controller: 'forms',
            only: [:show, :create]


Create service-specific library
-------------------------------
Within /app/lib/service/ create a new .rb file for the service.
Minimally, you need this:

module Service
  class Paging < Service::Base
  end
end

But add in any other logic you need, refer to base.rb for 
what methods to override, and look at other services for
examples of override logic.


Bounce - redirect browser to another URL
----------------------------------------
Services configured as type:bounce, need to implement:

    build_service_url(params, bib_record, current_user)
    
If the service is linked directly from CLIO, then 'params' will
likely be just the bib id.  That's already been used to fetch a
full ClioRecord object, which is the 2nd arg - the bib_record. 



Form - build a Valet form
----------------------------------------
Services configured as type:form need a form.

The form should be in app/views/forms, and named after the services,
e.g.,   /app/views/forms/avery_onsite.html.erb

The form should try to re-use partials if possible.



Optional - create confirmation page 
-----------------------------------
If after collecting information you'd like this service to redirect
to a confirmation page, you'll need to do two things:

1) write a get_confirmation_locals() method, to gather local variables,

2) write an /app/views/forms/SERVICE_confirm.html.erb form, to display the variables



Optional - send email
---------------------
If after collection information you'd like this service to send
email, you'll need to do three things:

1) write a send_emails() method, which will gather params

2) add a method to /app/mailers/form_mailer.rb to process params and send mail

3) write mail template, named the same as the method, under /app/views/form_mailer/SERVICE.text.erb 



Supporting services without a bib argument
---------------------
The basic Valet structure assumes that each service takes a single param, the bib id.
Some services support a simple redirect without a bib id, and need special setup.
These services still use Valet-based authentication and logging.

1) Add a route to the "SIMPLE REDIRECT SERVICES" section of routes.rb

    get 'illiad', action: :show, controller: 'forms'

2) Add a new key to the app_config.yml section for this service:

    bib_optional: true

3) Setup the rest as usual

 





